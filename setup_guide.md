# Project Setup Guide

Everything you need to run `setup_project.sh` and verify the result.

---

## What the Script Does

One command creates a fully structured Python project:

| Phase | What happens |
|---|---|
| 1 | Checks Python, Git, uv — offers to install missing tools |
| 2 | Collects project name, directory, GitHub URL from you |
| 3 | Initialises a `uv` Python project and virtual environment |
| 4 | Creates `.env`, `.env.example`, `.gitignore` |
| 5 | Creates the full directory structure |
| 6 | Creates `CLAUDE.md` with coding guidelines |
| 7 | Creates shared skill modules (`config.py`, `utils.py`, `state.json`) |
| 8 | Creates example Claude Code skills (orchestrator, data\_processor, report\_generator) |
| 9 | Creates `README.md` and `docs/SETUP.md` |
| 10 | Initialises Git, prompts for initial commit, optionally pushes to GitHub |
| 11 | Verifies all expected files and directories exist |

---

## Prerequisites

### Required

| Tool | Minimum version | Check | Install |
|---|---|---|---|
| **Bash** | any | `bash --version` | Pre-installed on Mac/Linux. Windows: use **Git Bash** or WSL |
| **Python** | 3.11+ | `python --version` | [python.org](https://www.python.org/downloads/) or [Anaconda](https://www.anaconda.com/download) |
| **Git** | 2.x+ | `git --version` | [git-scm.com](https://git-scm.com/downloads) |
| **uv** | any | `uv --version` | `pip install uv` or see below |

> The script will detect missing tools and offer to install them automatically.
> If you prefer to install manually first, that is recommended.

### Installing uv (recommended before running)

**Mac / Linux**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

**Via pip (any platform)**
```bash
pip install uv
```

After installing, restart your terminal so `uv` is on PATH.

### Optional

| Tool | Purpose |
|---|---|
| **GitHub account** | Push project to a remote repository |
| **VSCode** | Recommended editor; project is pre-configured for it |
| **Claude Code** | To use the skills created by the script |

### Windows-specific note

The script requires a **Unix-compatible shell**. Use one of:
- **Git Bash** — installed with Git for Windows (recommended)
- **WSL** (Windows Subsystem for Linux)
- **MSYS2**

Do **not** run the script in Command Prompt (`cmd`) or plain PowerShell.

---

## Running the Script

### Step 1 — Download the files

Place both files in the same folder:

```
my-folder/
├── setup_project.sh
└── setup_guide.md
```

### Step 2 — Open a terminal

- **Mac / Linux** — open Terminal and `cd` to the folder
- **Windows** — right-click the folder → **Git Bash Here**

### Step 3 — Make the script executable (first time only)

```bash
chmod +x setup_project.sh
```

### Step 4 — Run

```bash
bash setup_project.sh
```

---

## Interactive Prompts Walkthrough

The script will ask four questions, then confirm before doing anything.

### 1. Project name
```
Project name (e.g. My Cool Project): My Analytics Project
```
- Spaces are fine — the script converts to a safe Python package name automatically.
- Cannot be blank.

### 2. Project base directory
```
Default project base: /path/to/current/folder
Project base directory [press Enter to use default]:
```
- Press **Enter** to create the project inside the current folder.
- Or type an absolute path, e.g. `~/projects` — the script appends the project name.

### 3. GitHub repo URL (optional)
```
GitHub repo URL (leave blank to skip, e.g. https://github.com/user/repo.git):
```
- Leave blank to skip GitHub setup entirely.
- If provided, the script will offer to push after the initial commit.
- Create the repo on GitHub **before** running the script (create it empty, no README).

### 4. Confirmation summary
```
Summary:
  Project Name : My Analytics Project
  Package Name : my-analytics-project
  Directory    : /path/to/my-analytics-project
  Python       : C:\Users\you\anaconda3\python.exe

Continue with setup? (y/n)
```
- Review the paths. Type `y` to proceed, `n` to cancel with no changes made.

### 5. Initial commit (Phase 10)
```
Files that will be committed:
?? README.md
?? CLAUDE.md
?? .env
...

Create initial commit? (y/n)
```
- The file list comes from `git status --short` — `??` means untracked (new file).
- Type `y` to commit all generated files.
- If you provided a GitHub URL, a follow-up prompt asks whether to push.

---

## What Gets Created

```
<your-project-name>/
├── README.md                        # Project overview
├── CLAUDE.md                        # Coding guidelines for Claude Code
├── pyproject.toml                   # uv project file
├── uv.lock                          # Locked dependencies
├── .env                             # Local config — DO NOT COMMIT
├── .env.example                     # Config template — safe to commit
├── .gitignore
├── .claude/
│   └── skills/
│       ├── shared/
│       │   ├── config.py            # Shared path config (import in every script)
│       │   ├── utils.py             # StateManager for cross-skill data
│       │   └── state.json           # Runtime state shared between skills
│       ├── orchestrator/
│       │   └── SKILL.md
│       ├── data_processor/
│       │   └── SKILL.md
│       └── report_generator/
│           └── SKILL.md
├── data/
│   ├── input/                       # Read-only input files
│   ├── output/                      # Processed output
│   └── temp/                        # Intermediate / scratch files
├── scripts/                         # Your Python entry-point scripts go here
├── tests/                           # pytest test suite
├── logs/
└── docs/
    └── SETUP.md                     # Detailed setup reference
```

---

## Verification

The script runs its own verification at the end (Phase 11) and prints ✓ / ✗ for every expected file and directory.

To re-verify manually at any time:

```bash
cd <your-project-name>

# Check key files
for f in README.md CLAUDE.md .env .env.example .gitignore pyproject.toml \
          .claude/skills/shared/config.py .claude/skills/shared/utils.py \
          .claude/skills/shared/state.json docs/SETUP.md; do
  [ -f "$f" ] && echo "OK  $f" || echo "MISSING  $f"
done

# Check key directories
for d in data/input data/output data/temp logs scripts tests docs .claude/skills/shared; do
  [ -d "$d" ] && echo "OK  $d/" || echo "MISSING  $d/"
done

# Verify Python environment
uv run python -c "import sys; print('Python', sys.version)"
uv pip freeze
```

Expected output for a successful setup:
```
OK  README.md
OK  CLAUDE.md
OK  .env
...
Python 3.11.x ...
```

### Verify Git
```bash
git log --oneline        # should show the initial commit
git status               # should show clean working tree
```

---

## Post-Setup Next Steps

1. **Edit `.env`** with your actual values — the generated file has sensible defaults but paths are set at creation time.

2. **Add dependencies**
   ```bash
   uv add requests pandas    # example
   uv sync                   # sync after editing pyproject.toml manually
   ```

3. **Create your first script** in `scripts/`:
   ```python
   # scripts/main.py
   import sys
   sys.path.insert(0, '.claude/skills/shared')
   from config import Config

   print(Config.PROJECT_ROOT)
   ```
   Run it:
   ```bash
   uv run python scripts/main.py
   ```

4. **Connect to GitHub later** (if skipped during setup):
   ```bash
   git remote add origin https://github.com/<user>/<repo>.git
   git push -u origin main
   ```

5. **Open in Claude Code** and run a skill:
   ```
   /orchestrator
   ```

---

## Troubleshooting

### `python: command not found`
- Anaconda users: ensure Anaconda is initialised — run `conda init bash`, restart terminal.
- Windows: ensure Python is added to PATH during installation (tick the checkbox in the installer).

### `uv: command not found` after installing
- The installer adds uv to `~/.local/bin` (Linux/Mac) or `%USERPROFILE%\.local\bin` (Windows).
- Restart your terminal, or run `source ~/.bashrc` / `source ~/.zshrc`.

### `No interpreter found at path ...`
- This happens when uv receives a Unix-style path on Windows (e.g. `/c/Users/...` instead of `C:\Users\...`).
- The script converts paths automatically via `cygpath`. Ensure you are running in Git Bash, not WSL with a different Python.

### `SKILLS_DIR: unbound variable`
- Caused by an older version of the script. Update to the latest `setup_project.sh`.

### `EOF: command not found`
- Caused by an older version of the script. Update to the latest `setup_project.sh`.

### `git push` fails
- Check that the GitHub repository exists and is empty (no README, no commits).
- Verify your credentials: `git config --list | grep user`.
- Use a [personal access token](https://github.com/settings/tokens) if password authentication is rejected.

### Script exits immediately
- The script uses `set -e` (exit on error) and `set -u` (exit on undefined variable).
- Check the last printed error line — it will tell you exactly which check failed.
- Run with `bash -x setup_project.sh` for full debug trace.

---

## Package Contents

| File | Purpose |
|---|---|
| `setup_project.sh` | The automation script — run this |
| `setup_guide.md` | This guide — read before running |

Share both files together. The script is self-contained and works offline (except for GitHub push and optional tool installation).
