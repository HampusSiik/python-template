#!/bin/bash
set -euo pipefail

WORKSPACE_ROOT="$(pwd)"
DEFAULT_NAME="$(basename "$WORKSPACE_ROOT")"
REQUESTED_NAME="${1:-${PROJECT_NAME:-$DEFAULT_NAME}}"
PROJECT_NAME="${REQUESTED_NAME:-$DEFAULT_NAME}"

echo "Initializing Python project: $PROJECT_NAME"

ensure_uv_available() {
    if command -v uv >/dev/null 2>&1; then
        return
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required to install uv" >&2
        exit 1
    fi

    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null
    export PATH="$HOME/.local/bin:$PATH"
    hash -r
}

ensure_uv_project() {
    if [ -f pyproject.toml ]; then
        echo "pyproject.toml already exists, skipping uv init"
        return
    fi

    echo "Bootstrapping uv project files..."
    TEMP_DIR="$(mktemp -d)"
    uv init "$TEMP_DIR" --no-workspace >/dev/null

    python3 - "$TEMP_DIR/pyproject.toml" "$PROJECT_NAME" <<'PY'
import pathlib
import sys

pyproject = pathlib.Path(sys.argv[1])
project_name = sys.argv[2]
text = pyproject.read_text()
replacement = f'name = "{project_name}"'

lines = []
replaced = False
for line in text.splitlines():
    stripped = line.strip()
    if not replaced and stripped.startswith('name = '):
        lines.append(replacement)
        replaced = True
    else:
        lines.append(line)

if not replaced:
    if '[project]' in text:
        text = text.replace('[project]', f'[project]\n{replacement}', 1)
    else:
        text = text + f'\n[project]\n{replacement}\n'
else:
    text = '\n'.join(lines)

pyproject.write_text(text)
PY

    shopt -s dotglob
    mv "$TEMP_DIR"/* "$WORKSPACE_ROOT"
    shopt -u dotglob
    rm -rf "$TEMP_DIR"
}

ensure_basic_structure() {
    mkdir -p src tests

    if [ ! -f tests/test_example.py ]; then
        cat > tests/test_example.py <<'EOF'
def test_example():
    assert True
EOF
    fi
}

ensure_gitignore() {
    if [ -f .gitignore ]; then
        return
    fi

    cat > .gitignore <<'EOF'
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
*.egg-info/
.installed.cfg
*.egg

# Virtual environments
.venv/
venv/
ENV/
env/

# uv
.uv/

# IDEs
.vscode/
.idea/
*.swp
*.swo
*~

# Testing
.pytest_cache/
.coverage
htmlcov/

EOF
}

ensure_uv_available
ensure_uv_project
ensure_basic_structure
if ! uv add --dev pytest >/dev/null 2>&1; then
    echo "Warning: Failed to add pytest via uv"
fi
ensure_gitignore

echo "Python project '$PROJECT_NAME' initialized successfully!"
echo "Run 'uv run pytest' to run tests"
