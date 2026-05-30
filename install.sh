#!/usr/bin/env bash
#=====================================================================
# bmad-super-spec – one‑click global installer
#=====================================================================
# Works on Linux, macOS, Windows (Git‑Bash / WSL)
# Performs:
#   1. Installs BMad Method (npm global)
#   2. Installs uv (Python tool manager)
#   3. Installs Spec‑Kit CLI via uv
#   4. Registers Superpowers skill for common agents
#   5. Copies the skill into the global PI skill directory
#   6. Installs a tiny wrapper (`bmad-super-spec-run`) on the PATH
#=====================================================================

set -euo pipefail

log()   { printf "\n\033[1;34m>> %s\033[0m\n" "$*"; }
ok()    { printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
warn()  { printf "\033[1;33m⚠ %s\033[0m\n" "$*"; }
error(){ printf "\033[1;31m✖ %s\033[0m\n" "$*"; exit 1; }

# ---------- Detect OS ----------
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
    Linux*)   OS=linux;;
    Darwin*)  OS=mac;;
    CYGWIN*|MINGW*|MSYS*) OS=windows;;
    *)        error "Unsupported OS: $OS_TYPE";;
esac
log "Detected OS: $OS"

# ---------- 1. Install BMad Method (npm) ----------
if command -v npx >/dev/null 2>&1 && npx --yes bmad-method --version >/dev/null 2>&1; then
    ok "BMad Method already installed (global npm)."
else
    log "Installing BMad Method (npm global package)..."
    npm i -g bmad-method
    ok "BMad Method installed."
fi

# ---------- 2. Install uv (Python tool manager) ----------
install_uv_unix() {
    if command -v brew >/dev/null 2>&1; then
        if brew list uv >/dev/null 2>&1; then ok "uv already installed via Homebrew."; return; fi
        log "Installing uv via Homebrew..."
        brew install uv && ok "uv installed (brew)." && return
    fi
    if command -v apt-get >/dev/null 2>&1; then
        if dpkg -s uv >/dev/null 2>&1; then ok "uv already installed via apt."; return; fi
        log "Installing uv via apt (sudo required)..."
        sudo apt-get update -qq && sudo apt-get install -y uv && ok "uv installed (apt)." && return
    fi
    if command -v dnf >/dev/null 2>&1; then
        if rpm -q uv >/dev/null 2>&1; then ok "uv already installed via dnf."; return; fi
        log "Installing uv via dnf (sudo required)..."
        sudo dnf install -y uv && ok "uv installed (dnf)." && return
    fi
    if command -v curl >/dev/null 2>&1; then
        log "Installing uv via official installer script (curl)..."
        curl -LsSf https://github.com/astral-sh/uv/releases/latest/download/uv-installer.sh | sh && ok "uv installed (script)." && return
    fi
    error "Cannot install uv – missing brew/apt/dnf/curl."
}
install_uv_windows() {
    if command -v winget >/dev/null 2>&1; then
        if winget list --id Astral.Sh.Uv | grep -q "Astral.Sh.Uv"; then ok "uv already installed via winget."; return; fi
        log "Installing uv via winget..."
        winget install -e --id Astral.Sh.Uv && ok "uv installed (winget)." && return
    fi
    if command -v scoop >/dev/null 2>&1; then
        if scoop list | grep -q "^uv"; then ok "uv already installed via scoop."; return; fi
        log "Installing uv via scoop..."
        scoop install uv && ok "uv installed (scoop)." && return
    fi
    log "Downloading uv binary for Windows..."
    TMPDIR=$(mktemp -d)
    cd "$TMPDIR"
    curl -L -o uv-installer.ps1 https://github.com/astral-sh/uv/releases/latest/download/uv-installer.ps1
    powershell -ExecutionPolicy Bypass -File uv-installer.ps1 && ok "uv installed (PowerShell)."
    cd - >/dev/null && rm -rf "$TMPDIR"
}

if [[ "$OS" == "windows" ]]; then install_uv_windows; else install_uv_unix; fi

# ---------- 3. Install Spec‑Kit CLI (via uv) ----------
if command -v specify >/dev/null 2>&1; then
    ok "Spec‑Kit CLI (specify) already present."
else
    log "Installing Spec‑Kit CLI via uv..."
    uv tool install specify-cli && ok "Spec‑Kit CLI installed."
fi

# ---------- 4. Register Superpowers (skill library) ----------
install_superpowers() {
    if command -v pi >/dev/null 2>&1; then
        log "Registering Superpowers via generic PI command…"
        pi skill install superpowers || true
        ok "Superpowers registered with PI."
        return
    fi
    # Claude Code detection (very naive)
    if pgrep -f "claude" >/dev/null 2>&1; then
        log "Installing Superpowers into Claude Code…"
        /plugin install superpowers@claude-plugins-official || true
        ok "Superpowers installed in Claude." && return
    fi
    # Cursor detection (again naive)
    if pgrep -f "cursor" >/dev/null 2>&1; then
        warn "Please run '/add-plugin superpowers' inside Cursor Agent chat."
        return
    fi
    if command -v gemini >/dev/null 2>&1; then
        log "Installing Superpowers into Gemini CLI…"
        gemini extensions install https://github.com/obra/superpowers && ok "Superpowers installed in Gemini."
        return
    fi
    warn "Automatic Superpowers registration failed. Please install it manually for your agent."
    cat <<'EOF'
  * Claude Code → /plugin install superpowers@claude-plugins-official
  * Cursor     → /add-plugin superpowers   (in the Agent chat)
  * Gemini CLI → gemini extensions install https://github.com/obra/superpowers
  * OpenCode   → follow docs/README.opencode.md
EOF
}
install_superpowers

# ---------- 5. Determine global PI skill directory ----------
PI_ROOT="${PI_ROOT:-${HOME}/.pi}"
log "Using PI_ROOT = $PI_ROOT"
mkdir -p "$PI_ROOT/skills"

# ---------- 6. Copy the skill globally ----------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$REPO_ROOT"
SKILL_DST="$PI_ROOT/skills/bmad-super-spec"
if [[ -d "$SKILL_DST" ]]; then
    SRC_VER=$(jq -r .version "$SKILL_SRC/manifest.json")
    DST_VER=$(jq -r .version "$SKILL_DST/manifest.json" 2>/dev/null || echo "0.0.0")
    if [[ "$SRC_VER" > "$DST_VER" ]]; then
        log "Updating existing skill (v$DST_VER → v$SRC_VER)…"
        rm -rf "$SKILL_DST"
        cp -R "$SKILL_SRC" "$SKILL_DST"
        ok "Skill updated to v$SRC_VER."
    else
        ok "Skill already present (v$DST_VER). No update needed."
    fi
else
    log "Copying skill into PI's global folder…"
    cp -R "$SKILL_SRC" "$SKILL_DST"
    ok "Skill installed globally."
fi

# ---------- 7. Install wrapper script on PATH ----------
install_wrapper() {
    if [[ "$OS" == "windows" ]]; then
        WRAPPER_DIR="${USERPROFILE}/AppData/Local/Microsoft/WindowsApps"
    else
        WRAPPER_DIR="${HOME}/.local/bin"
    fi
    mkdir -p "$WRAPPER_DIR"
    WRAPPER_PATH="${WRAPPER_DIR}/bmad-super-spec-run"
    cat >"$WRAPPER_PATH" <<'EOS'
#!/usr/bin/env bash
# Forward arguments to the PI skill
set -euo pipefail
PI_ROOT="${PI_ROOT:-${HOME}/.pi}"
pi skill run bmad-super-spec "$@"
EOS
    chmod +x "$WRAPPER_PATH"
    ok "Wrapper installed at $WRAPPER_PATH"
    if ! command -v bmad-super-spec-run >/dev/null 2>&1; then
        warn "Directory $WRAPPER_DIR is not on your PATH."
        cat <<'HINT'
Add the following line to your shell profile (e.g. ~/.bashrc, ~/.zshrc):
    export PATH="\$PATH:$WRAPPER_DIR"
Then reload the shell or run: source ~/.bashrc
HINT
    fi
}
install_wrapper

log "===================================================================="
log "🚀 Installation complete! 🎉"
log "You can now start the workflow with a single command, e.g.:"
cat <<'EXAMPLE'
    bmad-super-spec-run init          # start a brand‑new project
    bmad-super-spec-run status        # see current stage & log location
    bmad-super-spec-run continue      # resume a paused workflow
EXAMPLE
log "All logs are stored inside the project folder under .bmad-super-spec/run.log"
log "===================================================================="
