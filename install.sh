#!/usr/bin/env bash
# Zest Package Manager Installer - Linux / macOS
# Usage: ./install.sh [OPTIONS]
# Pipe install: curl -sSL https://raw.githubusercontent.com/fuseraft/zest/main/install.sh | bash

set -euo pipefail 2>/dev/null || set -e

# -------------------------------------------------------------------------
# Colors
# -------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

REPO_URL="https://github.com/fuseraft/zest"

# -------------------------------------------------------------------------
# Logging
# -------------------------------------------------------------------------
info()    { printf "${BLUE}  •${NC} %s\n" "$*"; }
success() { printf "${GREEN}  ✓${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}  !${NC} %s\n" "$*"; }
die()     { printf "${RED}  ✗ ERROR:${NC} %s\n" "$*" >&2; exit 1; }
header()  { printf "\n${BOLD}%s${NC}\n" "$*"; }

# -------------------------------------------------------------------------
# Usage
# -------------------------------------------------------------------------
usage() {
  cat <<EOF
${BOLD}Zest Installer${NC} — Linux / macOS

USAGE:
  install.sh [OPTIONS]

OPTIONS:
  --user              Install for current user only in ~/.zest  (default)
  --system            Install system-wide to /opt/zest          (requires sudo)
  --prefix=PATH       Install to a custom directory
  --uninstall         Remove Zest
  --update            Remove the old install and reinstall the latest
  -h, --help          Show this help

EXAMPLES:
  ./install.sh                          # User install
  ./install.sh --system                 # System-wide install  (sudo)
  ./install.sh --prefix=/usr/local      # Custom prefix
  ./install.sh --update                 # Update to latest
  ./install.sh --uninstall              # Remove Zest

  # One-liner install from the web:
  curl -sSL https://raw.githubusercontent.com/fuseraft/zest/main/install.sh | bash

EOF
}

# -------------------------------------------------------------------------
# Argument Parsing
# -------------------------------------------------------------------------
INSTALL_MODE="user"  # user | system | custom
PREFIX=""
UNINSTALL=false
UPDATE=false

for arg in "$@"; do
  case "$arg" in
    --user)      INSTALL_MODE="user" ;;
    --system)    INSTALL_MODE="system" ;;
    --prefix=*)  INSTALL_MODE="custom"; PREFIX="${arg#--prefix=}" ;;
    --uninstall) UNINSTALL=true ;;
    --update)    UPDATE=true ;;
    -h|--help)   usage; exit 0 ;;
    *) die "Unknown argument: $arg  (run with --help for usage)" ;;
  esac
done

# Resolve prefix
if [[ -z "$PREFIX" ]]; then
  case "$INSTALL_MODE" in
    user)   PREFIX="$HOME/.zest" ;;
    system) PREFIX="/opt/zest" ;;
  esac
fi

BIN_DIR="$PREFIX/bin"

# -------------------------------------------------------------------------
# Uninstall
# -------------------------------------------------------------------------
if $UNINSTALL; then
  header "Uninstalling Zest"
  if [[ ! -d "$PREFIX" ]]; then
    warn "No Zest installation found at $PREFIX"
    exit 0
  fi
  rm -rf "$PREFIX"
  # Remove PATH entries
  for shell_rc in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile"; do
    [[ -f "$shell_rc" ]] || continue
    if grep -qF "$BIN_DIR" "$shell_rc" 2>/dev/null; then
      tmp="$(mktemp)"
      grep -v "# Added by Zest installer" "$shell_rc" \
        | grep -vF "export PATH=\"${BIN_DIR}" > "$tmp" || true
      mv "$tmp" "$shell_rc"
      info "Removed PATH entry from $shell_rc"
    fi
  done
  # Remove system symlink if present
  [[ -L "/usr/local/bin/zest" ]] && rm -f "/usr/local/bin/zest" && info "Removed /usr/local/bin/zest"
  success "Zest uninstalled from $PREFIX"
  exit 0
fi

# -------------------------------------------------------------------------
# Banner
# -------------------------------------------------------------------------
printf "${BOLD}${GREEN}"
cat <<'LOGO'
                                           
                                    ,d     
                                    88     
888888888   ,adPPYba,  ,adPPYba,  MM88MMM  
     a8P"  a8P_____88  I8[    ""    88     
  ,d8P'    8PP"""""""   `"Y8ba,     88     
,d8"       "8b,   ,aa  aa    ]8I    88,    
888888888   `"Ybbd8"'  `"YbbdP"'    "Y888  

LOGO
printf "${NC}"
header "Zest Installer"

info "Prefix    : $PREFIX"

# -------------------------------------------------------------------------
# Prerequisites
# -------------------------------------------------------------------------
header "Checking prerequisites"

command -v kiwi >/dev/null 2>&1 \
  || die "Kiwi is not installed or not in PATH. Install Kiwi first: https://github.com/fuseraft/kiwi"
info "kiwi      : $(command -v kiwi)"

# -------------------------------------------------------------------------
# Sudo Check for System Install
# -------------------------------------------------------------------------
if [[ "$INSTALL_MODE" == "system" && "${EUID:-$(id -u)}" -ne 0 ]]; then
  warn "System install requires root. Re-running with sudo..."
  exec sudo bash "$0" "$@"
fi

# -------------------------------------------------------------------------
# Update: wipe previous install before reinstalling
# -------------------------------------------------------------------------
if $UPDATE && [[ -d "$PREFIX" ]]; then
  info "Removing previous installation..."
  rm -rf "$PREFIX"
  success "Old installation removed"
fi

mkdir -p "$BIN_DIR"

# -------------------------------------------------------------------------
# Locate or clone the repository
# -------------------------------------------------------------------------
header "Installing Zest"

CLEANUP_REPO=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-./install.sh}")" 2>/dev/null && pwd || pwd)"

if [[ -f "$SCRIPT_DIR/zest.kiwi" ]]; then
  REPO_DIR="$SCRIPT_DIR"
  info "Using local repository at $REPO_DIR"
else
  command -v git >/dev/null 2>&1 \
    || die "git is required to clone the Zest repository."
  REPO_DIR="$(mktemp -d)"
  CLEANUP_REPO=true
  trap '[[ "$CLEANUP_REPO" == "true" ]] && rm -rf "$REPO_DIR"' EXIT
  info "Cloning Zest repository..."
  git clone --depth=1 "$REPO_URL" "$REPO_DIR" > /dev/null 2>&1
  success "Repository cloned"
fi

# -------------------------------------------------------------------------
# Copy files
# -------------------------------------------------------------------------
cp "$REPO_DIR/zest.kiwi" "$PREFIX/zest.kiwi"
cp -r "$REPO_DIR/lib/." "$PREFIX/lib/"
success "Zest scripts installed"

# -------------------------------------------------------------------------
# Create wrapper script
# -------------------------------------------------------------------------
cat > "$BIN_DIR/zest" <<'WRAPPER'
#!/usr/bin/env bash
ZEST_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ZEST_HOME
exec kiwi "${ZEST_HOME}/zest.kiwi" "$@"
WRAPPER

chmod +x "$BIN_DIR/zest"
success "Wrapper script created: $BIN_DIR/zest"

# -------------------------------------------------------------------------
# PATH / Symlink
# -------------------------------------------------------------------------
header "Configuring PATH"

if [[ "$INSTALL_MODE" == "system" ]]; then
  SYMLINK="/usr/local/bin/zest"
  ln -sf "$BIN_DIR/zest" "$SYMLINK"
  success "Symlinked: $SYMLINK → $BIN_DIR/zest"
else
  added=false
  for shell_rc in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile"; do
    [[ -f "$shell_rc" ]] || continue
    if ! grep -qF "$BIN_DIR" "$shell_rc" 2>/dev/null; then
      printf '\n# Added by Zest installer\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >> "$shell_rc"
      info "Updated PATH in $shell_rc"
      added=true
    fi
  done
  if ! $added; then
    printf '\n# Added by Zest installer\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >> "$HOME/.profile"
    info "Updated PATH in ~/.profile"
  fi
fi

# -------------------------------------------------------------------------
# Done
# -------------------------------------------------------------------------
header "Installation complete!"
printf "  Binary  : %s/zest\n" "$BIN_DIR"
printf "  Home    : %s\n" "$PREFIX"
printf "\n"

if [[ "$INSTALL_MODE" != "system" ]]; then
  printf "${YELLOW}To start using Zest, restart your shell or run:${NC}\n"
  printf '  source ~/.bashrc   # or ~/.zshrc / ~/.profile\n'
  printf "\n"
fi

printf "Run ${BOLD}zest --help${NC} to get started.\n\n"
