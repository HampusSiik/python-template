#!/bin/bash
set -euo pipefail

WORKSPACE_ROOT="$(pwd)"
DEFAULT_NAME="$(basename "$WORKSPACE_ROOT")"
REQUESTED_NAME="${1:-${PROJECT_NAME:-$DEFAULT_NAME}}"
PROJECT_NAME="${REQUESTED_NAME:-$DEFAULT_NAME}"

echo "Initializing Python project: $PROJECT_NAME"

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
    # uv init creates its own Git metadata; skip it so we do not clobber the host repo
    for entry in "$TEMP_DIR"/*; do
        name="$(basename "$entry")"
        if [ "$name" = ".git" ]; then
            continue
        fi
        mv "$entry" "$WORKSPACE_ROOT/"
    done
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
"$(dirname "$0")/install-tools.sh" --quiet
ensure_uv_project
ensure_basic_structure
if ! uv add --dev pytest >/dev/null 2>&1; then
    echo "Warning: Failed to add pytest via uv"
fi
ensure_gitignore

echo "Python project '$PROJECT_NAME' initialized successfully!"
echo "Run 'uv run pytest' to run tests"
