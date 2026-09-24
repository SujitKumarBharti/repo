#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Repository - Local Disk Cleaner & Sparse Checkout Manager
# Maintainer: SujitKumarBharti
# Repository: https://github.com/SujitKumarBharti/repo
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║        REPOSITORY LOCAL STORAGE & DISK CLEANER                ║"
    echo "  ║        https://sujitkumarbharti.github.io/repo                ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_help() {
    print_banner
    echo -e "${BOLD}USAGE:${NC}"
    echo "  ./clean_local.sh [OPTIONS]"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo -e "  ${GREEN}(no arguments)${NC}        Clean local package binaries from disk (keep scripts & database)"
    echo -e "  ${GREEN}-s, --status${NC}          Show local disk usage vs online registered packages"
    echo -e "  ${GREEN}-r, --restore${NC}         Download/restore local copies of packages from git"
    echo -e "  ${GREEN}-h, --help${NC}            Show this help message"
    echo ""
    echo -e "${BOLD}HOW IT WORKS:${NC}"
    echo "  • Uses Git Sparse-Checkout to keep binary packages (.deb, .rpm, etc.) on GitHub"
    echo "  • Removes physical package binaries from your local PC to free disk space"
    echo "  • Future commits will NEVER accidentally delete packages from GitHub"
    echo "  • To permanently delete a package from GitHub, use: ./delete.sh <package_name>"
    echo ""
}

show_status() {
    print_banner
    echo -e "${BLUE}${BOLD}📊 Repository Storage Status:${NC}\n"
    
    local reg_file="$SCRIPT_DIR/database/registry.json"
    if [ -f "$reg_file" ]; then
        python3 -c '
import json, sys, os

with open(sys.argv[1]) as f:
    data = json.load(f)

pkgs = data.get("packages", [])
print("  Total packages in registry: {}".format(len(pkgs)))
total_bytes = sum(p.get("size", 0) for p in pkgs)
mb = total_bytes / (1024 * 1024)
print("  Total repository package size: {:.2f} MB".format(mb))
print("\n  Package List:")
for p in pkgs:
    local_exists = os.path.exists(p.get("filepath", ""))
    status = "PRESENT ON DISK" if local_exists else "SAVED ON GITHUB (0 MB locally)"
    print("  • {:<20} (v{:<8}) [{:<7}] -> {}".format(p["name"], p.get("version", "-"), p.get("os_type", "-"), status))
' "$reg_file"
    else
        echo "  Registry file not found."
    fi

    echo ""
    local local_size
    local_size=$(du -sh database 2>/dev/null | awk '{print $1}' || echo "0")
    echo -e "  Current local 'database/' folder size on your disk: ${YELLOW}${BOLD}$local_size${NC}"
    echo ""
}

clean_local() {
    print_banner
    echo -e "${BLUE}🧹 Cleaning local package binaries to free disk space...${NC}"

    # Ensure git repo
    if [ ! -d ".git" ]; then
        echo -e "${RED}❌ Error: Not a git repository.${NC}"
        exit 1
    fi

    # Check uncommitted local binary files
    local uncommitted_binaries
    uncommitted_binaries=$(git status --porcelain database/ | grep -E '\.(deb|rpm|pkg\.tar\.zst|run|AppImage)$' || true)
    if [ -n "$uncommitted_binaries" ]; then
        echo -e "${YELLOW}⚠️  Warning: You have uncommitted binary files in database/:${NC}"
        echo "$uncommitted_binaries"
        echo -e "${YELLOW}Please commit and push your uploaded packages first before cleaning!${NC}"
        read -p "Do you want to push now? [y/N]: " push_choice
        if [[ "$push_choice" =~ ^[Yy]$ ]]; then
            git add database/
            git commit -m "chore: save packages to repository" || true
            git push || true
        else
            echo -e "${RED}Aborting local cleanup to prevent losing unpushed packages.${NC}"
            exit 1
        fi
    fi

    # Configure sparse-checkout to exclude all binary packages
    echo -e "${BLUE}⚙️  Configuring Git Sparse-Checkout...${NC}"
    git sparse-checkout set --no-cone '/*' '!database/*/*.deb' '!database/*/*.rpm' '!database/*/*.pkg.tar.zst' '!database/*/*.run' '!database/*/*.AppImage'

    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}🎉 LOCAL DISK CLEANUP COMPLETE!${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Summary:${NC}"
    echo -e "  ✔ All packages remain safe and hosted on GitHub."
    echo -e "  ✔ Local package binaries removed from your PC to save disk space."
    echo -e "  ✔ Future git commits will ${GREEN}NEVER${NC} delete packages from GitHub."
    echo -e "  ✔ To permanently delete a package from GitHub, use: ${CYAN}./delete.sh <name>${NC}"
    echo ""
}

restore_all() {
    print_banner
    echo -e "${BLUE}📦 Restoring all package binaries to local disk...${NC}"
    git sparse-checkout disable
    echo -e "${GREEN}✔ All package files checked out to local disk.${NC}"
}

# Command dispatch
case "$1" in
    -h|--help)
        show_help
        ;;
    -s|--status)
        show_status
        ;;
    -r|--restore)
        restore_all
        ;;
    *)
        clean_local
        ;;
esac
