# Helper: How setup_project.sh Works

A plain-English walkthrough of every phase in the script so you know exactly what runs and why.

---

## Top of Script — Safety Settings

```bash
set -e   # stop immediately if any command fails
set -u   # stop immediately if any variable is used before being set
```

These two lines make the script safe. Without them, a silent failure (e.g. a path not found) could cascade and leave the project half-built in an unknown state. With them, the script stops at the first problem and tells you exactly where it failed.

---

## Helper Functions

Four print helpers wrap `echo` with ANSI color codes:

| Function | Color | Used for |
|---|---|---|
| `print_header` | Blue | Phase titles |
| `print_step` | Green ✓ | Successful actions |
| `print_warning` | Yellow ⚠ | Non-fatal issues (skipped steps, optional things) |
| `print_error` | Red ✗ | Failures |

Every message in the script goes through one of these so the output is easy to scan.

---

## PHASE 1 — Prerequisites Check

The script checks three tools before asking you anything. If a tool is missing it offers to install it — you are never surprised mid-setup.

### Python

1. Runs `which python`, then `which python3` — takes whichever is found first.
2. On Windows (Git Bash), converts the Unix-style path (`/c/Users/...`) to a Windows path (`C:\Users\...`) using `cygpath -w`. This is required because `uv` is a native Windows binary and cannot read Git Bash paths.
3. If Python is not found at all, offers to install via:
   - `winget` on Windows
   - `brew` on macOS
   - Prints the download URL and exits if neither package manager exists.

### Git

Same pattern — checks `command -v git`, offers `winget` / `brew` install if missing, exits if the user declines.

### uv

uv is the Python package manager the project uses instead of pip.

1. Checks `which uv` first (fastest path).
2. If not in PATH, searches a list of known install locations:
   - `~/.local/bin/uv` — Linux/Mac default
   - `~/.cargo/bin/uv` — Rust-based install
   - `Scripts/uv.exe` inside the Python folder — Windows Anaconda
   - `anaconda3/Scripts/` and `miniconda3/Scripts/` — common Anaconda locations
3. If still not found, offers to install via `pip install uv`, then re-scans the same locations.
4. Once found, adds uv's directory to `PATH` so the rest of the script can call `uv` by name.

---

## Project Configuration — User Prompts

Four questions are asked before anything is written to disk. You can review and cancel at the confirmation step — nothing is created until you say yes.

### 1. Project Name
```
Project name (e.g. My Cool Project): My Analytics Project
```
- Spaces are allowed in the name — it becomes the folder name as-is.
- The script automatically derives a Python-safe package name: `my-analytics-project` (lowercase, hyphens). This goes into `pyproject.toml`.
- Cannot be left blank — loops until you enter something.

### 2. Project Base Directory
```
Default project base: /path/to/current/folder
Project base directory [press Enter to use default]:
```
- Press Enter to use the folder the script lives in.
- Or type a path like `~/projects` — the script always appends the project name as a subfolder.
- Result: `~/projects/My Analytics Project/`

### 3. GitHub Repo URL (optional)
```
GitHub repo URL (leave blank to skip): https://github.com/user/repo.git
```
- Leave blank to skip GitHub entirely.
- If provided, the script parses out your username and repo name for use in Phase 10.
- **Important:** create the repo on GitHub before running the script, and leave it empty (no README, no commits).

### 4. Confirmation Summary
```
Summary:
  Project Name : My Analytics Project
  Package Name : my-analytics-project
  Directory    : /path/to/My Analytics Project
  Python       : C:\Users\you\anaconda3\python.exe

Continue with setup? (y/n)
```
- Review everything here. Type `y` to proceed, `n` to cancel with no changes made.

---

## PHASE 2 — Project Directory

```bash
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
```

Creates the project folder if it does not exist, then changes into it. From this point every file is written relative to the project root.

---

## PHASE 3 — uv Project Setup

```bash
uv init --python "$PYTHON_PATH" --name "$PACKAGE_NAME"
uv sync
```

- `uv init` creates `pyproject.toml` and a minimal starter file. Skipped if `pyproject.toml` already exists (safe to re-run the script).
- `uv sync` creates `.venv/` and installs all dependencies declared in `pyproject.toml`.
- Prints the first 5 installed packages so you can confirm the environment was created.

---

## PHASE 4 — Environment Files

Three files are created to manage configuration.

### `.env` — your local config (never commit this)

Written with variable expansion so real absolute paths are embedded:

```
PROJECT_ROOT=/home/you/My Analytics Project
DATA_DIR=/home/you/My Analytics Project/data
OUTPUT_DIR=/home/you/My Analytics Project/output
...
```

Also contains commented placeholders for GitHub tokens and API keys so you know where to add them later.

### `.env.example` — the template (safe to commit)

Written without variable expansion — contains generic placeholders like `~/my_project`. Team members copy this to `.env` and fill in their own values.

### `.gitignore`

Only created if one does not already exist. Covers:
- `.env` and local environment variants
- `.venv/` and virtual environment folders
- Python build artifacts (`__pycache__`, `*.pyc`, `dist/`, `*.egg-info/`)
- IDE folders (`.vscode/`, `.idea/`)
- Log files and data directories
- `state.json` (runtime state, not needed in git)

---

## PHASE 5 — Directory Structure

Loops through a fixed list and creates each folder with `mkdir -p`:

```
data/input          ← read-only input files go here
data/output         ← processed results
data/temp           ← intermediate / scratch files
logs/
.claude/skills/shared/
.claude/skills/orchestrator/
.claude/skills/data_processor/
.claude/skills/report_generator/
scripts/            ← your Python entry-point scripts
tests/              ← pytest test suite
docs/
```

Prints a warning (not an error) if a directory already exists — the script is safe to re-run.

---

## PHASE 6 — CLAUDE.md

Creates `CLAUDE.md` at the project root. This file is read by Claude Code at the start of every session — it is the AI's instruction manual for your project.

Contents:

| Section | What it contains |
|---|---|
| **Commands** | How to run, install, and test with `uv` |
| **Imports** | The `Config` pattern — never hardcode paths |
| **Python Guidelines** | Type hints, pathlib, early return, logging, env vars at startup |
| **Guardrails** | No `.env` commits, no hardcoded secrets, `INPUT_DIR` is read-only, no bare `except:` |
| **Testing** | `tmp_path` fixture, no live endpoints, cover failure paths |

---

## PHASE 7 — Shared Skill Modules

Three Python files written to `.claude/skills/shared/`. Every skill imports from this folder.

### `config.py`

- Loads `.env` once at import time using `python-dotenv`.
- `Config` class reads env vars and builds `pathlib.Path` objects for every directory.
- `ensure_dirs()` is called on import — so any skill that imports `Config` automatically creates its required directories.
- `print_config()` prints all paths for debugging.

```python
from config import Config
Config.INPUT_DIR    # Path object, fully resolved
Config.OUTPUT_DIR
Config.STATE_FILE
```

### `utils.py`

- `StateManager` class reads and writes `state.json`.
- Skills use this to pass data to each other without needing function arguments or global variables.

```python
from utils import StateManager
state = StateManager()
state.set_data("files_processed", 42)   # write
count = state.get_data("files_processed")  # read in next skill
```

Key methods:

| Method | Purpose |
|---|---|
| `set_skill_active(name)` | Mark a skill as currently running |
| `set_skill_complete(name, success)` | Record completion in history |
| `set_data(key, value)` | Store a value for the next skill to read |
| `get_data(key)` | Read a value written by a previous skill |
| `print_state()` | Dump full state JSON for debugging |

### `state.json`

Seed file with initial structure:
```json
{
  "status": "initialized",
  "current_skill": null,
  "data": {},
  "history": []
}
```

---

## PHASE 8 — Example Skills

Three `SKILL.md` files — one per skill directory. Each file has:

- **YAML front-matter** (`name`, `description`, `context`) — read by Claude Code to register the skill.
- **A Python code example** — shows how to import `Config` and `StateManager` and wire up the skill. These are starting templates, not finished code.

| Skill | Purpose |
|---|---|
| `orchestrator` | Runs all other skills in sequence, checks state between them |
| `data_processor` | Reads from `INPUT_DIR`, writes results to `OUTPUT_DIR` |
| `report_generator` | Reads previous skill's output from state, generates reports |

Invoke in Claude Code:
```
/orchestrator       ← runs all skills in order
/data_processor     ← runs one skill directly
/report_generator
```

---

## PHASE 9 — Documentation

### `docs/SETUP.md`

Manual setup steps for anyone who wants to understand what the script does under the hood — uv init, git commands, connecting GitHub. Also contains a project structure tree and useful command reference.

### `README.md`

Generated with your actual project name and GitHub URL expanded in. Contains:
- Project overview and tech stack
- Quick start (`uv sync` → edit `.env` → run)
- Annotated directory tree
- Environment variable table
- Skills command table
- Useful commands

If you provided a GitHub URL during setup, it is appended at the bottom of `README.md`.

---

## PHASE 10 — Git Initialisation

1. Checks if a git repo already exists (`git rev-parse --git-dir`) — skips everything if so.
2. Runs `git init` and `git branch -M main`.
3. Shows pending files via `git status --short`, then asks:
   ```
   Files that will be committed:
   ?? README.md
   ?? CLAUDE.md
   ...

   Create initial commit? (y/n)
   ```
   (`??` means untracked new file. `git status --short` is used instead of `git add -n` to avoid a broken-pipe error under `set -e`.)
4. If yes: stages all files and commits with the message:
   ```
   Initial project setup with uv, Claude Code, and shared skills configuration
   ```
5. If a GitHub URL was provided, asks a second question:
   ```
   Push to GitHub? (y/n)
   ```
   - Yes: adds the remote and pushes.
   - No: prints the manual commands to do it later.
6. If you decline the commit, prints the manual `git add . && git commit` command.

---

## PHASE 11 — Verification

Two loops run automatically:

**File check** — verifies each expected file exists:
```
README.md, CLAUDE.md, .env, .env.example, .gitignore,
pyproject.toml, config.py, utils.py, state.json,
orchestrator/SKILL.md, docs/SETUP.md
```

**Directory check** — verifies each expected folder exists:
```
data/input, data/output, data/temp, logs,
.claude/skills/shared, scripts, tests, docs
```

Each item prints a green ✓ (pass) or red ✗ (missing). If anything is missing, the final message changes from "All checks passed" to a warning.

---

## Final Summary

Prints:
- Project name, location, Python path
- Checklist of next steps (edit `.env`, add dependencies, create scripts, push to GitHub, use Claude skills)
- Overall pass/fail based on Phase 11

---

## Complete Flow at a Glance

```
START
  │
  ├─ Check Python ──── missing? offer to install ── declined? exit
  ├─ Check Git ─────── missing? offer to install ── declined? exit
  ├─ Check uv ──────── missing? offer to install ── declined? exit
  │
  ├─ Ask: project name, directory, GitHub URL
  ├─ Show summary ──── user says n? exit cleanly
  │
  ├─ Create project directory
  ├─ uv init + uv sync  (creates pyproject.toml + .venv)
  ├─ Write .env, .env.example, .gitignore
  ├─ Create all directories
  ├─ Write CLAUDE.md
  ├─ Write config.py, utils.py, state.json
  ├─ Write SKILL.md files (orchestrator, data_processor, report_generator)
  ├─ Write docs/SETUP.md + README.md
  │
  ├─ git init + git branch -M main
  ├─ Ask: create initial commit? ── yes → git add . && git commit
  │                                      └─ Ask: push to GitHub? ── yes → git push
  │
  ├─ Verify all files and directories
  └─ Print summary + next steps
```
