#!/usr/bin/env bash
# ==============================================================================
# SujitKumarBharti Universal Linux Repository Setup
# One-line Setup: curl -fsSL https://sujitkumarbharti.github.io/repo/install.sh | sudo bash
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

REPO_BASE="https://sujitkumarbharti.github.io/repo"

echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════════╗"
echo "  ║        SUJIT KUMAR BHARTI - LINUX REPOSITORY SETUP            ║"
echo "  ║        https://sujitkumarbharti.github.io/repo                ║"
echo "  ╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Error: This script must be run as root or with sudo.${NC}"
    echo -e "Please run:"
    echo -e "${CYAN}   curl -fsSL ${REPO_BASE}/install.sh | sudo bash${NC}"
    exit 1
fi

# Clean up any legacy helper if present
rm -f /usr/local/bin/urepo /usr/bin/urepo /usr/local/bin/repo /usr/bin/repo 2>/dev/null || true
rm -rf /var/lib/urepo 2>/dev/null || true

# Detect Linux Distribution
DISTRO="unknown"
DISTRO_FAMILY="unknown"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="${NAME:-$ID}"
    
    case "$ID" in
        ubuntu|debian|kali|linuxmint|pop|elementary|raspbian|parrot)
            DISTRO_FAMILY="debian"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            DISTRO_FAMILY="fedora"
            ;;
        arch|manjaro|endeavouros|garuda)
            DISTRO_FAMILY="arch"
            ;;
    esac

    # Check ID_LIKE if still unknown
    if [ "$DISTRO_FAMILY" == "unknown" ]; then
        for like in $ID_LIKE; do
            case "$like" in
                debian|ubuntu) DISTRO_FAMILY="debian"; break ;;
                fedora|rhel)   DISTRO_FAMILY="fedora"; break ;;
                arch)          DISTRO_FAMILY="arch"; break ;;
            esac
        done
    fi
fi

# Fallback detection
if [ "$DISTRO_FAMILY" == "unknown" ]; then
    if [ -f /etc/debian_version ] || command -v apt-get >/dev/null 2>&1; then
        DISTRO_FAMILY="debian"
    elif [ -f /etc/redhat-release ] || command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        DISTRO_FAMILY="fedora"
    elif [ -f /etc/arch-release ] || command -v pacman >/dev/null 2>&1; then
        DISTRO_FAMILY="arch"
    fi
fi

echo -e "${BLUE}🐧 Detected System: ${GREEN}${BOLD}$DISTRO ($DISTRO_FAMILY)${NC}"

# Configure system package manager
case "$DISTRO_FAMILY" in
    debian)
        echo -e "${BLUE}📦 Adding APT repository to /etc/apt/sources.list.d/skb-repo.list...${NC}"
        mkdir -p /etc/apt/sources.list.d
        echo "deb [trusted=yes] ${REPO_BASE}/database/debian ./" > /etc/apt/sources.list.d/skb-repo.list

        echo -e "${BLUE}🔄 Updating apt package cache...${NC}"
        apt-get update -o Dir::Etc::sourcelist="sources.list.d/skb-repo.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" || apt-get update -y || true

        echo ""
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}🎉 REPOSITORY ADDED SUCCESSFULLY TO APT!${NC}"
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${BOLD}Ab aap seedhe standard apt commands use kar sakte hain:${NC}"
        echo -e "  • ${CYAN}sudo apt update${NC}"
        echo -e "  • ${CYAN}sudo apt search <package>${NC}       (e.g., sudo apt search omengaminghub)"
        echo -e "  • ${CYAN}sudo apt install <package>${NC}      (e.g., sudo apt install omengaminghub)"
        echo -e "  • ${CYAN}sudo apt remove <package>${NC}       (e.g., sudo apt remove omengaminghub)"
        echo ""
        ;;

    fedora)
        echo -e "${BLUE}📦 Adding DNF repository to /etc/yum.repos.d/skb-repo.repo...${NC}"
        mkdir -p /etc/yum.repos.d
        cat << EOF > /etc/yum.repos.d/skb-repo.repo
[skb-repo]
name=SujitKumarBharti Linux Repository
baseurl=${REPO_BASE}/database/fedora
enabled=1
gpgcheck=0
EOF

        echo -e "${BLUE}🔄 Updating dnf cache...${NC}"
        if command -v dnf >/dev/null 2>&1; then
            dnf check-update || true
        else
            yum check-update || true
        fi

        echo ""
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}🎉 REPOSITORY ADDED SUCCESSFULLY TO DNF/YUM!${NC}"
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${BOLD}Ab aap seedhe standard dnf commands use kar sakte hain:${NC}"
        echo -e "  • ${CYAN}sudo dnf search <package>${NC}"
        echo -e "  • ${CYAN}sudo dnf install <package>${NC}"
        echo -e "  • ${CYAN}sudo dnf remove <package>${NC}"
        echo ""
        ;;

    arch)
        echo -e "${BLUE}📦 Configuring Pacman repository in /etc/pacman.conf...${NC}"
        if ! grep -q "\[skb-repo\]" /etc/pacman.conf; then
            cat << EOF >> /etc/pacman.conf

[skb-repo]
SigLevel = Optional TrustAll
Server = ${REPO_BASE}/database/arch
EOF
        fi

        echo -e "${BLUE}🔄 Syncing pacman databases...${NC}"
        pacman -Sy || true

        echo ""
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}🎉 REPOSITORY ADDED SUCCESSFULLY TO PACMAN!${NC}"
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${BOLD}Ab aap seedhe standard pacman commands use kar sakte hain:${NC}"
        echo -e "  • ${CYAN}sudo pacman -Ss <package>${NC}"
        echo -e "  • ${CYAN}sudo pacman -S <package>${NC}"
        echo -e "  • ${CYAN}sudo pacman -R <package>${NC}"
        echo ""
        ;;

    *)
        echo -e "${YELLOW}⚠️  Could not determine a native package manager for this OS.${NC}"
        echo "Supported: Debian, Ubuntu, Kali, Fedora, RHEL, Arch Linux."
        exit 1
        ;;
esac

echo -e "${PURPLE}Enjoy using SujitKumarBharti Linux Repository! 🚀${NC}"
echo ""
