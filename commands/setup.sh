#!/bin/bash

# ask-devenv setup — run once after cloning.
# Clones ask-backend and ask-frontend into projects/, generates SSL certs,
# patches /etc/hosts, and scaffolds .env.

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${ROOT_DIR}/.env"

. "$SCRIPT_DIR/lib/utils.sh"

# ---------------------------------------------------------------------------
# Repos to clone
# ---------------------------------------------------------------------------
REPOS=(
    "backend/ask-backend:git@github.com:Weezevent/ask-backend.git"
    "frontend/ask-frontend:git@github.com:Weezevent/ask-frontend.git"
    "frontend/ask-frontend-widget:git@github.com:Weezevent/ask-frontend-widget.git"
)

# Local domains
LOCAL_DOMAINS=(
    "127.0.0.1 ask.local"
    "127.0.0.1 api.ask.local"
)

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------
validate_prerequisites() {
    local missing=0

    print_msg "$YELLOW" "Checking prerequisites..."

    if ! command_exists git; then
        print_msg "$RED" "✗ git is not installed"
        missing=1
    else
        print_msg "$GREEN" "✓ git"
    fi

    if ! command_exists docker; then
        print_msg "$RED" "✗ Docker is not installed — install Docker Desktop"
        missing=1
    elif ! docker info >/dev/null 2>&1; then
        print_msg "$RED" "✗ Docker daemon is not running — start Docker Desktop"
        missing=1
    else
        print_msg "$GREEN" "✓ Docker"
    fi

    if docker compose version >/dev/null 2>&1; then
        print_msg "$GREEN" "✓ Docker Compose v2"
    else
        print_msg "$RED" "✗ Docker Compose v2 not found"
        missing=1
    fi

    if ! command_exists step; then
        print_msg "$RED" "✗ step-cli is not installed (required for SSL)"
        print_msg "$RED" "  macOS: brew install step"
        print_msg "$RED" "  Linux: https://smallstep.com/docs/step-cli/installation"
        missing=1
    else
        print_msg "$GREEN" "✓ step-cli"
    fi

    if [ ! -f "$ENV_FILE" ]; then
        print_msg "$RED" "✗ .env file missing — run: cp .env.example .env"
        exit 1
    else
        print_msg "$GREEN" "✓ .env present"
    fi

    if [ $missing -eq 1 ]; then
        print_msg "$RED" "\nPlease fix the above and re-run setup.sh."
        exit 1
    fi

    print_msg "$GREEN" "\nAll prerequisites met.\n"
}

# ---------------------------------------------------------------------------
# Clone repos into projects/
# ---------------------------------------------------------------------------
clone_repositories() {
    local failed=() success=0 skipped=0

    print_msg "$YELLOW" "Cloning repositories into ${ROOT_DIR}/projects/...\n"

    for entry in "${REPOS[@]}"; do
        local subpath="${entry%%:*}"
        local url="${entry#*:}"
        local dest="${ROOT_DIR}/projects/${subpath}"

        if [ -d "$dest/.git" ]; then
            print_msg "$YELLOW" "⊘ ${subpath}: already exists, skipping"
            ((skipped+=1))
        elif git clone "$url" "$dest" 2>&1; then
            print_msg "$GREEN" "✓ ${subpath}: cloned"
            ((success+=1))
        else
            print_msg "$RED" "✗ ${subpath}: failed to clone"
            failed+=("$subpath")
        fi
    done

    echo ""
    print_msg "$GREEN" "Cloned: ${success}  Skipped: ${skipped}  Failed: ${#failed[@]}"

    if [ ${#failed[@]} -gt 0 ]; then
        print_msg "$RED" "Failed repos: ${failed[*]}"
        print_msg "$RED" "Check your SSH keys / GitHub access and retry."
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# /etc/hosts
# ---------------------------------------------------------------------------
setup_local_domains() {
    local to_add=()

    print_msg "$YELLOW" "Checking /etc/hosts entries...\n"

    for entry in "${LOCAL_DOMAINS[@]}"; do
        local host="${entry##* }"
        if grep -qE "(^|[[:space:]])${host}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
            print_msg "$YELLOW" "⊘ ${host}: already in /etc/hosts"
        else
            to_add+=("$entry")
            print_msg "$YELLOW" "○ ${host}: needs to be added"
        fi
    done

    if [ ${#to_add[@]} -eq 0 ]; then
        print_msg "$GREEN" "\nAll local domains already configured.\n"
        return 0
    fi

    echo ""
    print_msg "$YELLOW" "The following entries will be added to /etc/hosts (requires sudo):"
    for e in "${to_add[@]}"; do echo "  $e"; done
    echo ""

    read -p "Add them? [y/N] " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "" | sudo tee -a /etc/hosts >/dev/null
        echo "# ask-devenv" | sudo tee -a /etc/hosts >/dev/null
        for e in "${to_add[@]}"; do
            echo "$e" | sudo tee -a /etc/hosts >/dev/null
            print_msg "$GREEN" "✓ Added: $e"
        done
    else
        print_msg "$YELLOW" "Skipped. Add them manually before running docker compose up."
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# SSL certificates (via step-cli, same approach as shop-dev-env)
# ---------------------------------------------------------------------------
setup_ssl_certificates() {
    local ssl_script="${ROOT_DIR}/nginx/ssl/generate-certs.sh"

    print_msg "$YELLOW" "Checking SSL certificates...\n"

    if bash "$ssl_script"; then
        print_msg "$GREEN" "✓ SSL certificates ready.\n"
    else
        print_msg "$RED" "✗ SSL certificate generation failed."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    print_msg "$GREEN" "╔══════════════════════════════════════════════╗"
    print_msg "$GREEN" "║       ask-devenv setup                       ║"
    print_msg "$GREEN" "╚══════════════════════════════════════════════╝"
    echo ""

    validate_prerequisites
    clone_repositories
    setup_local_domains
    setup_ssl_certificates

    print_msg "$GREEN" "╔══════════════════════════════════════════════╗"
    print_msg "$GREEN" "║       Setup complete!                        ║"
    print_msg "$GREEN" "╚══════════════════════════════════════════════╝"
    echo ""
    print_msg "$GREEN" "Next steps:"
    print_msg "$GREEN" "  1. Fill in .env (ACCOUNTS_CLIENT_SECRET, GIGZ_* creds)"
    print_msg "$GREEN" "  2. docker compose up -d"
    print_msg "$GREEN" "  3. Open https://ask.local"
    print_msg "$GREEN" "     API docs: https://api.ask.local/docs"
    print_msg "$GREEN" "     Qdrant:   http://localhost:6333/dashboard"
    echo ""
}

main "$@"
