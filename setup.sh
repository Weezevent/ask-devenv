#!/usr/bin/env bash
# ask-devenv setup — run once after cloning.
# Installs mkcert, generates local TLS certs, adds /etc/hosts entries,
# and creates a .env from .env.example.
set -euo pipefail

DOMAIN_API="api.ask.local"
DOMAIN_UI="ask.local"
CERT_DIR="./certs"

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[ask-devenv]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ask-devenv]${NC} $*"; }
error() { echo -e "${RED}[ask-devenv]${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Check prerequisites
# ---------------------------------------------------------------------------
command -v docker  >/dev/null 2>&1 || error "Docker not found. Install Docker Desktop."
command -v mkcert  >/dev/null 2>&1 || {
    warn "mkcert not found. Installing via Homebrew…"
    command -v brew >/dev/null 2>&1 || error "Homebrew not found. Install mkcert manually: https://github.com/FiloSottile/mkcert"
    brew install mkcert
}

# ---------------------------------------------------------------------------
# 2. Install mkcert root CA (once per machine)
# ---------------------------------------------------------------------------
info "Installing mkcert local CA (may ask for sudo password)…"
mkcert -install

# ---------------------------------------------------------------------------
# 3. Generate TLS cert covering both domains
# ---------------------------------------------------------------------------
mkdir -p "$CERT_DIR"
info "Generating TLS certificate for ${DOMAIN_API} and ${DOMAIN_UI}…"
mkcert \
    -cert-file "${CERT_DIR}/ask.local.pem" \
    -key-file  "${CERT_DIR}/ask.local-key.pem" \
    "$DOMAIN_UI" "$DOMAIN_API"

info "Certificates written to ${CERT_DIR}/"

# ---------------------------------------------------------------------------
# 4. Add /etc/hosts entries
# ---------------------------------------------------------------------------
add_host() {
    local host="$1"
    if grep -qF "127.0.0.1 ${host}" /etc/hosts 2>/dev/null; then
        info "/etc/hosts already has ${host} — skipping."
    else
        info "Adding 127.0.0.1 ${host} to /etc/hosts (requires sudo)…"
        echo "127.0.0.1 ${host}" | sudo tee -a /etc/hosts >/dev/null
    fi
}

add_host "$DOMAIN_UI"
add_host "$DOMAIN_API"

# ---------------------------------------------------------------------------
# 5. Create .env if missing
# ---------------------------------------------------------------------------
if [ -f .env ]; then
    warn ".env already exists — not overwriting."
else
    cp .env.example .env
    info ".env created from .env.example. Fill in the required values before running docker compose up."
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
info "Setup complete. Next steps:"
echo "  1. Edit .env and fill in ACCOUNTS_CLIENT_SECRET, GIGZ_* credentials, etc."
echo "  2. docker compose up -d"
echo "  3. Open https://ask.local"
echo "     API docs: https://api.ask.local/docs"
echo "     Qdrant dashboard: http://localhost:6333/dashboard"
