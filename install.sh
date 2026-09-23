#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Repository Installer Script
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
NC='\033[0m' # No Color

PRIMARY_URL="https://sujitkumarbharti.github.io/repo"
FALLBACK_URL="https://raw.githubusercontent.com/SujitKumarBharti/repo/main"

echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════════╗"
echo "  ║        SUJIT KUMAR BHARTI - UNIVERSAL LINUX REPO SETUP        ║"
echo "  ║        https://sujitkumarbharti.github.io/repo                ║"
echo "  ╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Error: This installer must be run as root or with sudo.${NC}"
    echo -e "Please run:"
    echo -e "${CYAN}   curl -fsSL https://sujitkumarbharti.github.io/repo/install.sh | sudo bash${NC}"
    exit 1
fi

# Detect Linux Distribution
DISTRO="Linux"
DISTRO_FAMILY="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="${NAME:-$ID}"
    case "$ID" in
        ubuntu|debian|kali|linuxmint|pop|elementary|raspbian)
            DISTRO_FAMILY="debian"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            DISTRO_FAMILY="fedora"
            ;;
        arch|manjaro|endeavouros)
            DISTRO_FAMILY="arch"
            ;;
    esac
fi
echo -e "${BLUE}🐧 Detected Linux System: ${GREEN}${BOLD}$DISTRO${NC}"

# Check required utilities (curl, python3)
echo -e "${BLUE}🔍 Checking system prerequisites...${NC}"
MISSING_TOOLS=()
for tool in curl python3 sha256sum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚙️  Installing missing dependencies: ${MISSING_TOOLS[*]}${NC}"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y "${MISSING_TOOLS[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "${MISSING_TOOLS[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm "${MISSING_TOOLS[@]}"
    else
        echo -e "${RED}❌ Please install ${MISSING_TOOLS[*]} manually and re-run.${NC}"
        exit 1
    fi
fi

# Download urepo CLI
echo -e "${BLUE}📥 Installing universal repository manager CLI ('urepo' and 'repo')...${NC}"
TEMP_BIN=$(mktemp)

DOWNLOAD_SUCCESS=false
if curl -fsSL --connect-timeout 5 "$PRIMARY_URL/bin/urepo" -o "$TEMP_BIN" 2>/dev/null; then
    DOWNLOAD_SUCCESS=true
elif curl -fsSL --connect-timeout 8 "$FALLBACK_URL/bin/urepo" -o "$TEMP_BIN" 2>/dev/null; then
    DOWNLOAD_SUCCESS=true
fi

if [ "$DOWNLOAD_SUCCESS" != "true" ]; then
    rm -f "$TEMP_BIN"
    echo -e "${RED}❌ Failed to download urepo CLI from repository.${NC}"
    echo "Please check your network connection."
    exit 1
fi

# Install to BOTH /usr/local/bin and /usr/bin to guarantee sudo PATH availability
cp "$TEMP_BIN" /usr/local/bin/urepo
chmod 755 /usr/local/bin/urepo
ln -sf /usr/local/bin/urepo /usr/local/bin/repo

if [ -d /usr/bin ]; then
    cp "$TEMP_BIN" /usr/bin/urepo
    chmod 755 /usr/bin/urepo
    ln -sf /usr/bin/urepo /usr/bin/repo
fi
rm -f "$TEMP_BIN"

# Initialize urepo cache
mkdir -p /var/lib/urepo
chmod 755 /var/lib/urepo

echo -e "${BLUE}🔄 Fetching repository registry...${NC}"
TEMP_REG=$(mktemp)
if curl -fsSL --connect-timeout 5 "$PRIMARY_URL/database/registry.json" -o "$TEMP_REG" 2>/dev/null || \
   curl -fsSL --connect-timeout 8 "$FALLBACK_URL/database/registry.json" -o "$TEMP_REG" 2>/dev/null; then
    mv "$TEMP_REG" /var/lib/urepo/registry.json
    chmod 644 /var/lib/urepo/registry.json
else
    rm -f "$TEMP_REG"
    echo -e "${YELLOW}⚠️  Could not pre-cache registry now. It will be fetched automatically on first use.${NC}"
fi

# Configure Native Package Manager Repositories
if [ "$DISTRO_FAMILY" == "debian" ] || [ -d /etc/apt/sources.list.d ]; then
    echo -e "${BLUE}⚙️  Configuring native APT repository (/etc/apt/sources.list.d/skb-repo.list)...${NC}"
    echo "deb [trusted=yes] https://sujitkumarbharti.github.io/repo/database/debian ./" > /etc/apt/sources.list.d/skb-repo.list
    echo -e "${BLUE}🔄 Updating apt package lists...${NC}"
    apt-get update -y || true
elif [ "$DISTRO_FAMILY" == "fedora" ] || [ -d /etc/yum.repos.d ]; then
    echo -e "${BLUE}⚙️  Configuring native DNF/YUM repository (/etc/yum.repos.d/skb-repo.repo)...${NC}"
    cat << 'EOF' > /etc/yum.repos.d/skb-repo.repo
[skb-repo]
name=SujitKumarBharti Universal Linux Repository
baseurl=https://sujitkumarbharti.github.io/repo/database/fedora
enabled=1
gpgcheck=0
EOF
fi

echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}🎉 REPOSITORY ADDED SUCCESSFULLY!${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Aap 2 tariko se packages install kar sakte hain:${NC}"
echo ""
echo -e "${CYAN}${BOLD}Option 1: Native APT se direct install karein:${NC}"
echo -e "  • ${GREEN}sudo apt update${NC}"
echo -e "  • ${GREEN}sudo apt search omengaminghub${NC}"
echo -e "  • ${GREEN}sudo apt install omengaminghub${NC}"
echo ""
echo -e "${CYAN}${BOLD}Option 2: Universal CLI (urepo / repo) se:${NC}"
echo -e "  • ${GREEN}urepo list${NC}                     View all available packages"
echo -e "  • ${GREEN}urepo search <term>${NC}            Search packages"
echo -e "  • ${GREEN}sudo urepo install <name>${NC}      Install package (e.g., sudo urepo install omengaminghub)"
echo -e "  • ${GREEN}sudo urepo remove <name>${NC}       Uninstall package"
echo ""
echo -e "${PURPLE}Enjoy using SujitKumarBharti Universal Linux Repository! 🚀${NC}"
echo ""
