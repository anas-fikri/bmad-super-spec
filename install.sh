#!/usr/bin/env bash

set -euo pipefail

# Helper to print messages
info(){ echo -e "\033[1;34m[INFO]\033[0m $*"; }
error(){ echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# Ensure required commands exist
for cmd in npm uv; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    error "Required command '$cmd' not found. Please install it first."
    exit 1
  fi
done

# Determine install mode: global (with sudo) or user‑local
USE_SUDO=""
if [ -w "$(npm root -g)" ] 2>/dev/null; then
  info "You have write permission to the global npm directory. Installing globally without sudo."
else
  # Test if sudo works without password prompt (common in CI); if not, fall back to local install
  if sudo -n true 2>/dev/null; then
    USE_SUDO="sudo"
    info "Will install globally using sudo."
  else
    info "No permission for global install and sudo requires a password. Falling back to user‑local npm prefix."
    NPM_PREFIX="$HOME/.npm-global"
    mkdir -p "$NPM_PREFIX"
    npm config set prefix "$NPM_PREFIX"
    export PATH="$NPM_PREFIX/bin:$PATH"
    info "Local npm prefix set to $NPM_PREFIX. Updated PATH for this script run."
  fi
fi

install_pkg(){
  local pkg="$1"
  info "Installing $pkg..."
  if [ -n "$USE_SUDO" ]; then
    $USE_SUDO npm i -g "$pkg"
  else
    npm i -g "$pkg"
  fi
}

# Install the three tools
install_pkg bmad-method
install_pkg superpowers

# Install specify-cli via uv (already installed, but ensure latest)
info "Ensuring specify-cli (Spec‑Kit) is installed via uv..."
uv tool install specify-cli || true

# Verify installations
info "Verifying installations:"
for cmd in bmad-method superpowers specify; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ver=$($cmd --version 2>/dev/null || true)
    echo "  $cmd → found${ver:+, version $ver}"
  else
    echo "  $cmd → NOT found"
  fi
done

# If we used a local prefix, remind the user to persist PATH
if [ -z "$USE_SUDO" ] && [ -n "${NPM_PREFIX-}" ]; then
  echo -e "\n\033[1;33mNOTE:\033[0m To make the installed tools available in future shells, add the following line to your ~/.bashrc (or ~/.zshrc):"
  echo "export PATH=\"$NPM_PREFIX/bin:\$PATH\""
fi

info "All done! You can now run the skill commands, e.g.:"
echo "  pi skill run bmad-super-spec init"

# ---------------------------------------------------------------
# 1️⃣ Copy the skill into PI's skill directory (default $HOME/.pi/skills)
# ---------------------------------------------------------------
PI_ROOT="${PI_ROOT:-$HOME/.pi}"
SKILL_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DST="$PI_ROOT/skills/bmad-super-spec"
info "Copying skill to $SKILL_DST"
mkdir -p "$SKILL_DST"
# Use rsync to copy without the .git directory and preserve permissions.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude='.git' "$SKILL_SRC/" "$SKILL_DST/"
else
  # Fallback to cp if rsync is unavailable.
  cp -r "$SKILL_SRC" "$SKILL_DST" || {
    error "Failed to copy skill directory. Check permissions or install rsync."
    exit 1
  }
fi

# ---------------------------------------------------------------
# 2️⃣ Create the wrapper script(s) in a directory that is on PATH
# ---------------------------------------------------------------
# Detect platform (Linux/macOS/Git‑Bash vs native Windows PowerShell)
OS_TYPE="$(uname -s 2>/dev/null || echo "Windows")"
if [[ "$OS_TYPE" == "Linux" || "$OS_TYPE" == "Darwin" ]]; then
  # Unix‑like environment – use ~/.local/bin
  WRAPPER_DIR="${HOME}/.local/bin"
  mkdir -p "$WRAPPER_DIR"
  WRAPPER_PATH="$WRAPPER_DIR/bmad-super-spec-run"
  info "Installing Unix wrapper at $WRAPPER_PATH"
  cat > "$WRAPPER_PATH" <<'EOF'
#!/usr/bin/env bash
# Directly run the orchestrator without invoking PI, to save RAM.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve the installed skill directory (where the orchestrator resides).
SKILL_ROOT="${HOME}/.pi/skills/bmad-super-spec"
ORCHESTRATOR="${SKILL_ROOT}/orchestrator.js"
exec node "$ORCHESTRATOR" "$@"
EOF
  chmod +x "$WRAPPER_PATH"
else
  # Assume native Windows (PowerShell/CMD). Use a batch file that calls node directly.
  WRAPPER_DIR="${USERPROFILE}/AppData/Local/Microsoft/WindowsApps"
  mkdir -p "$WRAPPER_DIR"
  WRAPPER_PATH="$WRAPPER_DIR/bmad-super-spec-run.bat"
  info "Installing Windows batch wrapper at $WRAPPER_PATH"
  cat > "$WRAPPER_PATH" <<'EOF'
@echo off
rem Directly run the orchestrator without invoking PI, to save RAM.
set "SKILL_ROOT=%USERPROFILE%\.pi\skills\bmad-super-spec"
set "ORCHESTRATOR=%SKILL_ROOT%\orchestrator.js"
node "%ORCHESTRATOR%" %*
EOF
  # No chmod needed on Windows
fi

# ---------------------------------------------------------------
# 3️⃣ Ensure the wrapper directory is in PATH (bash/zsh only for Unix)
# ---------------------------------------------------------------
if [[ "$OS_TYPE" == "Linux" || "$OS_TYPE" == "Darwin" ]]; then
  if [[ ":$PATH:" != *":$WRAPPER_DIR:"* ]]; then
    echo -e "\n\033[1;33mNOTE:\033[0m Adding $WRAPPER_DIR to your PATH for this session."
    export PATH="$WRAPPER_DIR:$PATH"
    # Also suggest persisting it for future shells
    if [[ "${SHELL}" == *bash* ]]; then
      echo "export PATH=\"$WRAPPER_DIR:\\$PATH\"" >> "${HOME}/.bashrc"
      info "Appended PATH export to ${HOME}/.bashrc"
    elif [[ "${SHELL}" == *zsh* ]]; then
      echo "export PATH=\"$WRAPPER_DIR:\\$PATH\"" >> "${HOME}/.zshrc"
      info "Appended PATH export to ${HOME}/.zshrc"
    fi
  fi
else
  # On native Windows the directory is already on PATH, but give a friendly reminder.
  info "The wrapper was placed in $WRAPPER_DIR which is normally on PATH. If the command is not found, restart your terminal or add the folder to the system PATH manually."
fi

# ---------------------------------------------------------------
# 4️⃣ Enable slash‑command / skill‑command support in PI settings
# ---------------------------------------------------------------
SETTINGS_FILE="$PI_ROOT/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
  if ! grep -q '"enableSkillCommands"' "$SETTINGS_FILE"; then
    info "Enabling skill commands in $SETTINGS_FILE"
    # Insert the flag before the final closing brace (simple append)
    tmp=$(mktemp)
    jq '.enableSkillCommands = true' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  fi
else
  info "Creating $SETTINGS_FILE with skill command enabled"
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{"enableSkillCommands": true}' > "$SETTINGS_FILE"
fi

# ---------------------------------------------------------------
# Finished – user can now run the wrapper or the direct PI command
# ---------------------------------------------------------------
