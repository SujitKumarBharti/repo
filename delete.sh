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
    echo -e "  ${GREEN}(no arguments)${NC}             Launch interactive manager menu"
    echo -e "  ${GREEN}<package_name>${NC}             Target specific package for deletion from repository"
    echo -e "  ${GREEN}-c, --clean-local${NC}          Clean local package binaries (free PC disk space, keep on GitHub)"
    echo -e "  ${GREEN}-s, --status${NC}               Show repository storage status (local vs online)"
    echo -e "  ${GREEN}-r, --restore${NC}              Restore/download all package binaries to local disk"
    echo -e "  ${GREEN}-y, --yes, --force${NC}         Skip confirmation prompt"
    echo -e "  ${GREEN}-l, --list${NC}                 List all registered packages"
    echo -e "  ${GREEN}-h, --help${NC}                 Show this help screen"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  ./delete.sh                               # Interactive menu with options"
    echo "  ./delete.sh omengaminghub                 # Delete package with confirmation"
    echo "  ./delete.sh -c                            # Free local disk space immediately"
    echo "  ./delete.sh -s                            # Check disk usage vs online packages"
    echo ""
}

# Free local disk space using git sparse checkout
clean_local_disk() {
    print_banner
    echo -e "${BLUE}🧹 Cleaning local package binaries to free disk space...${NC}"

    if [ ! -d "$SCRIPT_DIR/.git" ]; then
        echo -e "${RED}❌ Error: Not a git repository.${NC}"
        return 1
    fi

    # Check uncommitted local binary files
    local uncommitted_binaries
    uncommitted_binaries=$(git status --porcelain "$DATABASE_DIR/" 2>/dev/null | grep -E '\.(deb|rpm|pkg\.tar\.zst|run|AppImage)$' || true)
    if [ -n "$uncommitted_binaries" ]; then
        echo -e "${YELLOW}⚠️  Notice: There are uncommitted package binaries in database/:${NC}"
        echo "$uncommitted_binaries"
        echo -e "${BLUE}📦 Automatically staging, committing, and pushing before cleaning local disk...${NC}"
        git config advice.updateSparsePath false 2>/dev/null || true
        git add --sparse database/
        git commit -m "chore: save packages to repository before cleaning" || true
        git push || true
    fi

    echo -e "${BLUE}⚙️  Configuring Git Sparse-Checkout...${NC}"
    git sparse-checkout set --no-cone '/*' '!database/*/*.deb' '!database/*/*.rpm' '!database/*/*.pkg.tar.zst' '!database/*/*.run' '!database/*/*.AppImage'

    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}🎉 LOCAL DISK CLEANUP COMPLETE!${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ✔ All packages remain safe and hosted on GitHub."
    echo -e "  ✔ Local package binaries removed from your PC to save disk space."
    echo -e "  ✔ Future git commits will ${GREEN}NEVER${NC} accidentally delete packages from GitHub."
    echo ""
}

# Show storage status (local vs online)
show_storage_status() {
    print_banner
    echo -e "${BLUE}${BOLD}📊 Repository Storage Status:${NC}\n"
    
    if [ -f "$REGISTRY_FILE" ]; then
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
' "$REGISTRY_FILE"
    else
        echo "  Registry file not found."
    fi

    echo ""
    local local_size
    local_size=$(du -sh "$DATABASE_DIR" 2>/dev/null | awk '{print $1}' || echo "0")
    echo -e "  Current local 'database/' folder size on your disk: ${YELLOW}${BOLD}$local_size${NC}"
    echo ""
}

# Restore packages to local disk
restore_local_packages() {
    print_banner
    echo -e "${BLUE}📦 Restoring all package binaries to local disk...${NC}"
    git sparse-checkout disable
    echo -e "${GREEN}✔ All package files checked out to local disk.${NC}"
}

# Update native APT repository indexes for Debian/Ubuntu/Kali
update_apt_repo() {
    local deb_dir="$DATABASE_DIR/debian"
    if [ ! -d "$deb_dir" ]; then return 0; fi

    echo -e "${BLUE}📦 Regenerating APT repository indexes (Packages, Packages.gz, Release)...${NC}"
    python3 -c '
import os, hashlib, datetime, sys, json, gzip

deb_dir = sys.argv[1]
reg_file = sys.argv[2]

try:
    with open(reg_file, "r") as f:
        data = json.load(f)
except Exception:
    data = {"packages": []}

packages = data.get("packages", [])
stanzas = []
import re

for p in packages:
    if p.get("os_type") == "debian":
        control = p.get("control_info", "").strip()
        fname = p.get("filename", "")
        size = p.get("size", 0)
        md5 = p.get("md5", "")
        sha1 = p.get("sha1", "")
        sha256 = p.get("sha256", "")

        if control:
            p_ver = str(p.get("version", ""))
            p_name = str(p.get("name", ""))
            control = re.sub(r"(?m)^Version:\s*.*$", "Version: " + p_ver, control)
            control = re.sub(r"(?m)^Package:\s*.*$", "Package: " + p_name, control)
            entry = f"{control}\nFilename: ./{fname}\nSize: {size}\nMD5sum: {md5}\nSHA1: {sha1}\nSHA256: {sha256}\n"
            stanzas.append(entry)

packages_content = "\n".join(stanzas) + ("\n" if stanzas else "")

pkg_file = os.path.join(deb_dir, "Packages")
with open(pkg_file, "w") as f:
    f.write(packages_content)

pkg_gz_file = os.path.join(deb_dir, "Packages.gz")
with open(pkg_file, "rb") as f_in, gzip.open(pkg_gz_file, "wb") as f_out:
    f_out.write(f_in.read())

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
' "$deb_dir" "$REGISTRY_FILE"

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

    # Delete file from git and local disk (handles sparse/cleaned files cleanly!)
    local abs_filepath="$SCRIPT_DIR/$filepath"
    if [ -d "$SCRIPT_DIR/.git" ]; then
        git rm --sparse -f "$filepath" 2>/dev/null || git rm -f "$filepath" 2>/dev/null || true
    fi
    if [ -f "$abs_filepath" ]; then
        rm -f "$abs_filepath"
        echo -e "${GREEN}🗑️  Deleted package file: $abs_filepath${NC}"
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
    echo -e "${BLUE}📦 Staging and committing deletion automatically...${NC}"
    git config advice.updateSparsePath false 2>/dev/null || true
    git add --sparse database/
    git commit -m "chore: delete $name v$ver from $os_type" || true

    echo -e "${BLUE}🚀 Pushing deletion to GitHub...${NC}"
    if git push; then
        echo ""
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}🎉 SUCCESS! Package '$name' permanently deleted from GitHub! ✨${NC}"
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    else
        echo -e "${YELLOW}⚠️ Git push was not completed. You can push manually with: ${CYAN}git push${NC}"
    fi
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

    echo "  ──────────────────────────────────────────────────────────────────────────────────"
    echo -e "  ${BOLD}Additional Options:${NC}"
    echo -e "    ${CYAN}[c]${NC} Clean local disk space (free up GBs, keep packages hosted on GitHub)"
    echo -e "    ${CYAN}[s]${NC} Check storage status (local disk usage vs online repository)"
    echo -e "    ${CYAN}[r]${NC} Restore all package binaries to local disk"
    echo -e "    ${CYAN}[q]${NC} Quit"
    echo ""
    read -p "Enter package number [#], option [c/s/r], or 'q' to quit: " user_choice

    case "$user_choice" in
        c|C)
            clean_local_disk
            exit 0
            ;;
        s|S)
            show_storage_status
            exit 0
            ;;
        r|R)
            restore_local_packages
            exit 0
            ;;
        q|Q|"")
            echo -e "${BLUE}Cancelled.${NC}"
            exit 0
            ;;
    esac

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
        -c|--clean-local)
            clean_local_disk
            exit 0
            ;;
        -s|--status)
            show_storage_status
            exit 0
            ;;
        -r|--restore)
            restore_local_packages
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
