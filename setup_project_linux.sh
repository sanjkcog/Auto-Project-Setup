#!/bin/bash

################################################################################
# PROJECT SETUP AUTOMATION SCRIPT — LINUX / macOS
#
# Platform: Linux (Ubuntu, Debian, Fedora, Arch) and macOS
# For Windows use: setup_project.sh (run in Git Bash)
#
# Purpose: Complete one-command project initialization with:
# - uv (Python package manager)
# - Git (local + remote setup)
# - Environment variables (.env file)
# - Claude Code configuration (CLAUDE.md)
# - Shared skill configuration
#
# Usage: bash setup_project_linux.sh
#
# Prerequisites:
# - Python 3.11+  (https://www.python.org/downloads/)
# - Git           (https://git-scm.com/downloads)
# - uv            (curl -LsSf https://astral.sh/uv/install.sh | sh)
#
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Detect Linux distro package manager
detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo ""
    fi
}

# Install a package using the detected package manager
pkg_install() {
    local pkg="$1"
    local mgr
    mgr=$(detect_pkg_manager)
    case "$mgr" in
        apt)     sudo apt-get install -y "$pkg" ;;
        dnf)     sudo dnf install -y "$pkg" ;;
        yum)     sudo yum install -y "$pkg" ;;
        pacman)  sudo pacman -Sy --noconfirm "$pkg" ;;
        zypper)  sudo zypper install -y "$pkg" ;;
        brew)    brew install "$pkg" ;;
        *)
            print_error "No supported package manager found (apt/dnf/yum/pacman/zypper/brew)."
            return 1
            ;;
    esac
}

# Configuration — collected interactively below after prerequisites check
PROJECT_NAME=""
PROJECT_DIR=""
GITHUB_REPO_URL=""
GITHUB_USERNAME=""
GITHUB_REPO=""

# Detect the directory where this script lives — used as the default project base
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

################################################################################
# PHASE 1: PREREQUISITES CHECK
################################################################################

print_header "PHASE 1: Checking Prerequisites"

echo "Checking required tools..."

# ── Python ───────────────────────────────────────────────────────────────────
# Prefer python3; fall back to python only if it is Python 3
PYTHON_PATH=$(which python3 2>/dev/null || "")
if [ -z "$PYTHON_PATH" ]; then
    _py=$(which python 2>/dev/null || "")
    if [ -n "$_py" ] && "$_py" -c "import sys; sys.exit(0 if sys.version_info.major==3 else 1)" 2>/dev/null; then
        PYTHON_PATH="$_py"
    fi
fi

if [ -z "$PYTHON_PATH" ]; then
    print_error "Python 3 not found in PATH"
    echo "Python 3.11+ is required."
    read -p "Would you like to install Python now? (y/n) " -n 1 -r </dev/tty
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mgr=$(detect_pkg_manager)
        case "$mgr" in
            apt)
                sudo apt-get update -qq
                sudo apt-get install -y python3 python3-pip python3-venv
                ;;
            dnf|yum)
                sudo "$mgr" install -y python3 python3-pip
                ;;
            pacman)
                sudo pacman -Sy --noconfirm python python-pip
                ;;
            zypper)
                sudo zypper install -y python3 python3-pip
                ;;
            brew)
                brew install python
                ;;
            *)
                echo "No supported package manager found. Install Python manually:"
                echo "  https://www.python.org/downloads/"
                exit 1
                ;;
        esac
        PYTHON_PATH=$(which python3 2>/dev/null || which python 2>/dev/null || "")
        if [ -z "$PYTHON_PATH" ]; then
            print_error "Python installation failed or not in PATH. Restart terminal and retry."
            exit 1
        fi
    else
        print_warning "Install Python 3.11+ and re-run: https://www.python.org/downloads/"
        exit 1
    fi
fi

# Verify it is Python 3
PY_VERSION=$("$PYTHON_PATH" -c "import sys; print(sys.version)" 2>&1)
if ! "$PYTHON_PATH" -c "import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)" 2>/dev/null; then
    print_warning "Python found but version may be below 3.11: $PY_VERSION"
    print_warning "uv will select an appropriate version automatically."
fi
print_step "Python found at: $PYTHON_PATH ($PY_VERSION)"

# ── Git ───────────────────────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
    print_error "git not found in PATH"
    read -p "Would you like to install Git now? (y/n) " -n 1 -r </dev/tty
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pkg_install git
        if ! command -v git &>/dev/null; then
            print_error "Git installation failed. Restart terminal and retry."
            exit 1
        fi
    else
        print_warning "Install Git and re-run: https://git-scm.com/downloads"
        exit 1
    fi
fi
print_step "git found at: $(which git)"

# ── uv ────────────────────────────────────────────────────────────────────────
UV_PATH=$(which uv 2>/dev/null || "")

if [ -z "$UV_PATH" ]; then
    # Check common install locations
    for candidate in \
        "$HOME/.local/bin/uv" \
        "$HOME/.cargo/bin/uv" \
        "$(dirname "$PYTHON_PATH")/uv"; do
        if [ -f "$candidate" ] && "$candidate" --version &>/dev/null 2>&1; then
            UV_PATH="$candidate"
            break
        fi
    done
fi

if [ -z "$UV_PATH" ]; then
    print_error "uv not found"
    echo "uv is required as the Python package manager."
    read -p "Would you like to install uv now? (y/n) " -n 1 -r </dev/tty
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v curl &>/dev/null; then
            echo "Installing uv via official installer..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
            # Installer places uv in ~/.local/bin
            export PATH="$HOME/.local/bin:$PATH"
            UV_PATH=$(which uv 2>/dev/null || "$HOME/.local/bin/uv")
        else
            echo "curl not found. Installing uv via pip..."
            "$PYTHON_PATH" -m pip install uv --quiet
            UV_PATH=$(which uv 2>/dev/null || "$(dirname "$PYTHON_PATH")/uv" || "")
        fi
        if [ -z "$UV_PATH" ] || ! "$UV_PATH" --version &>/dev/null 2>&1; then
            print_error "uv installation failed. Restart terminal and retry."
            print_warning "Manual install: curl -LsSf https://astral.sh/uv/install.sh | sh"
            exit 1
        fi
    else
        print_warning "Install uv and re-run: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
fi

UV_VERSION=$("$UV_PATH" --version 2>&1)
print_step "uv found at: $UV_PATH ($UV_VERSION)"

# Make uv callable by name for the rest of the script
export PATH="$(dirname "$UV_PATH"):$PATH"

################################################################################
# COLLECT PROJECT CONFIGURATION FROM USER
################################################################################

print_header "Project Configuration"

# Project name
while [ -z "$PROJECT_NAME" ]; do
    read -p "Project name (e.g. My Cool Project): " PROJECT_NAME </dev/tty
    if [ -z "$PROJECT_NAME" ]; then
        print_warning "Project name cannot be empty."
    fi
done
# Derive a valid Python package name for uv/pyproject.toml
PACKAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-_')

# Project base directory
echo "Default project base: $SCRIPT_DIR"
read -p "Project base directory [press Enter to use default]: " PROJECT_DIR </dev/tty
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
PROJECT_DIR="${PROJECT_DIR%/}/$PROJECT_NAME"
print_step "Project will be created at: $PROJECT_DIR"

# GitHub repo URL (optional)
read -p "GitHub repo URL (leave blank to skip, e.g. https://github.com/user/repo.git): " GITHUB_REPO_URL </dev/tty
if [ -n "$GITHUB_REPO_URL" ]; then
    GITHUB_USERNAME=$(echo "$GITHUB_REPO_URL" | sed -E 's|https://github.com/([^/]+)/.*|\1|')
    GITHUB_REPO=$(echo "$GITHUB_REPO_URL" | sed -E 's|https://github.com/[^/]+/([^/]+)(\.git)?$|\1|')
    print_step "GitHub: $GITHUB_USERNAME / $GITHUB_REPO"
else
    print_warning "GitHub setup skipped — add a remote later: git remote add origin <url>"
fi

echo ""
echo "Summary:"
echo "  Project Name : $PROJECT_NAME"
echo "  Package Name : $PACKAGE_NAME  (used in pyproject.toml)"
echo "  Directory    : $PROJECT_DIR"
echo "  Python       : $PYTHON_PATH"
[ -n "$GITHUB_REPO_URL" ] && echo "  GitHub URL   : $GITHUB_REPO_URL"
echo ""
read -p "Continue with setup? (y/n) " -n 1 -r </dev/tty
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Setup cancelled"
    exit 0
fi

################################################################################
# PHASE 2: PROJECT INITIALIZATION
################################################################################

print_header "PHASE 2: Project Initialization"

if [ ! -d "$PROJECT_DIR" ]; then
    print_step "Creating project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"
PROJECT_ROOT=$(pwd)
print_step "Working directory: $PROJECT_ROOT"

################################################################################
# PHASE 3: UV INITIALIZATION
################################################################################

print_header "PHASE 3: UV Project Setup"

if [ ! -f "pyproject.toml" ]; then
    print_step "Initializing uv project"
    uv init --python "$PYTHON_PATH" --name "$PACKAGE_NAME" --vcs none
else
    print_warning "pyproject.toml already exists, skipping uv init"
fi

print_step "Running uv sync to create virtual environment"
uv sync

print_step "Listing installed packages"
uv pip freeze | head -5
echo "  ..."

################################################################################
# PHASE 4: ENVIRONMENT CONFIGURATION
################################################################################

print_header "PHASE 4: Environment Configuration"

cat > ".env" << EOF
# ========================================
# PROJECT ENVIRONMENT VARIABLES
# ========================================
# DO NOT COMMIT THIS FILE TO GIT

# === DIRECTORIES ===
PROJECT_ROOT=${PROJECT_ROOT}
PROJECT_NAME=${PROJECT_NAME}
DATA_DIR=${PROJECT_ROOT}/data
OUTPUT_DIR=${PROJECT_ROOT}/output
TEMP_DIR=${PROJECT_ROOT}/temp
LOGS_DIR=${PROJECT_ROOT}/logs

# === SKILLS CONFIGURATION ===
SKILLS_DIR=${PROJECT_ROOT}/.claude/skills
SHARED_SKILLS_DIR=${PROJECT_ROOT}/.claude/skills/shared
STATE_FILE=${PROJECT_ROOT}/.claude/skills/shared/state.json

# === SETTINGS ===
DEBUG=False
LOG_LEVEL=INFO
PYTHON_VERSION=3.11

# === GITHUB (optional) ===
# GITHUB_USERNAME=your_username
# GITHUB_TOKEN=your_token

# === API KEYS (optional) ===
# ANTHROPIC_API_KEY=sk-ant-...
# OPENAI_API_KEY=sk-...
EOF

print_step "Created .env file"

cat > ".env.example" << 'EOF'
# ========================================
# PROJECT ENVIRONMENT VARIABLES (Template)
# ========================================
# Copy this file to .env and fill in your values

PROJECT_ROOT=~/my_project
PROJECT_NAME=my_project
DATA_DIR=${PROJECT_ROOT}/data
OUTPUT_DIR=${PROJECT_ROOT}/output
TEMP_DIR=${PROJECT_ROOT}/temp
LOGS_DIR=${PROJECT_ROOT}/logs

# OPTIONAL
GITHUB_USERNAME=your_username
GITHUB_TOKEN=your_token
DEBUG=False
LOG_LEVEL=INFO
EOF

print_step "Created .env.example"

if [ ! -f ".gitignore" ]; then
    cat > ".gitignore" << 'EOF'
# Environment
.env
.env.local
.env.*.local
*.venv
.venv
venv/
ENV/
env/

# UV
uv.lock

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
pip-wheel-metadata/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Testing
.pytest_cache/
.coverage
htmlcov/

# Logs
logs/
*.log

# Data
data/
output/
temp/

# Claude Code
.claude/skills/shared/state.json
EOF
    print_step "Created .gitignore"
else
    print_warning ".gitignore already exists"
fi

################################################################################
# PHASE 5: DIRECTORY STRUCTURE
################################################################################

print_header "PHASE 5: Creating Directory Structure"

dirs_to_create=(
    "data/input"
    "data/output"
    "data/temp"
    "logs"
    ".claude/skills/shared"
    ".claude/skills/orchestrator"
    ".claude/skills/data_processor"
    ".claude/skills/report_generator"
    "scripts"
    "tests"
    "docs"
)

for dir in "${dirs_to_create[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_step "Created directory: $dir"
    else
        print_warning "Directory already exists: $dir"
    fi
done

################################################################################
# PHASE 6: CLAUDE CODE CONFIGURATION
################################################################################

print_header "PHASE 6: Claude Code Configuration"

cat > "CLAUDE.md" << 'EOF'
# CLAUDE.md

## Commands
```bash
uv run python <script>          # run a script
uv add <package>                # add dependency (never pip install)
uv sync                         # install from lock file
uv run pytest tests/ -v         # run tests
```

## Imports
All scripts import shared config — never hardcode paths:
```python
from config import Config
# Config.INPUT_DIR | Config.OUTPUT_DIR | Config.TEMP_DIR | Config.LOGS_DIR | Config.STATE_FILE
```
Cross-skill data goes through `StateManager` in `.claude/skills/shared/utils.py`.

## Python Guidelines
- Python 3.11+. Type-hint every function signature.
- Use `pathlib.Path` for all paths — never string concatenation.
- One function, one responsibility. Keep functions under 30 lines.
- Return early to avoid deep nesting (max 2–3 levels).
- Use `with` blocks for all file I/O.
- Log via `logging` module. No `print()` in production code.
- Load env vars once at startup via `python-dotenv`. Never call `os.getenv` inside functions.
- Raise specific exceptions (`ValueError`, `FileNotFoundError`, `RuntimeError`). Never bare `except:`.
- No `import *`. No mutable default arguments.

## Guardrails
- Never commit `.env` — only `.env.example` goes to git.
- Never hardcode credentials, tokens, or API keys.
- Never mutate `Config` class attributes at runtime.
- Never call `sys.exit()` inside library or skill functions — only in `if __name__ == "__main__"` blocks.
- Never write to `INPUT_DIR` — it is read-only input. Write only to `OUTPUT_DIR` or `TEMP_DIR`.
- Never swallow exceptions silently (`except: pass`).

## Testing
- One test file per module: `tests/test_<module>.py`.
- Cover edge cases and failure paths, not only the happy path.
- Use `tmp_path` pytest fixture for file I/O — never write to real project dirs.
- Mock external API calls. Never hit live endpoints in tests.
- All tests must pass before committing: `uv run pytest tests/ -v`.
EOF

print_step "Created CLAUDE.md"

################################################################################
# PHASE 7: SHARED SKILL MODULES
################################################################################

print_header "PHASE 7: Creating Shared Skill Modules"

cat > ".claude/skills/shared/config.py" << 'EOF'
"""
config.py - Shared configuration for all skills
Every skill imports this to get expanded paths
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env once at module import
dotenv_path = os.path.join(os.path.dirname(__file__), '../../../.env')
load_dotenv(dotenv_path)

class Config:
    """Central configuration - read environment variables ONCE"""

    PROJECT_ROOT = Path(os.path.expandvars(
        os.getenv('PROJECT_ROOT', os.path.expanduser('~/my_project'))
    ))

    PROJECT_NAME = os.getenv('PROJECT_NAME', 'my_project')

    DATA_DIR = PROJECT_ROOT / os.path.expandvars(
        os.getenv('DATA_DIR', '${PROJECT_ROOT}/data')
    )

    INPUT_DIR  = DATA_DIR / 'input'
    OUTPUT_DIR = DATA_DIR / 'output'
    TEMP_DIR   = DATA_DIR / 'temp'
    LOGS_DIR   = PROJECT_ROOT / os.path.expandvars(
        os.getenv('LOGS_DIR', '${PROJECT_ROOT}/logs')
    )

    STATE_FILE = PROJECT_ROOT / '.claude/skills/shared/state.json'

    DEBUG          = os.getenv('DEBUG', 'False').lower() == 'true'
    LOG_LEVEL      = os.getenv('LOG_LEVEL', 'INFO')
    PYTHON_VERSION = os.getenv('PYTHON_VERSION', '3.11')

    @classmethod
    def ensure_dirs(cls):
        for directory in [cls.DATA_DIR, cls.INPUT_DIR, cls.OUTPUT_DIR,
                          cls.TEMP_DIR, cls.LOGS_DIR]:
            directory.mkdir(parents=True, exist_ok=True)

    @classmethod
    def print_config(cls):
        print("=== Configuration ===")
        for attr in ('PROJECT_ROOT','PROJECT_NAME','DATA_DIR','INPUT_DIR',
                     'OUTPUT_DIR','TEMP_DIR','LOGS_DIR','STATE_FILE',
                     'DEBUG','LOG_LEVEL'):
            print(f"{attr}: {getattr(cls, attr)}")

Config.ensure_dirs()
EOF

print_step "Created config.py"

cat > ".claude/skills/shared/utils.py" << 'EOF'
"""
utils.py - Shared utilities for all skills
StateManager - manages state.json for all skills
"""

import json
from pathlib import Path
from datetime import datetime
from typing import Dict, Any
from config import Config

class StateManager:
    """Manages shared state file between skills"""

    def __init__(self):
        self.state_file = Config.STATE_FILE
        self._init_state()

    def _init_state(self):
        if not self.state_file.exists():
            self.save({
                "status": "initialized",
                "current_skill": None,
                "timestamp": datetime.now().isoformat(),
                "data": {},
                "history": []
            })

    def load(self) -> Dict[str, Any]:
        if not self.state_file.exists():
            self._init_state()
        with open(self.state_file, 'r') as f:
            return json.load(f)

    def save(self, state: Dict[str, Any]):
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)

    def set_skill_active(self, skill_name: str):
        state = self.load()
        state.update({'current_skill': skill_name, 'status': 'running',
                      'timestamp': datetime.now().isoformat()})
        self.save(state)

    def set_skill_complete(self, skill_name: str, success: bool, message: str = ""):
        state = self.load()
        state['history'].append({
            "skill": skill_name,
            "status": "success" if success else "error",
            "message": message,
            "timestamp": datetime.now().isoformat()
        })
        if not success:
            state['status'] = 'error'
        self.save(state)

    def set_pipeline_complete(self, success: bool, message: str = ""):
        """Mark the entire pipeline as finished — call this at the end of orchestrator"""
        state = self.load()
        state['status'] = 'success' if success else 'error'
        state['current_skill'] = None
        state['timestamp'] = datetime.now().isoformat()
        if message:
            state['message'] = message
        self.save(state)

    def set_data(self, key: str, value: Any):
        state = self.load()
        state['data'][key] = value
        self.save(state)

    def get_data(self, key: str) -> Any:
        return self.load().get('data', {}).get(key)

    def print_state(self):
        print(json.dumps(self.load(), indent=2))
EOF

print_step "Created utils.py"

cat > ".claude/skills/shared/state.json" << 'EOF'
{
  "status": "initialized",
  "current_skill": null,
  "timestamp": "2024-01-15T00:00:00Z",
  "data": {},
  "history": []
}
EOF

print_step "Created state.json"

################################################################################
# PHASE 8: EXAMPLE SKILLS
################################################################################

print_header "PHASE 8: Creating Example Skills"

cat > ".claude/skills/orchestrator/SKILL.md" << 'EOF'
---
name: orchestrator
description: Master skill - runs all other skills in sequence with shared state
context: editor
---

# Orchestrator Skill

## Usage
```
/orchestrator
```

## Implementation
```python
import sys
sys.path.insert(0, '../shared')
from config import Config
from utils import StateManager

Config.print_config()
state = StateManager()
state.set_skill_active("orchestrator")

skills = ["data_processor", "report_generator"]
pipeline_ok = True

for skill in skills:
    print(f"\nRunning {skill}...")
    state.set_skill_active(skill)
    # invoke /skill here

    if state.load()['status'] == 'error':
        print(f"ERROR: {skill} failed — stopping pipeline")
        pipeline_ok = False
        break
    print(f"✓ {skill} completed")

# Mark pipeline complete — sets top-level status to 'success' or 'error'
state.set_pipeline_complete(success=pipeline_ok)

print("\n=== Execution Summary ===")
state.print_state()
```
EOF

print_step "Created orchestrator/SKILL.md"

cat > ".claude/skills/data_processor/SKILL.md" << 'EOF'
---
name: data_processor
description: Process input data files
context: editor
---

# Data Processor Skill

## Usage
```
/data_processor
```

## Implementation
```python
import sys
sys.path.insert(0, '../shared')
from config import Config
from utils import StateManager

state = StateManager()
state.set_skill_active("data_processor")

input_files = list(Config.INPUT_DIR.glob("*.csv"))
print(f"Found {len(input_files)} files in {Config.INPUT_DIR}")

# TODO: Add processing logic

state.set_data("files_processed", len(input_files))
state.set_skill_complete("data_processor", success=True)
```
EOF

print_step "Created data_processor/SKILL.md"

cat > ".claude/skills/report_generator/SKILL.md" << 'EOF'
---
name: report_generator
description: Generate reports from processed data
context: editor
---

# Report Generator Skill

## Usage
```
/report_generator
```

## Implementation
```python
import sys
sys.path.insert(0, '../shared')
from config import Config
from utils import StateManager

state = StateManager()
state.set_skill_active("report_generator")

files_processed = state.get_data("files_processed")
print(f"Files processed: {files_processed}")
print(f"Writing reports to: {Config.OUTPUT_DIR}")

# TODO: Add report generation logic

state.set_skill_complete("report_generator", success=True)
```
EOF

print_step "Created report_generator/SKILL.md"

################################################################################
# PHASE 9: DOCUMENTATION
################################################################################

print_header "PHASE 9: Creating Documentation"

cat > "docs/SETUP.md" << 'EOF'
# Project Setup Guide

## Quick Start
```bash
bash setup_project_linux.sh
```

## Manual Setup

```bash
# 1. Create and activate venv
uv init --python python3 --vcs none
uv sync
source .venv/bin/activate

# 2. Configure environment
cp .env.example .env
# Edit .env with your values

# 3. Git
git init
git add .
git commit -m "Initial commit"
git branch -M main

# 4. GitHub (optional)
git remote add origin https://github.com/username/repo.git
git push -u origin main
```

## Useful Commands
```bash
uv add <package>           # add dependency
uv run python <script>     # run script
uv run pytest tests/ -v    # run tests
uv sync                    # sync dependencies
source .venv/bin/activate  # activate venv manually
```

For more information, see:
- README.md  - Project overview and structure
- CLAUDE.md  - Coding guidelines for Claude Code
- .claude/skills/*/SKILL.md - Skill documentation
EOF

print_step "Created docs/SETUP.md"

# Create README.md
cat > "README.md" << EOF
# ${PROJECT_NAME}

## Overview

This project uses:
- **uv** for Python package management
- **Python 3.11+**
- **python-dotenv** for environment configuration
- **Claude Code skills** for multi-step workflow automation

## Quick Start

\`\`\`bash
uv sync                        # install dependencies
cp .env.example .env           # configure environment
uv run python scripts/main.py  # run project
\`\`\`

## Project Structure

\`\`\`
${PROJECT_NAME}/
├── .env                   # local config (do not commit)
├── .env.example           # config template
├── .gitignore
├── CLAUDE.md              # Claude Code coding guidelines
├── pyproject.toml
├── uv.lock
├── .claude/
│   └── skills/
│       ├── shared/        # config.py, utils.py, state.json
│       ├── orchestrator/
│       ├── data_processor/
│       └── report_generator/
├── data/
│   ├── input/             # read-only input files
│   ├── output/            # processed output
│   └── temp/              # intermediate files
├── scripts/               # entry-point scripts
├── tests/                 # pytest test suite
├── logs/
└── docs/
    └── SETUP.md
\`\`\`

## Environment Variables

Copy \`.env.example\` to \`.env\`. Never commit \`.env\`.

| Variable | Description |
|---|---|
| \`PROJECT_ROOT\` | Absolute project base path |
| \`DATA_DIR\` | Parent of input / output / temp |
| \`OUTPUT_DIR\` | Processed output directory |
| \`TEMP_DIR\` | Intermediate / scratch files |
| \`LOGS_DIR\` | Log file directory |
| \`DEBUG\` | Enable debug logging (True/False) |
| \`LOG_LEVEL\` | Logging verbosity (INFO / DEBUG / ERROR) |

## Skills (Claude Code)

| Command | Description |
|---|---|
| \`/orchestrator\` | Run all skills in sequence |
| \`/data_processor\` | Process input files |
| \`/report_generator\` | Generate reports from processed data |

## Useful Commands

\`\`\`bash
uv add <package>           # add dependency
uv run python <script>     # run script in venv
uv run pytest tests/ -v    # run tests
source .venv/bin/activate  # activate venv manually
\`\`\`
EOF
if [ -n "${GITHUB_REPO_URL}" ]; then
    echo "" >> "README.md"
    echo "## GitHub" >> "README.md"
    echo "Repository: ${GITHUB_REPO_URL}" >> "README.md"
fi

print_step "Created README.md"

################################################################################
# PHASE 10: GIT INITIALIZATION
################################################################################

print_header "PHASE 10: Git Initialization"

# Init repo if one does not exist yet
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_step "Initializing git repository"
    git init
    git branch -M main
else
    print_warning "Git repository already exists — skipping git init"
fi

# Offer to commit if there are uncommitted files (handles re-runs after a crash)
if git rev-parse --git-dir > /dev/null 2>&1; then
    UNCOMMITTED=$(git status --short 2>/dev/null)
    if [ -n "$UNCOMMITTED" ]; then
        echo ""
        echo "Files that will be committed:"
        echo "$UNCOMMITTED" | head -20
        echo ""
        read -p "Create initial commit? (y/n) " -n 1 -r </dev/tty
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git add .
            git commit -m "Initial project setup with uv, Claude Code, and shared skills configuration"
            print_step "Initial commit created"

            if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_REPO" ]; then
                echo ""
                read -p "Push to GitHub ($GITHUB_REPO_URL)? (y/n) " -n 1 -r </dev/tty
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    git remote add origin "https://github.com/$GITHUB_USERNAME/$GITHUB_REPO.git"
                    git push -u origin main \
                        && print_step "Pushed to GitHub" \
                        || print_warning "Push failed — check credentials and run: git push -u origin main"
                else
                    print_warning "Push skipped — run manually: git remote add origin $GITHUB_REPO_URL && git push -u origin main"
                fi
            fi
        else
            print_warning "Commit skipped — run manually: git add . && git commit -m 'Initial commit'"
        fi
    else
        print_warning "Nothing to commit — working tree is clean"
    fi
fi

################################################################################
# PHASE 11: SUMMARY & VERIFICATION
################################################################################

print_header "PHASE 11: Verification & Summary"

echo "Checking setup..."

files_to_check=(
    "README.md"
    "CLAUDE.md"
    ".env"
    ".env.example"
    ".gitignore"
    "pyproject.toml"
    ".claude/skills/shared/config.py"
    ".claude/skills/shared/utils.py"
    ".claude/skills/shared/state.json"
    ".claude/skills/orchestrator/SKILL.md"
    "docs/SETUP.md"
)

all_good=true
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        print_step "$file"
    else
        print_error "$file (missing)"
        all_good=false
    fi
done

dirs_to_check=(
    "data/input"
    "data/output"
    "data/temp"
    "logs"
    ".claude/skills/shared"
    "scripts"
    "tests"
    "docs"
)

for dir in "${dirs_to_check[@]}"; do
    if [ -d "$dir" ]; then
        print_step "$dir/"
    else
        print_error "$dir/ (missing)"
        all_good=false
    fi
done

################################################################################
# FINAL SUMMARY
################################################################################

print_header "Setup Complete!"

echo "Project Name : $PROJECT_NAME"
echo "Location     : $PROJECT_ROOT"
echo "Python       : $PYTHON_PATH"
echo ""

cat << 'EOF'
Next Steps:

1. Edit .env with your configuration values
2. Add dependencies:   uv add <package>
3. Create scripts in:  scripts/
4. Run tests:          uv run pytest tests/ -v
5. Use Claude skills:  /orchestrator

Important files:
  README.md   - Project overview
  CLAUDE.md   - Coding guidelines (read by Claude Code)
  .env        - Local config (DO NOT COMMIT)
EOF

echo ""
if [ "$all_good" = true ]; then
    print_step "All checks passed! Happy coding!"
else
    print_warning "Some files or directories are missing — review output above."
fi
