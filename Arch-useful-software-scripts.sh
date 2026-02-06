#!/usr/bin/env bash
# Interactive Arch installer (yay-only) — FIXED argument parsing
# This is the same script as the previous "with_logging" version but with robust
# command-line parsing (no unconditional `shift`), avoiding "shift: out of range".
#
# Usage:
#   ./interactive-arch-installer-yay-only_with_logging_fixed.sh [PACKAGES_DIR] [--dry-run] [--no-confirm] [--log-file <path>] [--verbose]
set -euo pipefail

# ---------------------------
# Defaults
# ---------------------------
PACKAGES_DIR="./packages"   # default, may be overridden by first non-option arg
DRY_RUN=false
AUTO_CONFIRM=true   # when true uses --noconfirm for yay installs; false => ask before installing
LOGFILE_OVERRIDE=""
VERBOSE=false

# ---------------------------
# Robust argument parsing:
# - first positional arg (if present and not an option) is PACKAGES_DIR
# - supported options: --dry-run, --no-confirm, --log-file <path>, --verbose, --help
# ---------------------------
# Use a flag to record whether PACKAGES_DIR was set by the user.
PACKAGES_DIR_SET=false

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-confirm)
      AUTO_CONFIRM=false
      shift
      ;;
    --log-file)
      if [ -n "${2:-}" ]; then
        LOGFILE_OVERRIDE="$2"
        shift 2
      else
        echo "Error: --log-file requires a path argument" >&2
        exit 1
      fi
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: installer.sh [PACKAGES_DIR] [--dry-run] [--no-confirm] [--log-file <path>] [--verbose]
 - PACKAGES_DIR default ./packages
 - --dry-run    : only show what would happen
 - --no-confirm : do not auto-confirm install (will prompt)
 - --log-file   : override default log path
 - --verbose    : more debug output
USAGE
      exit 0
      ;;
    --*) 
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      # non-option argument: treat as PACKAGES_DIR if not already set
      if [ "$PACKAGES_DIR_SET" = false ]; then
        PACKAGES_DIR="$1"
        PACKAGES_DIR_SET=true
        shift
      else
        echo "Unexpected positional argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

# ---------------------------
# The rest of the script follows exactly the previous implementation:
# logging, color helpers, ensure_yay, building lines, fzf UI, installation loop, summary.
# For brevity here we include the full implementation (unchanged except above parsing fix).
# ---------------------------

# ---------------------------
# Helpers: logging & colors
# ---------------------------
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/interactive-arch-installer"
mkdir -p "$LOG_DIR"
if [ -n "$LOGFILE_OVERRIDE" ]; then
  LOGFILE="$LOGFILE_OVERRIDE"
else
  LOGFILE="${LOG_DIR}/installer_${TIMESTAMP}.log"
fi
REPORT_FILE="${LOG_DIR}/installer_summary_${TIMESTAMP}.txt"

# ANSI helpers
_color() { printf '\033[%sm' "$1"; }    # usage: $(_color "1;32")
_color_reset() { printf '\033[0m'; }

# levels
log() {
  local level="$1"; shift
  local msg="$*"
  local now
  now="$(date --iso-8601=seconds)"
  printf '%s [%s] %s\n' "$now" "$level" "$msg" | tee -a "$LOGFILE"
}
info()    { log "INFO" "$*"; }
warn()    { log "WARN" "$*"; }
error()   { log "ERROR" "$*"; }
debug()   { $VERBOSE && log "DEBUG" "$*"; }

# trap to capture unexpected errors
on_err() {
  local rc=$?
  error "Unexpected error (code $rc). Last command: $BASH_COMMAND"
  echo "---- Last 200 lines of log ----" >> "$REPORT_FILE"
  tail -n 200 "$LOGFILE" >> "$REPORT_FILE" 2>/dev/null || true
  error "Wrote diagnostic summary to $REPORT_FILE"
  exit $rc
}
trap 'on_err' ERR

# ---------------------------
# UI / color map
# ---------------------------
declare -A GROUP_COLORS=(
  [base]="1;32"
  [common]="0;32"
  [cli-tools]="0;36"
  [dev]="1;34"
  [web]="1;35"
  [desktop-gnome]="1;33"
  [desktop-plasma]="1;33"
  [media]="0;31"
  [productivity]="0;35"
  [virtualization]="0;36"
  [network-services]="0;33"
  [security]="1;31"
  [fonts]="0;37"
  [appearance]="0;36"
  [office]="0;34"
  [devops]="0;35"
  [media-creation]="0;31"
  [aur]="1;31"
)
DEFAULT_GROUP_COLOR="0;37"

color_text() { printf '\033[%sm%s\033[0m' "$1" "$2"; }

# preview command (local descriptions)
if command -v bat >/dev/null 2>&1; then
  PREVIEW_CMD='bat --style=numbers --color=always --paging=never'
else
  PREVIEW_CMD='sed -n "1,200p"'
fi

# sanitize package name -> filename-safe
sanitize() { printf '%s' "$1" | sed 's/[^A-Za-z0-9+_.-]/_/g'; }

# ---------------------------
# Ensure yay available
# ---------------------------
ensure_yay() {
  if command -v yay >/dev/null 2>&1; then
    info "yay is installed: $(command -v yay)"
    return 0
  fi

  info "yay not found. Will build & install yay from AUR (requires sudo & base-devel)."
  read -rp "Proceed to install yay now? [y/N] " ans
  case "$ans" in [Yy]*) ;; *) error "yay required; aborting."; exit 1 ;; esac

  info "Installing base-devel and git if missing..."
  { sudo pacman -Sy --noconfirm; } 2>&1 | tee -a "$LOGFILE"
  { sudo pacman -S --needed --noconfirm base-devel git; } 2>&1 | tee -a "$LOGFILE"

  tmpdir="$(mktemp -d)"
  cleanup_tmp() { rm -rf "$tmpdir"; }
  trap cleanup_tmp EXIT

  info "Cloning yay AUR..."
  { git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"; } 2>&1 | tee -a "$LOGFILE"
  pushd "$tmpdir/yay" >/dev/null
  info "Building and installing yay..."
  { makepkg -si --noconfirm; } 2>&1 | tee -a "$LOGFILE" || { popd >/dev/null; error "Failed to build yay"; exit 1; }
  popd >/dev/null

  if ! command -v yay >/dev/null 2>&1; then
    error "yay still not found after build. Aborting."
    exit 1
  fi
  info "yay installed successfully: $(command -v yay)"
}

# ---------------------------
# Build selectable lines
# ---------------------------
DESC_DIR="descriptions"
mkdir -p "$DESC_DIR"
lines=()
declare -A seen

if [ ! -d "$PACKAGES_DIR" ]; then
  error "Packages directory not found: $PACKAGES_DIR"
  exit 1
fi

while IFS= read -r gf; do
  [ -z "$gf" ] && continue
  base=$(basename "$gf")
  group="${base%.*}"
  group_is_aur=false
  case "$group" in *aur*|*AUR*) group_is_aur=true ;; esac

  while IFS= read -r line || [ -n "$line" ]; do
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    if [[ "$line" == aur:* ]]; then
      pkg="${line#aur:}"
      marker="aur:${pkg}"
    else
      pkg="$line"
      marker="$pkg"
      if [ "$group_is_aur" = true ]; then marker="aur:${pkg}"; fi
    fi
    key="${marker#aur:}"
    if [ -n "${seen[$key]:-}" ]; then continue; fi
    seen[$key]=1

    safe="$(sanitize "$key")"
    descfile="${DESC_DIR}/${safe}.md"
    if [ ! -f "$descfile" ]; then
      printf "Package: %s\nGroup: %s\nSource: %s\n\n简要说明：\n\n- 用途：\n- 备注：\n" "$key" "$group" "$( [ "$group_is_aur" = true ] && echo "AUR" || echo "pacman/official" )" > "$descfile"
      info "Created description template: $descfile"
    fi

    gcolor="${GROUP_COLORS[$group]:-$DEFAULT_GROUP_COLOR}"
    display_group="$(color_text "$gcolor" "$group")"
    display_pkg="$(color_text "1;33" "$key")"
    # columns: colored_group \t colored_pkg \t descfile \t raw_marker
    lines+=("${display_group}"$'\t'"${display_pkg}"$'\t'"${descfile}"$'\t'"${marker}")
  done < "$gf"
done < <(find "$PACKAGES_DIR" -maxdepth 1 -type f -name '*.list' -print | sort)

if [ "${#lines[@]}" -eq 0 ]; then
  error "No packages found in $PACKAGES_DIR"
  exit 1
fi

# ---------------------------
# Adaptive UI sizes
# ---------------------------
LINES_T=$(tput lines 2>/dev/null || echo 24)
COLS_T=$(tput cols 2>/dev/null || echo 80)
if [ "$LINES_T" -lt 24 ]; then FZF_HEIGHT_PCT=60
elif [ "$LINES_T" -lt 40 ]; then FZF_HEIGHT_PCT=70
else FZF_HEIGHT_PCT=80; fi

if [ "$COLS_T" -lt 100 ]; then PREVIEW_PCT=60
elif [ "$COLS_T" -lt 160 ]; then PREVIEW_PCT=55
else PREVIEW_PCT=50; fi

# header info
echo
echo "$(color_text "1;36" "Interactive Arch Installer (yay-only) - $(date)")"
echo "Packages dir: $PACKAGES_DIR"
echo "Descriptions dir: $DESC_DIR"
echo "Log file: $LOGFILE"
echo

info "Launching selection UI..."

# ---------------------------
# fzf selection with preview & edit
# ---------------------------
FZF_CMD=(
  fzf --ansi --multi --height="${FZF_HEIGHT_PCT}%" --border
  --delimiter=$'\t' --with-nth=1,2
  --bind "tab:toggle+down,ctrl-a:select-all,ctrl-e:execute(${EDITOR} '{3}' >/dev/tty)"
  --preview "if [ -f {3} ]; then ${PREVIEW_CMD} {3}; else echo 'No description for {2}. Press Ctrl-E to create.'; fi"
  --preview-window="right:${PREVIEW_PCT}%:wrap"
  --prompt="Select packages (multi): "
)
selected=$(printf '%s\n' "${lines[@]}" | "${FZF_CMD[@]}" ) || true

if [ -z "$selected" ]; then
  info "No selection made; exiting."
  exit 0
fi

# ---------------------------
# Parse selection -> install_list
# ---------------------------
mapfile -t sel_lines < <(printf '%s\n' "$selected")
install_list=()
_valid_name_regex='^[A-Za-z0-9+_.-]+$'
for raw in "${sel_lines[@]}"; do
  marker="$(printf '%s\n' "$raw" | awk -F$'\t' '{print $4}')"
  marker="$(printf '%s' "$marker" | xargs)"
  if [[ "$marker" == aur:* ]]; then pkg="${marker#aur:}"; else pkg="$marker"; fi
  if [[ "$pkg" =~ $_valid_name_regex ]]; then
    install_list+=("$pkg")
  else
    warn "Skipping suspicious package name: $pkg"
  fi
done

if [ "${#install_list[@]}" -eq 0 ]; then
  warn "No valid packages selected. Exiting."
  exit 0
fi

info "Selected packages (${#install_list[@]}): ${install_list[*]}"
printf '%s\n' "Selected packages:" "${install_list[@]}" >> "$LOGFILE"

# ---------------------------
# Ensure yay
# ---------------------------
ensure_yay

# write basic header in log
info "Run started by user: $(whoami)"
info "System: $(uname -a)"
info "Running with DRY_RUN=$DRY_RUN AUTO_CONFIRM=$AUTO_CONFIRM VERBOSE=$VERBOSE"

# ---------------------------
# Install loop (per-package, record failures)
# ---------------------------
FAILED=()
SUCCESS=()

if [ "$DRY_RUN" = true ]; then
  info "Dry-run mode: no installation will be performed."
  printf 'DRY-RUN selected packages:\n' >> "$REPORT_FILE"
  printf '%s\n' "${install_list[@]}" >> "$REPORT_FILE"
  info "Wrote dry-run package list to $REPORT_FILE"
  exit 0
fi

# prepare yay options
YAY_OPTS=( -S --needed )
if [ "$AUTO_CONFIRM" = true ]; then
  YAY_OPTS+=( --noconfirm )
fi

info "Beginning installation via yay..."
for pkg in "${install_list[@]}"; do
  info "Installing: $pkg"
  if { yay "${YAY_OPTS[@]}" "$pkg"; } 2>&1 | tee -a "$LOGFILE"; then
    info "Installed: $pkg"
    SUCCESS+=("$pkg")
  else
    error "Failed to install: $pkg"
    FAILED+=("$pkg")
  fi
done

# ---------------------------
# Summary report
# ---------------------------
{
  echo "Interactive Arch Installer run summary"
  echo "Timestamp: $(date --iso-8601=seconds)"
  echo "User: $(whoami)"
  echo "Packages requested: ${#install_list[@]}"
  echo "Succeeded: ${#SUCCESS[@]}"
  if [ "${#SUCCESS[@]}" -gt 0 ]; then printf '  %s\n' "${SUCCESS[@]}"; fi
  echo "Failed: ${#FAILED[@]}"
  if [ "${#FAILED[@]}" -gt 0 ]; then printf '  %s\n' "${FAILED[@]}"; fi
  echo "Logfile: $LOGFILE"
  echo "End of summary."
} > "$REPORT_FILE"

info "Wrote summary report to: $REPORT_FILE"
if [ "${#FAILED[@]}" -gt 0 ]; then
  warn "Some packages failed to install. See $REPORT_FILE and $LOGFILE for details."
else
  info "All selected packages installed successfully."
fi

echo
echo "$(color_text "1;32" "Done. Summary saved to:") $REPORT_FILE"
echo "Log: $LOGFILE"