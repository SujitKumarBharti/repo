#!/usr/bin/env bash
# ==============================================================================
# SujitKumarBharti Universal Linux Repository Removal / Uninstaller
# One-line Setup: curl -fsSL https://sujitkumarbharti.github.io/repo/uninstall.sh | sudo bash
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

echo -e "${RED}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════════╗"
echo "  ║       SUJIT KUMAR BHARTI - LINUX REPOSITORY REMOVAL           ║"
echo "  ║       https://sujitkumarbharti.github.io/repo                 ║"
echo "  ╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Error: This script must be run as root or with sudo.${NC}"
    echo -e "Please run:"
    echo -e "${CYAN}   curl -fsSL ${REPO_BASE}/uninstall.sh | sudo bash${NC}"
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

REMOVED_ANY=false

# Clean by package manager / distro family
case "$DISTRO_FAMILY" in
    debian)
        echo -e "${BLUE}🧹 Removing APT repository configuration...${NC}"
        if [ -f /etc/apt/sources.list.d/skb-repo.list ]; then
            rm -f /etc/apt/sources.list.d/skb-repo.list
            echo -e "  ${GREEN}✔ Removed /etc/apt/sources.list.d/skb-repo.list${NC}"
            REMOVED_ANY=true
        fi

        if [ -f /etc/apt/sources.list.d/skb-repo.sources ]; then
            rm -f /etc/apt/sources.list.d/skb-repo.sources
            echo -e "  ${GREEN}✔ Removed /etc/apt/sources.list.d/skb-repo.sources${NC}"
            REMOVED_ANY=true
        fi

        if [ -f /etc/apt/keyrings/skb-repo.gpg ]; then
            rm -f /etc/apt/keyrings/skb-repo.gpg
            echo -e "  ${GREEN}✔ Removed GPG keyring /etc/apt/keyrings/skb-repo.gpg${NC}"
            REMOVED_ANY=true
        fi

        if [ -f /etc/apt/trusted.gpg.d/skb-repo.gpg ]; then
            rm -f /etc/apt/trusted.gpg.d/skb-repo.gpg
            echo -e "  ${GREEN}✔ Removed legacy keyring /etc/apt/trusted.gpg.d/skb-repo.gpg${NC}"
            REMOVED_ANY=true
        fi

        # Remove any apt lists cache from this repo
        rm -f /var/lib/apt/lists/*sujitkumarbharti* 2>/dev/null || true

        echo -e "${BLUE}🔄 Refreshing APT cache...${NC}"
        apt-get update -o Dir::Etc::sourcelist="sources.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="1" 2>/dev/null || apt-get update -y 2>/dev/null || true
        ;;

    fedora)
        echo -e "${BLUE}🧹 Removing DNF/YUM repository configuration...${NC}"
        if [ -f /etc/yum.repos.d/skb-repo.repo ]; then
            rm -f /etc/yum.repos.d/skb-repo.repo
            echo -e "  ${GREEN}✔ Removed /etc/yum.repos.d/skb-repo.repo${NC}"
            REMOVED_ANY=true
        fi

        if [ -f /etc/yum.repos.d/urepo.repo ]; then
            rm -f /etc/yum.repos.d/urepo.repo
            echo -e "  ${GREEN}✔ Removed /etc/yum.repos.d/urepo.repo${NC}"
            REMOVED_ANY=true
        fi

        echo -e "${BLUE}🔄 Refreshing DNF/YUM cache...${NC}"
        if command -v dnf >/dev/null 2>&1; then
            dnf clean all --disablerepo="*" 2>/dev/null || dnf clean all || true
        else
            yum clean all || true
        fi
        ;;

    arch)
        echo -e "${BLUE}🧹 Removing Pacman repository configuration...${NC}"
        if [ -f /etc/pacman.conf ] && grep -q "\[skb-repo\]" /etc/pacman.conf; then
            cp -a /etc/pacman.conf /etc/pacman.conf.skb-repo.bak
            awk '
            /^[[:space:]]*\[skb-repo\]/ { in_section=1; next }
            /^[[:space:]]*\[/ { in_section=0 }
            !in_section { print }
            ' /etc/pacman.conf.skb-repo.bak > /etc/pacman.conf
            echo -e "  ${GREEN}✔ Removed [skb-repo] entry from /etc/pacman.conf (backup saved to /etc/pacman.conf.skb-repo.bak)${NC}"
            REMOVED_ANY=true
        fi

        # Remove sync cache database
        if ls /var/lib/pacman/sync/skb-repo.* >/dev/null 2>&1; then
            rm -f /var/lib/pacman/sync/skb-repo.* 2>/dev/null || true
            echo -e "  ${GREEN}✔ Cleaned pacman sync cache for skb-repo${NC}"
            REMOVED_ANY=true
        fi

        echo -e "${BLUE}🔄 Syncing pacman databases...${NC}"
        pacman -Sy || true
        ;;

    *)
        echo -e "${YELLOW}⚠️ Unknown distro family. Performing universal sweep...${NC}"
        ;;
esac

# Universal sweep in case files exist from a manual configuration
if [ -f /etc/apt/sources.list.d/skb-repo.list ]; then
    rm -f /etc/apt/sources.list.d/skb-repo.list
    REMOVED_ANY=true
fi
if [ -f /etc/apt/keyrings/skb-repo.gpg ]; then
    rm -f /etc/apt/keyrings/skb-repo.gpg
    REMOVED_ANY=true
fi
if [ -f /etc/yum.repos.d/skb-repo.repo ]; then
    rm -f /etc/yum.repos.d/skb-repo.repo
    REMOVED_ANY=true
fi

echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}🎉 SUJIT KUMAR BHARTI REPOSITORY REMOVED SUCCESSFULLY!${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Your system package manager has been restored to default.${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Packages previously installed from this repository (e.g. omengaminghub)"
echo -e "are still installed on your system. If you wish to remove them, run:"
case "$DISTRO_FAMILY" in
    debian)
        echo -e "  • ${CYAN}sudo apt remove <package>${NC}       (e.g., sudo apt remove omengaminghub)"
        ;;
    fedora)
        echo -e "  • ${CYAN}sudo dnf remove <package>${NC}"
        ;;
    arch)
        echo -e "  • ${CYAN}sudo pacman -R <package>${NC}"
        ;;
    *)
        echo -e "  • Use your native package manager's remove command (apt remove / dnf remove / pacman -R)."
        ;;
esac
echo ""
echo -e "${PURPLE}Clean-up complete! ✨${NC}"
echo ""
