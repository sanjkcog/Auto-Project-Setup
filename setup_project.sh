#!/bin/bash

################################################################################
# PROJECT SETUP AUTOMATION SCRIPT
# 
# Purpose: Complete one-command project initialization with:
# - uv (Python package manager)
# - Git (local + remote setup)
# - Environment variables (.env file)
# - VSCode configuration
# - Claude Code configuration (CLAUDE.md)
# - Shared skill configuration
#
# Usage: bash setup_project.sh
#        or source setup_project.sh (to preserve env variables)
#
# Prerequisites:
# - uv installed (https://docs.astral.sh/uv/getting-started/)
# - git installed
# - GitHub account (optional, for remote)
# - VSCode (optional)
#
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color output
# Description: Defines a bash color variable for red text output
# Usage: Used with echo -e to display text in red color in terminal
# Example: echo -e "${RED}Error message${NC}"
# Note: Typically paired with color reset variable (NC='\033[0m') to prevent color bleeding
# \033 is the octal escape sequence for the ESC character (ASCII 27)
# [0;31m is the ANSI color code sequence for red text
# Combined: \033[0;31m sets the terminal output color to red
# Usage: echo -e "${RED}Error message${NC}" where NC is the reset code
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

# ── Python ──────────────────────────────────────────────────────────────────
PYTHON_PATH=$(which python 2>/dev/null || which python3 2>/dev/null || echo "")
# Convert Unix-style path (from Git Bash) to Windows path for native Windows tools like uv and VSCode
if command -v cygpath &>/dev/null && [ -n "$PYTHON_PATH" ]; then
    PYTHON_PATH=$(cygpath -w "$PYTHON_PATH")
fi
if [ -z "$PYTHON_PATH" ]; then
    print_error "Python not found in PATH"
    echo "Python is required to run this project."
    read -p "Would you like to install Python now? (y/n) " -n 1 -r </dev/tty
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v winget &>/dev/null; then
            echo "Installing Python via winget..."
            winget install Python.Python.3.11
            PYTHON_PATH=$(which python 2>/dev/null || which python3 2>/dev/null || echo "")
            if command -v cygpath &>/dev/null && [ -n "$PYTHON_PATH" ]; then PYTHON_PATH=$(cygpath -w "$PYTHON_PATH"); fi
        elif command -v brew &>/dev/null; then
            echo "Installing Python via Homebrew..."
            brew install python
            PYTHON_PATH=$(which python3 2>/dev/null || echo "")
        else
            echo "No package manager found. Please install Python manually from:"
            echo "  https://www.python.org/downloads/"
            echo "  or https://www.anaconda.com/download"
            exit 1
        fi
        if [ -z "$PYTHON_PATH" ]; then
            print_error "Python installation failed or not found in PATH. Please restart your terminal and try again."
            exit 1
        fi
    else
        print_warning "Python is required. Install from https://www.python.org/downloads/ and re-run this script."
        exit 1
    fi
fi
print_step "Python found at: $PYTHON_PATH"

# ── Git ──────────────────────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
    print_error "git not found in PATH"
    echo "Git is required for version control."
    read -p "Would you like to install Git now? (y/n) " -n 1 -r </dev/tty
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v winget &>/dev/null; then
            echo "Installing Git via winget..."
            winget install Git.Git
        elif command -v brew &>/dev/null; then
            echo "Installing Git via Homebrew..."
            brew install git
        else
            echo "No package manager found. Please install Git manually from:"
            echo "  https://git-scm.com/downloads"
            exit 1
        fi
        if ! command -v git &>/dev/null; then
            print_error "Git installation failed or not found in PATH. Please restart your terminal and try again."
            exit 1
        fi
    else
        print_warning "Git is required. Install from https://git-scm.com/downloads and re-run this script."
        exit 1
    fi
fi
print_step "git found at: $(which git)"

# ── uv ───────────────────────────────────────────────────────────────────────
# Search PATH first, then common Python install locations
UV_PATH=$(which uv 2>/dev/null || echo "")

if [ -z "$UV_PATH" ]; then
    # Look in common Python/pip script directories
    for candidate in \
        "$HOME/.local/bin/uv" \
        "$HOME/.cargo/bin/uv" \
        "$(dirname "$PYTHON_PATH")/uv" \
        "$(dirname "$PYTHON_PATH")/Scripts/uv" \
        "$(dirname "$PYTHON_PATH")/Scripts/uv.exe" \
        "$HOME/anaconda3/Scripts/uv" \
        "$HOME/anaconda3/Scripts/uv.exe" \
        "$HOME/miniconda3/Scripts/uv" \
        "$HOME/miniconda3/Scripts/uv.exe"; do
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
        echo "Installing uv via pip..."
        "$PYTHON_PATH" -m pip install uv --quiet
        UV_PATH=$(which uv 2>/dev/null || echo "")
        if [ -z "$UV_PATH" ]; then
            for candidate in \
                "$(dirname "$PYTHON_PATH")/uv" \
                "$(dirname "$PYTHON_PATH")/Scripts/uv" \
                "$(dirname "$PYTHON_PATH")/Scripts/uv.exe"; do
                if [ -f "$candidate" ] && "$candidate" --version &>/dev/null 2>&1; then
                    UV_PATH="$candidate"
                    break
                fi
            done
        fi
        if [ -z "$UV_PATH" ] || ! "$UV_PATH" --version &>/dev/null 2>&1; then
            print_error "uv installation failed. Please restart your terminal and try again."
            exit 1
        fi
    else
        print_warning "uv is required. Install with: pip install uv  or see https://docs.astral.sh/uv/getting-started/"
        exit 1
    fi
fi

UV_VERSION=$("$UV_PATH" --version 2>&1)
print_step "uv found at: $UV_PATH ($UV_VERSION)"

# Make sure uv is callable by name for the rest of the script
export PATH="$(dirname "$UV_PATH"):$PATH"

################################################################################
# COLLECT PROJECT CONFIGURATION FROM USER
################################################################################

print_header "Project Configuration"

# Project name — any name is allowed; spaces are fine for the directory
while [ -z "$PROJECT_NAME" ]; do
    read -p "Project name (e.g. My Cool Project): " PROJECT_NAME </dev/tty
    if [ -z "$PROJECT_NAME" ]; then
        print_warning "Project name cannot be empty."
    fi
done
# Derive a valid Python package name (no spaces, lowercase, hyphens) for uv/pyproject.toml
PACKAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-_')

# Project directory — default is the folder where this script lives
echo "Default project base: $SCRIPT_DIR"
read -p "Project base directory [press Enter to use default]: " PROJECT_DIR </dev/tty
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"   # use default if blank
PROJECT_DIR="${PROJECT_DIR%/}/$PROJECT_NAME"  # always append project name
print_step "Project will be created at: $PROJECT_DIR"

# GitHub repo URL (optional)
read -p "GitHub repo URL (leave blank to skip, e.g. https://github.com/user/repo.git): " GITHUB_REPO_URL </dev/tty
if [ -n "$GITHUB_REPO_URL" ]; then
    # Extract username and repo from URL for later use
    GITHUB_USERNAME=$(echo "$GITHUB_REPO_URL" | sed -E 's|https://github.com/([^/]+)/.*|\1|')
    GITHUB_REPO=$(echo "$GITHUB_REPO_URL" | sed -E 's|https://github.com/[^/]+/([^/]+)(\.git)?$|\1|')
    print_step "GitHub: $GITHUB_USERNAME / $GITHUB_REPO"
else
    print_warning "GitHub setup skipped — you can add a remote later with: git remote add origin <url>"
fi

echo ""
echo "Summary:"
echo "  Project Name : $PROJECT_NAME"
echo "  Package Name : $PACKAGE_NAME  (used in pyproject.toml)"
echo "  Directory    : $PROJECT_DIR"
echo "  Python       : $PYTHON_PATH"
if [ -n "$GITHUB_REPO_URL" ]; then
    echo "  GitHub URL   : $GITHUB_REPO_URL"
fi
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

# Create project directory if needed
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

# Create .env file — use actual resolved path so python-dotenv can read it
cat > ".env" << EOF
# ========================================
# PROJECT ENVIRONMENT VARIABLES
# ========================================
# DO NOT COMMIT THIS FILE TO GIT
# Add .env to .gitignore

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

# Create .env.example
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

# Create .gitignore
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

# Create CLAUDE.md
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

# Create config.py
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
    
    # Read and expand environment variables
    PROJECT_ROOT = Path(os.path.expandvars(
        os.getenv('PROJECT_ROOT', os.path.expanduser('~/my_project'))
    ))
    
    PROJECT_NAME = os.getenv('PROJECT_NAME', 'my_project')
    
    # Build directory paths
    DATA_DIR = PROJECT_ROOT / os.path.expandvars(
        os.getenv('DATA_DIR', '${PROJECT_ROOT}/data')
    )
    
    INPUT_DIR = DATA_DIR / 'input'
    OUTPUT_DIR = DATA_DIR / 'output'
    TEMP_DIR = DATA_DIR / 'temp'
    LOGS_DIR = PROJECT_ROOT / os.path.expandvars(
        os.getenv('LOGS_DIR', '${PROJECT_ROOT}/logs')
    )
    
    # State file
    STATE_FILE = PROJECT_ROOT / '.claude/skills/shared/state.json'
    
    # Settings
    DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    PYTHON_VERSION = os.getenv('PYTHON_VERSION', '3.11')
    
    @classmethod
    def ensure_dirs(cls):
        """Create all required directories"""
        for directory in [cls.DATA_DIR, cls.INPUT_DIR, cls.OUTPUT_DIR, 
                         cls.TEMP_DIR, cls.LOGS_DIR]:
            directory.mkdir(parents=True, exist_ok=True)
    
    @classmethod
    def print_config(cls):
        """Debug: print current configuration"""
        print("=== Configuration ===")
        print(f"PROJECT_ROOT: {cls.PROJECT_ROOT}")
        print(f"PROJECT_NAME: {cls.PROJECT_NAME}")
        print(f"DATA_DIR: {cls.DATA_DIR}")
        print(f"INPUT_DIR: {cls.INPUT_DIR}")
        print(f"OUTPUT_DIR: {cls.OUTPUT_DIR}")
        print(f"TEMP_DIR: {cls.TEMP_DIR}")
        print(f"LOGS_DIR: {cls.LOGS_DIR}")
        print(f"STATE_FILE: {cls.STATE_FILE}")
        print(f"DEBUG: {cls.DEBUG}")
        print(f"LOG_LEVEL: {cls.LOG_LEVEL}")

# Create directories when module is imported
Config.ensure_dirs()
EOF

print_step "Created config.py"

# Create utils.py
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
        """Initialize state file if it doesn't exist"""
        if not self.state_file.exists():
            initial_state = {
                "status": "initialized",
                "current_skill": None,
                "timestamp": datetime.now().isoformat(),
                "data": {},
                "history": []
            }
            self.save(initial_state)
    
    def load(self) -> Dict[str, Any]:
        """Load current state from file"""
        if not self.state_file.exists():
            self._init_state()
        with open(self.state_file, 'r') as f:
            return json.load(f)
    
    def save(self, state: Dict[str, Any]):
        """Save state to file"""
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)
    
    def set_skill_active(self, skill_name: str):
        """Mark skill as currently active"""
        state = self.load()
        state['current_skill'] = skill_name
        state['status'] = 'running'
        state['timestamp'] = datetime.now().isoformat()
        self.save(state)
    
    def set_skill_complete(self, skill_name: str, success: bool, message: str = ""):
        """Mark skill as complete and add to history"""
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
        """Set value in data section"""
        state = self.load()
        state['data'][key] = value
        self.save(state)
    
    def get_data(self, key: str) -> Any:
        """Get value from data section"""
        state = self.load()
        return state.get('data', {}).get(key)
    
    def print_state(self):
        """Print current state for debugging"""
        state = self.load()
        print(json.dumps(state, indent=2))
EOF

print_step "Created utils.py"

# Create initial state.json
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

# Create orchestrator skill
cat > ".claude/skills/orchestrator/SKILL.md" << 'EOF'
---
name: orchestrator
description: Master skill - runs all other skills in sequence with shared state
context: editor
---

# Orchestrator Skill

Master workflow that orchestrates all project skills.

## Usage

```
/orchestrator
```

## How It Works

1. Loads shared configuration from `.claude/skills/shared/config.py`
2. Initializes shared state in `.claude/skills/shared/state.json`
3. Runs skills in sequence:
   - data_processor
   - report_generator
4. Checks state between skills
5. Reports final status

## Implementation

```python
import sys
sys.path.insert(0, '../shared')

from config import Config
from utils import StateManager

Config.print_config()

state = StateManager()
state.set_skill_active("orchestrator")

print("\n=== Starting Orchestrator ===")

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

## Skills Directory

- `.claude/skills/shared/config.py` - Shared configuration
- `.claude/skills/shared/utils.py` - Shared utilities
- `.claude/skills/shared/state.json` - Shared state
- `.claude/skills/data_processor/SKILL.md` - Data processing
- `.claude/skills/report_generator/SKILL.md` - Report generation
EOF

print_step "Created orchestrator/SKILL.md"

# Create data_processor skill
cat > ".claude/skills/data_processor/SKILL.md" << 'EOF'
---
name: data_processor
description: Process input data files
context: editor
---

# Data Processor Skill

Process files from input directory and save to output.

## Usage

```
/data_processor
```

## How It Works

```python
import sys
sys.path.insert(0, '../shared')

from config import Config
from utils import StateManager

# Load shared configuration
state = StateManager()
state.set_skill_active("data_processor")

# Use CONFIG paths (already expanded!)
input_dir = Config.INPUT_DIR
output_dir = Config.OUTPUT_DIR

print(f"Input directory: {input_dir}")
print(f"Output directory: {output_dir}")

# Process files
input_files = list(input_dir.glob("*.csv"))
print(f"Found {len(input_files)} files to process")

# TODO: Add your processing logic

# Update state
state.set_data("files_processed", len(input_files))
state.set_skill_complete("data_processor", success=True)
```

## Configuration

Uses shared Config from `.claude/skills/shared/config.py`:
- `Config.INPUT_DIR` - Input files
- `Config.OUTPUT_DIR` - Output files
- `Config.TEMP_DIR` - Temporary files
EOF

print_step "Created data_processor/SKILL.md"

# Create report_generator skill
cat > ".claude/skills/report_generator/SKILL.md" << 'EOF'
---
name: report_generator
description: Generate reports from processed data
context: editor
---

# Report Generator Skill

Generate reports from processed data.

## Usage

```
/report_generator
```

## How It Works

```python
import sys
sys.path.insert(0, '../shared')

from config import Config
from utils import StateManager

# Load shared configuration and state
state = StateManager()
state.set_skill_active("report_generator")

# Read from previous skill's output
files_processed = state.get_data("files_processed")
print(f"Files processed previously: {files_processed}")

# Use output directory
output_dir = Config.OUTPUT_DIR
print(f"Output directory: {output_dir}")

# TODO: Add your report generation logic

# Update state
state.set_skill_complete("report_generator", success=True)
```

## Configuration

Uses shared Config and State Management.
EOF

print_step "Created report_generator/SKILL.md"

################################################################################
# PHASE 9: DOCUMENTATION
################################################################################

print_header "PHASE 9: Creating Documentation"

# Create SETUP.md
cat > "docs/SETUP.md" << 'EOF'
# Project Setup Guide

This document describes the complete project setup process.

## Quick Start

```bash
bash setup_project.sh
```

This runs all steps automatically.

## Manual Setup (Step by Step)

### 1. UV Initialization
```bash
uv init --python 3.11
uv sync
```

### 2. Create Environment File
```bash
cp .env.example .env
# Edit .env with your configuration
```

### 3. Add to .gitignore
```bash
echo ".env" >> .gitignore
```

### 4. Initialize Git
```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
```

### 5. Connect to GitHub (Optional)
```bash
git remote add origin https://github.com/username/repo.git
git push -u origin main
```

### 6. VSCode Setup
```bash
mkdir -p .vscode
# Create settings.json
```

### 7. Claude Code Setup
```bash
# CLAUDE.md created
# .claude/skills/ directory created
# Shared modules created
```

## Project Structure

```
project/
├── .env                 # Configuration (DO NOT COMMIT)
├── .env.example         # Configuration template
├── .gitignore
├── pyproject.toml       # uv project file
├── uv.lock              # Dependency lock file
├── .claude/
│   ├── CLAUDE.md        # Claude Code config
│   └── skills/
│       ├── shared/
│       │   ├── config.py
│       │   ├── utils.py
│       │   └── state.json
│       ├── orchestrator/
│       ├── data_processor/
│       └── report_generator/
├── data/
│   ├── input/
│   ├── output/
│   └── temp/
├── logs/
├── scripts/
├── tests/
└── docs/
```

## Next Steps

1. Edit `.env` with your configuration
2. Add your dependencies: `uv add package_name`
3. Create your scripts in scripts/ directory
4. Add tests in tests/ directory
5. Connect to GitHub if needed

## Useful Commands

```bash
# Activate virtual environment
source .venv/bin/activate

# Run Python script
uv run python script.py

# Install package
uv add package_name

# Run tests
uv run pytest tests/

# Sync dependencies
uv sync

# Run Claude skills
/orchestrator
/data_processor
/report_generator
```

For more information, see:
- README.md - Project overview and structure
- CLAUDE.md - Coding guidelines for Claude Code
- .claude/skills/*/SKILL.md - Individual skill documentation
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
    └── SETUP.md           # detailed setup guide
\`\`\`

## Environment Variables

Copy \`.env.example\` to \`.env\` and fill in values. Never commit \`.env\`.

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

Run from the project root in Claude Code:

| Command | Description |
|---|---|
| \`/orchestrator\` | Run all skills in sequence |
| \`/data_processor\` | Process input files |
| \`/report_generator\` | Generate reports from processed data |

Skills share state via \`.claude/skills/shared/state.json\`.

## Useful Commands

\`\`\`bash
uv add <package>           # add dependency
uv run python <script>     # run script in venv
uv run pytest tests/ -v    # run tests
source .venv/bin/activate  # activate venv manually (Unix)
.venv\\Scripts\\activate   # activate venv manually (Windows)
\`\`\`

## GitHub
EOF
if [ -n "${GITHUB_REPO_URL}" ]; then
    echo "" >> "README.md"
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

            # Offer GitHub push if remote configured
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

# Verify key files
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
        print_step "✓ $file"
    else
        print_error "✗ $file (missing)"
        all_good=false
    fi
done

# Verify directories
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
        print_step "✓ $dir/"
    else
        print_error "✗ $dir/ (missing)"
        all_good=false
    fi
done

################################################################################
# FINAL SUMMARY
################################################################################

print_header "Setup Complete! 🎉"

echo "Project Name: $PROJECT_NAME"
echo "Location:     $PROJECT_ROOT"
echo "Python:       $PYTHON_PATH"
echo ""

cat << 'EOF'
✓ uv project initialized
✓ Virtual environment created
✓ .env configuration file created
✓ Git repository initialized
✓ Claude Code configured
✓ Skills structure created
✓ Shared modules created
✓ Documentation created

## Next Steps:

1. **Edit Configuration**
   Edit .env with your actual configuration values
   
2. **Install Dependencies**
   uv add package_name
   
3. **Create Scripts**
   Add Python scripts to scripts/ directory
   
4. **Connect to GitHub (optional)**
   git remote add origin <your-repo-url>
   git push -u origin main
   
5. **Use Claude Code**
   /orchestrator          # Run all skills
   /data_processor        # Run specific skill
   /report_generator      # Run specific skill

## Important Files:

- README.md         - Project overview
- CLAUDE.md         - Coding guidelines (Claude Code reads this)
- .env              - Configuration (DO NOT COMMIT)
- .env.example      - Configuration template
- docs/SETUP.md     - Detailed setup guide

## Useful Commands:

source .venv/bin/activate  # Activate venv
uv run python script.py    # Run Python script
uv add package_name        # Install package
uv sync                    # Sync dependencies
uv run pytest tests/       # Run tests

EOF

if [ "$all_good" = true ]; then
    print_step "All checks passed!"
else
    print_warning "Some files/directories are missing"
fi

echo ""
print_step "Setup finished! Happy coding! 🚀"
