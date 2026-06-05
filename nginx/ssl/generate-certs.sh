#!/bin/bash

# SSL Certificate Generation for ask-devenv
# Uses step-cli (smallstep) — same approach as shop-dev-env.
# Generates a local CA + wildcard cert for ask.local and api.ask.local.

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
print_msg() { echo -e "${1}${2}${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"

LOCAL_DOMAINS=("ask.local" "api.ask.local")
CA_NAME="Weezevent Ask Local Dev CA"
CA_VALIDITY="87600h"      # 10 years
CERT_VALIDITY="19800h"    # ~2.25 years (browser max)

check_step_cli() {
    if ! command -v step &>/dev/null; then
        print_msg "$RED" "✗ step-cli not found"
        print_msg "$YELLOW" "  macOS: brew install step"
        print_msg "$YELLOW" "  Linux: https://smallstep.com/docs/step-cli/installation"
        exit 1
    fi
    print_msg "$GREEN" "✓ step-cli found"
}

certs_exist() {
    [ -f "${CERTS_DIR}/ca.crt" ] && [ -f "${CERTS_DIR}/ca.key" ] || return 1
    for d in "${LOCAL_DOMAINS[@]}"; do
        [ -f "${CERTS_DIR}/${d}.crt" ] && [ -f "${CERTS_DIR}/${d}.key" ] || return 1
    done
    return 0
}

generate_ca() {
    print_msg "$YELLOW" "Generating local CA..."
    step certificate create "${CA_NAME}" \
        "${CERTS_DIR}/ca.crt" "${CERTS_DIR}/ca.key" \
        --profile root-ca --no-password --insecure \
        --not-after="${CA_VALIDITY}" --force
    chmod 644 "${CERTS_DIR}/ca.crt"
    chmod 600 "${CERTS_DIR}/ca.key"
    print_msg "$GREEN" "✓ CA generated"
}

generate_domain_cert() {
    local domain="$1"
    print_msg "$YELLOW" "Generating cert for ${domain}..."
    step certificate create "${domain}" \
        "${CERTS_DIR}/${domain}.crt" "${CERTS_DIR}/${domain}.key" \
        --profile leaf \
        --ca "${CERTS_DIR}/ca.crt" --ca-key "${CERTS_DIR}/ca.key" \
        --no-password --insecure \
        --not-after="${CERT_VALIDITY}" \
        --san "${domain}" --san "*.${domain}" \
        --force
    chmod 644 "${CERTS_DIR}/${domain}.crt"
    chmod 600 "${CERTS_DIR}/${domain}.key"
    print_msg "$GREEN" "✓ Cert generated for ${domain}"
}

install_ca() {
    print_msg "$YELLOW" "\nInstalling CA in system trust store (requires sudo)..."
    if step certificate install "${CERTS_DIR}/ca.crt" --all 2>/dev/null; then
        print_msg "$GREEN" "✓ CA installed in system trust store"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        sudo security add-trusted-cert -d -r trustRoot \
            -k /Library/Keychains/System.keychain "${CERTS_DIR}/ca.crt"
        print_msg "$GREEN" "✓ CA installed via macOS Keychain"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -d "/usr/local/share/ca-certificates" ]; then
            sudo cp "${CERTS_DIR}/ca.crt" /usr/local/share/ca-certificates/ask-devenv-ca.crt
            sudo update-ca-certificates
            print_msg "$GREEN" "✓ CA installed via update-ca-certificates"
        else
            print_msg "$YELLOW" "⚠ Install CA manually — see ${CERTS_DIR}/ca.crt"
        fi
    fi
}

main() {
    print_msg "$GREEN" "╔══════════════════════════════════════════════╗"
    print_msg "$GREEN" "║       SSL Certificate Generation             ║"
    print_msg "$GREEN" "╚══════════════════════════════════════════════╝"
    echo ""

    check_step_cli
    mkdir -p "${CERTS_DIR}"

    if certs_exist; then
        print_msg "$YELLOW" "⊘ Certificates already exist in ${CERTS_DIR} — skipping."
        print_msg "$YELLOW" "  To regenerate: rm -rf ${CERTS_DIR} && ./nginx/ssl/generate-certs.sh"
        return 0
    fi

    generate_ca
    for domain in "${LOCAL_DOMAINS[@]}"; do
        generate_domain_cert "$domain"
    done

    echo ""
    read -p "Install CA in system trust store? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        install_ca
    else
        print_msg "$YELLOW" "Skipped. Install manually:"
        print_msg "$YELLOW" "  macOS: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${CERTS_DIR}/ca.crt"
        print_msg "$YELLOW" "  Linux: sudo cp ${CERTS_DIR}/ca.crt /usr/local/share/ca-certificates/ask-devenv-ca.crt && sudo update-ca-certificates"
    fi

    echo ""
    print_msg "$GREEN" "Certificate files: ${CERTS_DIR}/"
    print_msg "$YELLOW" "Firefox users: import ${CERTS_DIR}/ca.crt manually in about:preferences#privacy → Certificates → Authorities"
    echo ""
}

main "$@"
