#!/bin/sh

# Prevent double loading
[ -n "$UTILS_LOADED" ] && return
UTILS_LOADED=1

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

print_msg() {
    color="$1"
    msg="$2"
    printf "%b\n" "${color}${msg}${NC}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}
