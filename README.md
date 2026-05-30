# BMad + Superpowers + Spec‑Kit Skill (`bmad‑super‑spec`)

A **single reusable PI skill** that orchestrates the three powerful open‑source projects you mentioned:

| Component | What we call it in this skill | Key CLI/skill used |
|-----------|------------------------------|--------------------|
| **BMad Method** | `bmad‑help`, `bmad‑party`, `bmad‑finish‑branch` | `npx bmad-method` (installed globally) |
| **Superpowers** | `brainstorming`, `writing‑plans`, `subagent‑driven‑development`, `test‑driven‑development` | Skills are auto‑loaded by the host agent (Claude, Cursor, etc.) |
| **Spec‑Kit** | `/speckit.*` commands | `specify` CLI (installed via `uv tool install specify-cli …`) |

## What the skill does
1. **Init** – prompts the developer for a project name, then runs the full pipeline:
   - Vision & constitution (BMad + Spec‑Kit)
   - Brainstorm & formal spec (Superpowers + Spec‑Kit)
   - Architecture & technical plan (BMad + Superpowers)
   - Task generation (`/speckit.tasks` → GitHub issues or local todo file)
   - Sub‑agent driven implementation with TDD and automatic reviews.
2. **Status** – reads a small JSON state file (`.bmad‑super‑spec/state.json`) and prints the current stage, last log line and path to the log file.
3. **Continue** – picks up from the saved stage (useful when a developer stopped the job, switched machines, or a CI build crashed).

## Quick‑start on a *new* host
```bash
# 1️⃣ Install the three upstream tools (once per host)
npm i -g bmad-method            # provides `bmad-help` etc.
uv tool install specify-cli      # provides `specify`
# Superpowers is a skill library – just make sure your agent (Claude, Cursor, …) loads the repo:
#   e.g. for Claude Code:   /plugin install superpowers@claude-plugins-official
#   for Cursor:             /add-plugin superpowers

# 2️⃣ Add this skill to PI (assuming Pi looks for skills under $PI_ROOT/skills)
mkdir -p $PI_ROOT/skills
cp -r /data/docker-data/pi-skills/bmad-super-spec $PI_ROOT/skills/

# 3️⃣ Verify the manifest is visible to PI
pi skill list   # should show `bmad-super-spec`
```

## Using the skill
```bash
# Start a new workflow (creates a folder with the same name as the project)
pi skill run bmad-super-spec init

# While it runs you can open another terminal and check progress
pi skill run bmad-super-spec status

# If the process stopped or you need to move to another machine, copy the project folder
# (contains .bmad-super-spec/state.json and the log file) and then:
pi skill run bmad-super-spec continue
```

## How resume works
- After each major step the orchestrator writes `state.json`:
  ```json
  {"stage":"writing‑plans","project":"my‑app","log":"/full/path/to/log.txt"}
  ```
- `continue` reads that file and jumps straight to the next step, skipping everything already completed.
- The log file is appended throughout the run, so developers can always `cat $log` to see exactly which external command was executed.

## Extending / customizing
- **Presets** – you can drop a `preset.json` inside the project folder to override default prompts (e.g., enforce a company‑wide security checklist).
- **Extensions** – add more Spec‑Kit extensions (Jira, V‑Model, etc.) and the orchestrator will automatically discover them because it calls `specify extension list` before generating tasks.

---
*Feel free to open an issue in this repo if you need a specific integration or run into a bug.*
