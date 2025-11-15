#!/bin/bash
set -euo pipefail

QUIET=0
if [ "${1:-}" = "--quiet" ]; then
    QUIET=1
fi

log() {
    if [ "$QUIET" -eq 0 ]; then
        echo "$@"
    fi
}

ensure_uv_available() {
    if command -v uv >/dev/null 2>&1; then
        log "uv already installed at $(command -v uv)"
        return
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required to install uv" >&2
        exit 1
    fi

    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null
    export PATH="$HOME/.local/bin:$PATH"
    hash -r
    log "uv installed at $(command -v uv)"
}

ensure_uv_available
