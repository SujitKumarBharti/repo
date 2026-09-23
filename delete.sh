#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Repository - Package Delete & Rollout Cleaner
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
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$SCRIPT_DIR/database"
REGISTRY_FILE="$DATABASE_DIR/registry.json"

print_banner() {
    echo -e "${RED}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║         UNIVERSAL LINUX REPOSITORY - DELETE MANAGER           ║"
    echo "  ║         https://sujitkumarbharti.github.io/repo               ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_help() {
    print_banner
    echo -e "${BOLD}USAGE:${NC}"
    echo "  ./delete.sh [OPTIONS] [PACKAGE_NAME]"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo -e "  ${GREEN}(no arguments)${NC}             Launch interactive selection & delete menu"
    echo -e "  ${GREEN}<package_name>${NC}             Target specific package for deletion"
    echo -e "  ${GREEN}-y, --yes, --force${NC}         Skip confirmation prompt"
    echo -e "  ${GREEN}-l, --list${NC}                 List all registered packages"
    echo -e "  ${GREEN}-h, --help${NC}                 Show this help screen"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  ./delete.sh                               # Interactive menu with package numbers"
    echo "  ./delete.sh omengaminghub                 # Delete with confirmation"
    echo "  ./delete.sh omengaminghub -y              # Force delete without confirmation"
    echo ""
}

# Update native APT repository indexes for Debian/Ubuntu/Kali
update_apt_repo() {
    local deb_dir="$DATABASE_DIR/debian"
    if [ ! -d "$deb_dir" ]; then return 0; fi

    echo -e "${BLUE}📦 Regenerating APT repository indexes (Packages, Packages.gz, Release)...${NC}"
    python3 -c '
import os, hashlib, datetime, sys

deb_dir = sys.argv[1]
has_dpkg = os.system("which dpkg-scanpackages >/dev/null 2>&1") == 0

if has_dpkg:
    os.system("cd {} && dpkg-scanpackages . /dev/null > Packages 2>/dev/null && gzip -k -f Packages".format(deb_dir))

pkg_file = os.path.join(deb_dir, "Packages")
pkg_gz_file = os.path.join(deb_dir, "Packages.gz")

if os.path.isfile(pkg_file) and os.path.isfile(pkg_gz_file):
    def get_hashes(filepath):
        with open(filepath, "rb") as f:
            data = f.read()
        return len(data), hashlib.md5(data).hexdigest(), hashlib.sha256(data).hexdigest()

    pkg_size, pkg_md5, pkg_sha256 = get_hashes(pkg_file)
    gz_size, gz_md5, gz_sha256 = get_hashes(pkg_gz_file)

    now_rfc = datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S UTC")
    release_content = (
        "Origin: SujitKumarBharti Repo\n"
        "Label: SujitKumarBharti Universal Linux Repository\n"
        "Suite: stable\n"
        "Codename: stable\n"
        "Version: 1.0\n"
        "Components: main\n"
        "Architectures: amd64 arm64 all\n"
        "Date: {}\n"
        "MD5Sum:\n"
        " {} {} Packages\n"
        " {} {} Packages.gz\n"
        "SHA256:\n"
        " {} {} Packages\n"
        " {} {} Packages.gz\n"
    ).format(now_rfc, pkg_md5, pkg_size, gz_md5, gz_size, pkg_sha256, pkg_size, gz_sha256, gz_size)

    with open(os.path.join(deb_dir, "Release"), "w") as f:
        f.write(release_content)
' "$deb_dir"

    # Sign Release with GPG to generate InRelease and Release.gpg
    local gnupg_dir="$SCRIPT_DIR/keys/gnupg"
    if [ -d "$gnupg_dir" ] && command -v gpg >/dev/null 2>&1; then
        export GNUPGHOME="$gnupg_dir"
        gpg --batch --yes --clearsign --output "$deb_dir/InRelease" "$deb_dir/Release" 2>/dev/null || true
        gpg --batch --yes --detach-sign --armor --output "$deb_dir/Release.gpg" "$deb_dir/Release" 2>/dev/null || true
    fi
}

# Perform physical and registry deletion
execute_delete() {
    local target_name="$1"
    local target_os="$2"
    local force_flag="$3"

    # Fetch package details
    local pkg_details
    pkg_details=$(python3 -c '
import json, sys

reg_file = sys.argv[1]
name = sys.argv[2]
os_t = sys.argv[3] if len(sys.argv) > 3 else ""

try:
    with open(reg_file, "r") as f:
        data = json.load(f)
except:
    print("EMPTY")
    sys.exit(0)

packages = data.get("packages", [])
target = None

for p in packages:
    if p["name"] == name:
        if not os_t or p.get("os_type") == os_t:
            target = p
            break

if not target:
    print("NOT_FOUND")
else:
    print("{}|{}|{}|{}|{}".format(
        target["name"],
        target.get("version", "-"),
        target.get("os_type", "-"),
        target.get("filepath", ""),
        target.get("filename", "")
    ))
' "$REGISTRY_FILE" "$target_name" "$target_os")

    if [ "$pkg_details" == "NOT_FOUND" ] || [ "$pkg_details" == "EMPTY" ]; then
        echo -e "${RED}❌ Package '$target_name' not found in repository database.${NC}"
        return 1
    fi

    IFS='|' read -r name ver os_type filepath filename <<< "$pkg_details"

    echo ""
    echo -e "${YELLOW}${BOLD}⚠️  CONFIRM PACKAGE DELETION:${NC}"
    echo -e "   • Name:        ${BOLD}$name${NC}"
    echo -e "   • Version:     ${BOLD}$ver${NC}"
    echo -e "   • Target OS:   ${CYAN}$os_type${NC}"
    echo -e "   • File:        ${RED}$filepath${NC}"
    echo ""

    if [ "$force_flag" != "true" ]; then
        read -p "Are you sure you want to permanently delete this package? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Deletion cancelled.${NC}"
            return 0
        fi
    fi

    # Delete physical file
    local abs_filepath="$SCRIPT_DIR/$filepath"
    if [ -f "$abs_filepath" ]; then
        rm -f "$abs_filepath"
        echo -e "${GREEN}🗑️  Deleted package file: $abs_filepath${NC}"
    else
        echo -e "${YELLOW}File $abs_filepath was already removed or missing from disk.${NC}"
    fi

    # Remove from registry.json
    python3 -c '
import json, sys

reg_file = sys.argv[1]
name = sys.argv[2]
os_t = sys.argv[3]

with open(reg_file, "r") as f:
    data = json.load(f)

packages = data.get("packages", [])
data["packages"] = [p for p in packages if not (p["name"] == name and (not os_t or p.get("os_type") == os_t))]

with open(reg_file, "w") as f:
    json.dump(data, f, indent=2)
' "$REGISTRY_FILE" "$name" "$os_type"

    echo -e "${GREEN}✓ Removed '$name' from registry database.${NC}"

    # If debian package, update APT index
    if [ "$os_type" == "debian" ]; then
        update_apt_repo
    fi

    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}🎉 SUCCESS! Package '$name' deleted from repository.${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}🚀 NEXT STEP - PUSH TO GITHUB:${NC}"
    echo "Run these commands to apply the deletion online:"
    echo -e "${CYAN}   git add .${NC}"
    echo -e "${CYAN}   git commit -m \"chore: delete $name v$ver from $os_type\"${NC}"
    echo -e "${CYAN}   git push${NC}"
    echo ""
}

# Interactive selection menu
interactive_menu() {
    print_banner

    # Check packages count
    local pkg_count
    pkg_count=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    print(len(data.get("packages", [])))
except:
    print("0")
' "$REGISTRY_FILE")

    if [ "$pkg_count" -eq 0 ]; then
        echo -e "${YELLOW}No packages currently exist in the repository database.${NC}"
        echo -e "You can upload a package using: ${CYAN}./upload.sh -u${NC}\n"
        exit 0
    fi

    echo -e "${BLUE}${BOLD}📦 Select a package to delete from the list below:${NC}\n"

    # Display numbered table and store mappings
    python3 -c '
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

packages = data.get("packages", [])
print("  {:<5} {:<24} {:<10} {:<12} {:<30}".format("[#]", "NAME", "VERSION", "DISTRO", "FILENAME"))
print("  " + "-"*82)

for i, p in enumerate(packages, 1):
    num = "[{}]".format(i)
    name = p["name"]
    ver = p.get("version", "-")
    os_t = p.get("os_type", "-")
    fname = p.get("filename", "-")
    print("  {:<5} {:<24} {:<10} {:<12} {:<30}".format(num, name, ver, os_t, fname))
' "$REGISTRY_FILE"

    echo ""
    read -p "Enter package number [#] to delete, package name, or 'q' to quit: " user_choice

    if [ "$user_choice" == "q" ] || [ "$user_choice" == "Q" ] || [ -z "$user_choice" ]; then
        echo -e "${BLUE}Cancelled.${NC}"
        exit 0
    fi

    # Check if choice is a number
    if [[ "$user_choice" =~ ^[0-9]+$ ]]; then
        local selected
        selected=$(python3 -c '
import json, sys

idx = int(sys.argv[2]) - 1
with open(sys.argv[1]) as f:
    data = json.load(f)

packages = data.get("packages", [])
if 0 <= idx < len(packages):
    p = packages[idx]
    print("{}|{}".format(p["name"], p.get("os_type", "")))
else:
    print("INVALID")
' "$REGISTRY_FILE" "$user_choice")

        if [ "$selected" == "INVALID" ]; then
            echo -e "${RED}❌ Invalid selection number: $user_choice${NC}"
            exit 1
        fi

        local sel_name=$(echo "$selected" | cut -d'|' -f1)
        local sel_os=$(echo "$selected" | cut -d'|' -f2)
        execute_delete "$sel_name" "$sel_os" "false"
    else
        # User entered a package name directly
        execute_delete "$user_choice" "" "false"
    fi
}

# CLI Argument handling
FORCE="false"
TARGET_PKG=""

if [ $# -eq 0 ]; then
    interactive_menu
    exit 0
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
packages = data.get("packages", [])
if not packages:
    print("No packages registered.")
else:
    print("  {:<24} {:<10} {:<12} {:<30}".format("NAME", "VERSION", "DISTRO", "FILENAME"))
    print("  " + "-"*78)
    for p in packages:
        print("  {:<24} {:<10} {:<12} {:<30}".format(p["name"], p.get("version", "-"), p.get("os_type", "-"), p.get("filename", "-")))
' "$REGISTRY_FILE"
            exit 0
            ;;
        -y|--yes|--force)
            FORCE="true"
            ;;
        *)
            TARGET_PKG="$1"
            ;;
    esac
    shift
done

if [ -n "$TARGET_PKG" ]; then
    execute_delete "$TARGET_PKG" "" "$FORCE"
else
    interactive_menu
fi
