# Project Setup Guide — Linux / macOS

Everything you need to run `setup_project_linux.sh` and verify the result.

---

## What the Script Does

One command creates a fully structured Python project:

| Phase | What happens |
|---|---|
| 1 | Checks Python 3, Git, uv — offers to install missing tools via your distro's package manager |
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
| **Bash** | 4.x+ | `bash --version` | Pre-installed on all Linux distros and macOS |
| **Python** | 3.11+ | `python3 --version` | See distro-specific instructions below |
| **Git** | 2.x+ | `git --version` | See distro-specific instructions below |
| **uv** | any | `uv --version` | See instructions below |

> The script detects missing tools and offers to install them automatically using your distro's package manager.
> Installing manually first is recommended.

### Installing Python 3.11+

**Ubuntu / Debian**
```bash
sudo apt update
sudo apt install python3 python3-pip python3-venv
```

**Fedora**
```bash
sudo dnf install python3 python3-pip
```

**Arch Linux**
```bash
sudo pacman -Sy python python-pip
```

**openSUSE**
```bash
sudo zypper install python3 python3-pip
```

**macOS (Homebrew)**
```bash
brew install python
```

After installing, verify: `python3 --version` — must be 3.11 or higher.

### Installing Git

**Ubuntu / Debian**
```bash
sudo apt install git
```

**Fedora**
```bash
sudo dnf install git
```

**Arch Linux**
```bash
sudo pacman -Sy git
```

**openSUSE**
```bash
sudo zypper install git
```

**macOS**
```bash
brew install git
# or: xcode-select --install
```

### Installing uv

The official installer is the recommended method on Linux/macOS:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

After installing, reload your shell:
```bash
source ~/.bashrc    # bash
source ~/.zshrc     # zsh
```

Verify: `uv --version`

**Alternative — via pip:**
```bash
pip3 install uv
```

> Note: the curl installer places uv at `~/.local/bin/uv`. If `uv` is not found after install, add this to your shell profile:
> ```bash
> export PATH="$HOME/.local/bin:$PATH"
> ```

### Optional

| Tool | Purpose |
|---|---|
| **GitHub account** | Push the project to a remote repository |
| **VSCode** | Recommended editor; project is pre-configured |
| **Claude Code** | To use the skills created by the script |

---

## Running the Script

### Step 1 — Download the files

Place both files in the same folder:

```
my-folder/
├── setup_project_linux.sh
└── setup_guide_linux.md
```

### Step 2 — Open a terminal and navigate to the folder

```bash
cd /path/to/my-folder
```

### Step 3 — Make the script executable (first time only)

```bash
chmod +x setup_project_linux.sh
```

### Step 4 — Run

```bash
bash setup_project_linux.sh
```

---

## Interactive Prompts Walkthrough

The script asks four questions, then shows a summary before doing anything.

### 1. Project name
```
Project name (e.g. My Cool Project): My Analytics Project
```
- Spaces are allowed — the script converts to a safe Python package name automatically (`my-analytics-project`).
- Cannot be blank.

### 2. Project base directory
```
Default project base: /path/to/current/folder
Project base directory [press Enter to use default]:
```
- Press **Enter** to create the project inside the current folder.
- Or type an absolute path, e.g. `~/projects` — the script appends the project name automatically.

### 3. GitHub repo URL (optional)
```
GitHub repo URL (leave blank to skip, e.g. https://github.com/user/repo.git):
```
- Leave blank to skip GitHub entirely.
- If provided, the script offers to push after the initial commit.
- Create the GitHub repo **before** running the script — create it empty (no README, no .gitignore).

### 4. Confirmation summary
```
Summary:
  Project Name : My Analytics Project
  Package Name : my-analytics-project
  Directory    : /home/you/projects/My Analytics Project
  Python       : /usr/bin/python3

Continue with setup? (y/n)
```
- Review paths. Type `y` to proceed, `n` to cancel — nothing is written until you confirm.

### 5. Initial commit prompt (Phase 10)
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
- If a GitHub URL was provided, a follow-up prompt asks whether to push.

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

The script runs its own verification at the end (Phase 11) and prints a pass/fail for every expected file and directory.

To re-verify manually at any time:

```bash
cd "<your-project-name>"

# Check key files
for f in README.md CLAUDE.md .env .env.example .gitignore pyproject.toml \
          .claude/skills/shared/config.py .claude/skills/shared/utils.py \
          .claude/skills/shared/state.json docs/SETUP.md; do
  [ -f "$f" ] && echo "OK      $f" || echo "MISSING $f"
done

# Check key directories
for d in data/input data/output data/temp logs scripts tests docs .claude/skills/shared; do
  [ -d "$d" ] && echo "OK      $d/" || echo "MISSING $d/"
done

# Verify Python environment
uv run python3 -c "import sys; print('Python', sys.version)"
uv pip freeze
```

Expected output for a successful setup:
```
OK      README.md
OK      CLAUDE.md
OK      .env
...
Python 3.11.x (main, ...) ...
```

### Verify Git
```bash
git log --oneline    # should show the initial commit
git status           # should show: nothing to commit, working tree clean
```

### Verify virtual environment
```bash
source .venv/bin/activate
python3 -c "import sys; print(sys.prefix)"   # should print the .venv path
deactivate
```

---

## Post-Setup Next Steps

1. **Edit `.env`** — the generated file has your project path pre-filled, but review and add any API keys or custom settings.

2. **Add dependencies**
   ```bash
   uv add requests pandas    # example
   uv sync                   # re-sync after editing pyproject.toml manually
   ```

3. **Create your first script** in `scripts/`:
   ```python
   # scripts/main.py
   import sys
   sys.path.insert(0, '.claude/skills/shared')
   from config import Config

   print(Config.PROJECT_ROOT)
   print(Config.INPUT_DIR)
   ```
   Run it:
   ```bash
   uv run python3 scripts/main.py
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

### `python3: command not found`
- Install Python 3 using your distro's package manager (see Prerequisites above).
- On some systems Python 3 is installed as `python` — the script checks both.

### `uv: command not found` after installing
- The curl installer adds uv to `~/.local/bin`. Add it to your PATH permanently:
  ```bash
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  source ~/.bashrc
  ```
  For zsh users replace `.bashrc` with `.zshrc`.

### `curl: command not found`
- Install curl first:
  ```bash
  sudo apt install curl      # Ubuntu/Debian
  sudo dnf install curl      # Fedora
  sudo pacman -Sy curl       # Arch
  ```
- Or install uv via pip as an alternative: `pip3 install uv`

### `Permission denied` when running the script
- The script was not made executable. Run:
  ```bash
  chmod +x setup_project_linux.sh
  ```

### `sudo: command not found` (rare, minimal containers)
- Install sudo: `apt-get install sudo` (as root), or install packages directly as root.

### `uv init` fails with Python version error
- uv could not find Python 3.11+. Check: `python3 --version`
- If your distro ships an older Python, install 3.11+ manually or via `pyenv`:
  ```bash
  curl https://pyenv.run | bash
  pyenv install 3.11
  pyenv global 3.11
  ```

### `git push` fails
- Ensure the GitHub repository exists and is **empty** (no README, no commits on GitHub side).
- Verify your git identity is configured:
  ```bash
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  ```
- GitHub no longer accepts password authentication. Use a **personal access token**:
  - Generate at: https://github.com/settings/tokens
  - Use the token as your password when prompted, or configure credential storage:
    ```bash
    git config --global credential.helper store
    ```

### Script exits immediately with no clear message
- The script uses `set -e` (exit on error) and `set -u` (exit on undefined variable).
- Run with debug tracing to see exactly which line failed:
  ```bash
  bash -x setup_project_linux.sh 2>&1 | head -50
  ```

### `bad interpreter: /bin/bash^M: no such file or directory`
- The script has Windows line endings (CRLF). Convert them:
  ```bash
  sed -i 's/\r//' setup_project_linux.sh
  ```
  Or: `dos2unix setup_project_linux.sh` (install with `sudo apt install dos2unix`)

---

## Package Contents

| File | Purpose |
|---|---|
| `setup_project_linux.sh` | The automation script — run this |
| `setup_guide_linux.md` | This guide — read before running |

Share both files together. The script is self-contained and works offline (except for GitHub push and optional tool installation).
