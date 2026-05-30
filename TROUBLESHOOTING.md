# Troubleshooting Guide for **bmad‑super‑spec**

This guide complements the main `README.md` and focuses on the most common issues you may encounter when installing or running the combined BMad + Superpowers + Spec‑Kit skill.

---

## Table of Contents
1️⃣ [Skill not listed in `pi skill list`](#skill-not-listed)
2️⃣ [Wrapper command not found (`bmad‑super‑spec‑run`)](#wrapper-not-found)
3️⃣ [AI chat UI pops up instead of running the skill](#ai-chat-instead)
4️⃣ [Missing dependencies (BMad, uv, Spec‑Kit)](#missing-deps)
5️⃣ [Superpowers registration fails](#superpowers-fail)
6️⃣ [Permission / sudo prompts on Linux](#sudo-permission)
7️⃣ [Windows PATH issues](#windows-path)
8️⃣ [Resuming a paused workflow fails](#resume-fail)
9️⃣ [Log / state files not created](#log-state-missing)
🔟 [General checklist](#checklist)

---

### 1️⃣ Skill not listed in `pi skill list` <a name="skill-not-listed"></a>
**Symptoms**
- Running `pi skill list` does not show `bmad‑super‑spec`.
- `bmad‑super‑spec‑run` prints usage but no workflow starts.

**Causes & Fixes**
| Cause | Fix |
|------|-----|
| Skill folder not copied to PI’s global directory. | Verify the folder exists: `ls -R $HOME/.pi/skills/bmad-super-spec`. If missing, copy it manually: `cp -R /path/to/bmad-super-spec $HOME/.pi/skills/`. |
| PI has not re‑loaded its skill cache. | Run `pi reload` (or simply restart the terminal). |
| `$PI_ROOT` environment variable points to a different location. | Export the correct path before installing: `export PI_ROOT=$HOME/.pi` and re‑run `install.sh`. |

---

### 2️⃣ Wrapper command not found (`bmad‑super‑spec‑run`) <a name="wrapper-not-found"></a>
**Symptoms**
- Shell says `command not found: bmad-super-spec-run`.
- `which bmad-super-spec-run` returns nothing.

**Fixes**
1. **Check installation directory**
   - Linux/macOS/Git‑Bash: `$HOME/.local/bin/bmad-super-spec-run`
   - Windows PowerShell: `%USERPROFILE%\AppData\Local\Microsoft\WindowsApps\bmad-super-spec-run`
2. **Add directory to PATH**
   ```bash
   # Linux/macOS/Git‑Bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
   ```
   ```powershell
   # PowerShell (run once)
   [Environment]::SetEnvironmentVariable('PATH', "$env:PATH;$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps", [EnvironmentVariableTarget]::User)
   ```
3. **Make it executable** (Linux/macOS) `chmod +x $HOME/.local/bin/bmad-super-spec-run`.

---

### 3️⃣ AI chat UI appears instead of executing the skill <a name="ai-chat-instead"></a>
**Why**
- The command was typed as a *slash command* (`/settings bmad-super-spec-run init`) in a terminal, which PI interprets as a request to open the chat interface.
- Or the wrapper fell back to the default `pi` behavior because the skill/sub‑command was not recognised.

**Solution**
- Use **plain shell syntax**, **not** a slash prefix:
  ```bash
  bmad-super-spec-run init
  # or
  pi skill run bmad-super-spec init
  ```
- If you really want to use a slash‑command inside a chat session, enable it in PI settings (see below).

---

### 4️⃣ Missing dependencies (BMad, uv, Spec‑Kit) <a name="missing-deps"></a>
**Symptom**
- `command not found: npx` / `bmad‑method` / `uv` / `specify` during `install.sh`.

**Fix**
- **Node / npm** – install from <https://nodejs.org>. After installation, reopen the terminal.
- **uv** – the installer tries `brew`, `apt`, `dnf`, then a curl script. If all fail, run the script manually:
  ```bash
  curl -LsSf https://github.com/astral-sh/uv/releases/latest/download/uv-installer.sh | sh
  ```
- **Spec‑Kit** – once `uv` is present, `uv tool install specify-cli` will work. Verify with `specify --version`.

---

### 5️⃣ Superpowers registration fails <a name="superpowers-fail"></a>
**Symptoms**
- `install.sh` prints a warning that it could not auto‑detect a supported agent.
- Later `pi skill list` shows `brainstorming`, `writing-plans`, etc. missing.

**Fix**
- Manually copy the Superpowers skill directory to the PI skill path:
  ```bash
  mkdir -p $HOME/.pi/agent/skills
  cp -r /data/docker-data/superpowers/skills $HOME/.pi/agent/skills/
  ```
- Verify with `pi skill list | grep brainstorming`.
- If you are using Claude Code, Cursor, Gemini, or OpenCode, follow the agent‑specific instructions in the **Superpowers README** (the installer prints them when it cannot auto‑detect).

---

### 6️⃣ Permission / sudo prompts on Linux <a name="sudo-permission"></a>
**Symptom**
- During `install.sh` you see: `sudo: a terminal is required to read the password`.

**Fix**
- Run the installer **interactively** (not via a non‑interactive CI job) so you can supply the password.
- Or skip the `apt` path; the script will fall back to the **curl installer** for uv, which does **not** need sudo (as shown in the successful run).
- If you prefer the `apt` route, run:
  ```bash
  sudo apt-get update && sudo apt-get install -y uv
  ```
  before re‑running `install.sh`.

---

### 7️⃣ Windows PATH issues <a name="windows-path"></a>
**Symptom**
- PowerShell says `'bmad-super-spec-run' is not recognized as the name of a cmdlet...`.

**Fix**
1. Verify the file exists:
   ```powershell
   Get-Item "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\bmad-super-spec-run" 
   ```
2. If present, add the directory to the user PATH (once):
   ```powershell
   $new = "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps"
   $env:Path += ";$new"
   [Environment]::SetEnvironmentVariable('PATH', $env:Path, [EnvironmentVariableTarget]::User)
   ```
3. Restart PowerShell (or open a new session) and run `bmad-super-spec-run init` again.

---

### 8️⃣ Resuming a paused workflow fails <a name="resume-fail"></a>
**Symptoms**
- `bmad-super-spec-run continue` exits with `No saved state found in current directory.`
- Or it crashes with `JSON parse error`.

**Causes**
- You are not inside the **project folder** that contains `.bmad-super-spec/state.json`.
- The state file got corrupted (partial write, manual edit).

**Fix**
- `cd` into the folder that was created during `init` (e.g., `my‑project`).
- If the state file is missing, you can restart the workflow with `bmad-super-spec-run init`.
- To recover a corrupted JSON, open the file, delete the bad line, and keep a minimal JSON like:
  ```json
  {"project":"my‑project","stage":"implement","completedStages":["vision‑constitution","brainstorm‑spec","architecture‑plan","generate‑tasks","implement"]}
  ```

---

### 9️⃣ Log / state files not created <a name="log-state-missing"></a>
**Symptoms**
- After running `init`, the directory `.bmad-super-spec/` does not contain `run.log` or `state.json`.

**Root cause**
- The orchestrator failed early (e.g., missing external command) and exited before the `runStage` helper wrote the files.

**Debug steps**
1. Run the workflow with verbose output:
   ```bash
   bmad-super-spec-run init 2>&1 | tee /tmp/debug-output.txt
   ```
2. Look at the tail of the output for the first `❌ Workflow error:` line.
3. Install the missing tool (npm, uv, specify, etc.) and retry.

---

## 🔟 General Checklist (run before you ship) <a name="checklist"></a>
1. **PI skill discovery** – `pi skill list | grep bmad-super-spec` shows the skill.
2. **Wrapper in PATH** – `which bmad-super-spec-run` returns a full path.
3. **Dependencies** – `npx bmad-method --version`, `uv --version`, `specify --version` all succeed.
4. **Superpowers** – `pi skill list | grep brainstorming` works.
5. **Test a quick run** – `bmad-super-spec-run init` creates a folder and a log file.
6. **Status works** – `bmad-super-spec-run status` prints stage and log location.
7. **Resume works** – `cd <project>` then `bmad-super-spec-run continue` finishes remaining stages.
8. **Cross‑platform** – repeat steps 1‑7 on a Windows Git‑Bash session to confirm no PATH issues.
9. **Documentation** – Ensure `README.md` contains the one‑line install instructions, and this `TROUBLESHOOTING.md` is present in the repo root.

---

**Happy hacking!** If you encounter an issue not covered here, feel free to open an issue on the repository and attach the relevant log (`run.log`) and `state.json`. The maintainer (me) will add the case to this guide.
