#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Repository - Package Upload & Rollout Manager
# Maintainer: SujitKumarBharti
# Repository: https://github.com/SujitKumarBharti/repo
# ==============================================================================

set -e

# Terminal colors
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

# Print banner
print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║         UNIVERSAL LINUX REPOSITORY - UPLOAD MANAGER           ║"
    echo "  ║         https://sujitkumarbharti.github.io/repo               ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print help screen
show_help() {
    print_banner
    echo -e "${BOLD}USAGE:${NC}"
    echo "  ./upload.sh [OPTIONS]"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo -e "  ${GREEN}-u, --upload${NC}               Launch interactive upload wizard (default if no flags given)"
    echo -e "  ${GREEN}-l, --list${NC}                 List all packages currently in the database"
    echo -e "  ${GREEN}-s, --search <query>${NC}       Search packages by name or description"
    echo -e "  ${GREEN}--delete <name>${NC}            Delete a package from database and disk"
    echo -e "  ${GREEN}-h, --help${NC}                 Show this help message and exit"
    echo ""
    echo -e "${BOLD}AUTOMATED CLI FLAGS (Non-Interactive Mode):${NC}"
    echo "  -f, --file <path>          Path to package file (.deb, .rpm, .pkg.tar.zst, AppImage, binary)"
    echo "  -n, --name <name>          Package identifier (e.g. omen-gaming-hub)"
    echo "  -v, --version <version>    Package version (e.g. 1.0.0)"
    echo "  -o, --os <os_type>         Target OS: debian, fedora, arch, or universal"
    echo "  -d, --desc <description>   Package description"
    echo "  -r, --replace              Force replace existing package without prompting"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  ./upload.sh -u                                       # Interactive wizard"
    echo "  ./upload.sh -l                                       # List all packages"
    echo "  ./upload.sh -f ./app.deb -n myapp -v 1.0 -o debian   # Direct upload"
    echo "  ./upload.sh --delete myapp                           # Remove package"
    echo ""
}

# Verify registry file exists
ensure_registry() {
    mkdir -p "$DATABASE_DIR/debian" "$DATABASE_DIR/fedora" "$DATABASE_DIR/arch" "$DATABASE_DIR/universal"
    if [ ! -f "$REGISTRY_FILE" ]; then
        echo '{"repository":"SujitKumarBharti/repo","base_url":"https://sujitkumarbharti.github.io/repo","packages":[]}' > "$REGISTRY_FILE"
    fi
}

# List all packages
list_packages() {
    ensure_registry
    echo -e "${BLUE}${BOLD}📦 Registered Packages in Repository:${NC}\n"
    python3 -c '
import json, sys

with open(sys.argv[1], "r") as f:
    data = json.load(f)

packages = data.get("packages", [])
if not packages:
    print("  (No packages uploaded yet. Run ./upload.sh -u to upload your first package!)")
    sys.exit(0)

print("  {:<24} {:<10} {:<15} {:<30}".format("NAME", "VERSION", "TARGET OS", "FILENAME"))
print("  " + "-"*80)
for p in packages:
    name = p["name"]
    ver = p.get("version", "-")
    os_t = p.get("os_type", "-")
    fname = p.get("filename", "-")
    print("  {:<24} {:<10} {:<15} {:<30}".format(name, ver, os_t, fname))
print("\nTotal packages: {}".format(len(packages)))
' "$REGISTRY_FILE"
}

# Search package
search_packages() {
    local query="$1"
    ensure_registry
    echo -e "${BLUE}${BOLD}🔍 Searching for: '"${query}"'${NC}\n"
    python3 -c '
import json, sys

with open(sys.argv[1], "r") as f:
    data = json.load(f)

query = sys.argv[2].lower()
matches = [p for p in data.get("packages", []) if query in p["name"].lower() or query in p.get("description", "").lower()]

if not matches:
    print("  No packages found matching query.")
else:
    for p in matches:
        print("  • {} (v{}) [{}]".format(p["name"], p.get("version", "-"), p.get("os_type", "-")))
        print("    File: {}".format(p.get("filename", "-")))
        print("    Desc: {}\n".format(p.get("description", "-")))
' "$REGISTRY_FILE" "$query"
}

# Delete package
delete_package() {
    local pkg_name="$1"
    ensure_registry
    echo -e "${YELLOW}⚠️  Attempting to delete package: ${pkg_name}${NC}"
    
    local rel_fpath
    rel_fpath=$(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
p = next((x for x in d.get("packages", []) if x["name"] == sys.argv[2]), None)
print(p.get("filepath", "") if p else "")
' "$REGISTRY_FILE" "$pkg_name")

    if [ -n "$rel_fpath" ] && [ -d "$SCRIPT_DIR/.git" ]; then
        git rm --sparse -f "$rel_fpath" 2>/dev/null || git rm -f "$rel_fpath" 2>/dev/null || true
    fi

    python3 -c '
import json, os, sys

reg_file = sys.argv[1]
script_dir = sys.argv[2]
pkg_name = sys.argv[3]

with open(reg_file, "r") as f:
    data = json.load(f)

packages = data.get("packages", [])
target = next((p for p in packages if p["name"] == pkg_name), None)

if not target:
    print("Error: Package \"{}\" not found in registry.".format(pkg_name))
    sys.exit(1)

filepath = os.path.join(script_dir, target.get("filepath", ""))
if os.path.isfile(filepath):
    os.remove(filepath)
    print("Deleted file: {}".format(filepath))

data["packages"] = [p for p in packages if p["name"] != pkg_name]
with open(reg_file, "w") as f:
    json.dump(data, f, indent=2)

print("Successfully removed \"{}\" from registry.".format(pkg_name))
' "$REGISTRY_FILE" "$SCRIPT_DIR" "$pkg_name"

    update_apt_repo

    echo -e "${GREEN}✅ Deletion complete. Remember to commit and push:${NC}"
    echo "   git add database/"
    echo "   git commit -m \"chore: removed $pkg_name\""
    echo "   git push"
}

# Update native APT repository indexes for Debian/Ubuntu/Kali
update_apt_repo() {
    local deb_dir="$DATABASE_DIR/debian"
    if [ ! -d "$deb_dir" ]; then return 0; fi

    echo -e "${BLUE}📦 Updating APT repository indexes (Packages, Packages.gz, Release)...${NC}"
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

for p in packages:
    if p.get("os_type") == "debian":
        control = p.get("control_info", "").strip()
        fname = p.get("filename", "")
        size = p.get("size", 0)
        md5 = p.get("md5", "")
        sha1 = p.get("sha1", "")
        sha256 = p.get("sha256", "")

        if control:
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

# Core package process function
process_upload() {
    local input_file="$1"
    local pkg_name="$2"
    local pkg_version="$3"
    local os_type="$4"
    local pkg_desc="$5"
    local force_replace="$6"

    # Expand tilde if present
    input_file="${input_file/#\~/$HOME}"

    if [ ! -f "$input_file" ]; then
        echo -e "${RED}❌ Error: File not found at: $input_file${NC}"
        exit 1
    fi

    # Clean name
    pkg_name=$(echo "$pkg_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._-')
    if [ -z "$pkg_name" ]; then
        echo -e "${RED}❌ Error: Package name cannot be empty and must be alphanumeric (dashes and dots allowed).${NC}"
        exit 1
    fi

    local target_folder="$DATABASE_DIR/$os_type"
    mkdir -p "$target_folder"

    local base_filename=$(basename "$input_file")
    local extension="${base_filename##*.}"

    # Determine standard target filename
    local dest_filename="${pkg_name}_${pkg_version}.${extension}"
    if [ "$base_filename" == "$dest_filename" ] || [ "$extension" == "$base_filename" ]; then
        dest_filename="${pkg_name}_${pkg_version}"
    fi
    local dest_path="$target_folder/$dest_filename"
    local rel_path="database/$os_type/$dest_filename"

    ensure_registry

    # Check for existing package
    local check_result
    check_result=$(python3 -c '
import json, sys
with open(sys.argv[1], "r") as f:
    data = json.load(f)
name, os_type = sys.argv[2], sys.argv[3]
target = next((p for p in data.get("packages", []) if p["name"] == name and p.get("os_type") == os_type), None)
if target:
    print("EXISTS:{}:{}".format(target.get("version", ""), target.get("filepath", "")))
else:
    print("NEW")
' "$REGISTRY_FILE" "$pkg_name" "$os_type")

    if [[ "$check_result" =~ ^EXISTS: ]]; then
        local old_ver=$(echo "$check_result" | cut -d: -f2)
        local old_file=$(echo "$check_result" | cut -d: -f3)

        echo -e "${YELLOW}${BOLD}⚠️  PACKAGE ROLLOUT DETECTED:${NC}"
        echo -e "   Package '${BOLD}$pkg_name${NC}' already exists in ${CYAN}$os_type${NC} (Current version: ${YELLOW}$old_ver${NC})."
        echo -e "   Rolling out new version: ${GREEN}$pkg_version${NC}"
        echo -e "   Old file will be removed: ${RED}$old_file${NC}"

        if [ "$force_replace" != "true" ]; then
            read -p "   Proceed with replacing and rolling out update? [Y/n]: " confirm
            confirm=${confirm:-Y}
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "${RED}Cancelled by user.${NC}"
                exit 0
            fi
        fi

        # Remove old physical file if exists
        if [ -n "$old_file" ] && [ -f "$SCRIPT_DIR/$old_file" ]; then
            rm -f "$SCRIPT_DIR/$old_file"
            echo -e "${GREEN}   🗑️  Old package file deleted.${NC}"
        fi
    fi

    # Copy new file into database
    cp "$input_file" "$dest_path"
    chmod 644 "$dest_path"

    # Compute checksums, size, and metadata
    local sha256
    sha256=$(python3 -c '
import os, hashlib, subprocess, tarfile, io, json, sys, datetime

reg_file = sys.argv[1]
dest_path = sys.argv[2]
name = sys.argv[3]
ver = sys.argv[4]
os_t = sys.argv[5]
fname = sys.argv[6]
fpath = sys.argv[7]
desc = sys.argv[8]

with open(dest_path, "rb") as f:
    content = f.read()

size = len(content)
md5 = hashlib.md5(content).hexdigest()
sha1 = hashlib.sha1(content).hexdigest()
sha256 = hashlib.sha256(content).hexdigest()

control_info = ""
if os_t == "debian":
    try:
        control_info = subprocess.check_output(["dpkg-deb", "-f", dest_path], text=True)
    except Exception:
        try:
            with open(dest_path, "rb") as f:
                if f.read(8) == b"!<arch>\n":
                    while True:
                        h = f.read(60)
                        if len(h) < 60: break
                        fn = h[:16].strip().decode("ascii")
                        fs = int(h[48:58].strip())
                        fdata = f.read(fs)
                        if fs % 2 == 1: f.read(1)
                        if fn.startswith("control.tar"):
                            tf = tarfile.open(fileobj=io.BytesIO(fdata))
                            for m in tf.getmembers():
                                if m.name.endswith("control") and not m.isdir():
                                    extracted = tf.extractfile(m)
                                    if extracted:
                                        control_info = extracted.read().decode("utf-8", errors="replace")
        except Exception:
            pass

with open(reg_file, "r") as f:
    data = json.load(f)

packages = [p for p in data.get("packages", []) if not (p["name"] == name and p.get("os_type") == os_t)]

now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
pkg_entry = {
    "name": name,
    "version": ver,
    "os_type": os_t,
    "filename": fname,
    "filepath": fpath,
    "sha256": sha256,
    "size": size,
    "md5": md5,
    "sha1": sha1,
    "description": desc,
    "updated_at": now_iso
}
if control_info:
    pkg_entry["control_info"] = control_info

packages.append(pkg_entry)
data["packages"] = packages
data["updated_at"] = now_iso

with open(reg_file, "w") as f:
    json.dump(data, f, indent=2)

print(sha256)
' "$REGISTRY_FILE" "$dest_path" "$pkg_name" "$pkg_version" "$os_type" "$dest_filename" "$rel_path" "$pkg_desc")

    if [ "$os_type" == "debian" ]; then
        update_apt_repo
    fi
    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}🎉 SUCCESS! Package rolled out and indexed in database:${NC}"
    echo -e "   • Name:        ${BOLD}$pkg_name${NC}"
    echo -e "   • Version:     ${BOLD}$pkg_version${NC}"
    echo -e "   • Target OS:   ${BOLD}$os_type${NC}"
    echo -e "   • Stored File: ${CYAN}$rel_path${NC}"
    echo -e "   • SHA256:      ${PURPLE}$sha256${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo ""
    git config advice.updateSparsePath false 2>/dev/null || true
    read -p "🚀 Push to GitHub & automatically clean local disk space now? [y/N]: " auto_push_clean
    if [[ "$auto_push_clean" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}📦 Staging and committing changes...${NC}"
        git add --sparse database/
        git commit -m "feat: roll out $pkg_name v$pkg_version for $os_type" || true
        echo -e "${BLUE}🚀 Pushing to GitHub...${NC}"
        if git push; then
            echo -e "${BLUE}🧹 Automatically cleaning local binary to free disk space...${NC}"
            git sparse-checkout set --no-cone '/*' '!database/*/*.deb' '!database/*/*.rpm' '!database/*/*.pkg.tar.zst' '!database/*/*.run' '!database/*/*.AppImage' 2>/dev/null || true
            echo -e "${GREEN}${BOLD}🎉 SUCCESS! Package is live on GitHub and local disk space has been cleaned automatically! ✨${NC}"
        else
            echo -e "${YELLOW}⚠️ Git push was not completed (e.g. requires credentials in terminal).${NC}"
            echo -e "After pushing manually, you can clean local disk space anytime with: ${CYAN}./delete.sh -c${NC}"
        fi
    else
        echo -e "${YELLOW}${BOLD}🚀 NEXT STEP - PUSH TO GITHUB:${NC}"
        echo "Run these commands when you are ready to publish online:"
        echo -e "${CYAN}   git add --sparse database/${NC}"
        echo -e "${CYAN}   git commit -m \"feat: roll out $pkg_name v$pkg_version for $os_type\"${NC}"
        echo -e "${CYAN}   git push${NC}"
        echo ""
        echo -e "${YELLOW}${BOLD}💾 LOCAL DISK SPACE OPTIMIZATION:${NC}"
        echo -e "To automatically free local PC disk space after pushing, simply run:"
        echo -e "${CYAN}   ./delete.sh -c${NC}"
        echo -e "(or select option [c] from ${CYAN}./delete.sh${NC} interactive menu)."
    fi
    echo ""
}

# Interactive wizard
interactive_wizard() {
    print_banner
    echo -e "${BOLD}Welcome to the Interactive Package Upload & Rollout Wizard!${NC}\n"

    # Step 1: File location
    local input_file=""
    while [ -z "$input_file" ]; do
        read -e -p "📁 Step 1/5: Please enter file location (path to package): " input_file
        input_file="${input_file/#\~/$HOME}"
        if [ ! -f "$input_file" ]; then
            echo -e "${RED}   File '$input_file' not found! Please enter a valid path.${NC}"
            input_file=""
        fi
    done

    # Step 2: Package Name
    local pkg_name=""
    local suggested_name=$(basename "$input_file" | cut -d_ -f1 | cut -d- -f1)
    while [ -z "$pkg_name" ]; do
        read -p "📦 Step 2/5: Enter package name (e.g. omen-gaming-hub): " pkg_name
        pkg_name=$(echo "$pkg_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._-')
        if [ -z "$pkg_name" ]; then
            echo -e "${RED}   Package name is required! (letters, numbers, dashes, dots)${NC}"
        fi
    done

    # Step 3: Version
    local pkg_version=""
    while [ -z "$pkg_version" ]; do
        read -p "🔖 Step 3/5: Enter package version (e.g. 1.0.0): " pkg_version
        if [ -z "$pkg_version" ]; then
            echo -e "${RED}   Version is required!${NC}"
        fi
    done

    # Step 4: Target OS
    echo ""
    echo -e "${BLUE}${BOLD}🐧 Step 4/5: Select Target Linux Distribution / Type:${NC}"
    echo "   1) Ubuntu / Kali / Debian / Linux Mint / Pop!_OS (.deb)"
    echo "   2) Fedora / RHEL / CentOS / Rocky Linux (.rpm)"
    echo "   3) Arch Linux / Manjaro / EndeavourOS (.pkg.tar.zst)"
    echo "   4) Universal (AppImage / Standalone Binary / Script - works on ALL distros)"
    
    local os_type=""
    while [ -z "$os_type" ]; do
        read -p "   Select option [1-4]: " os_choice
        case "$os_choice" in
            1) os_type="debian" ;;
            2) os_type="fedora" ;;
            3) os_type="arch" ;;
            4) os_type="universal" ;;
            *) echo -e "${RED}   Invalid selection. Choose 1, 2, 3, or 4.${NC}" ;;
        esac
    done

    # Step 5: Description
    echo ""
    read -p "📝 Step 5/5: Enter short description: " pkg_desc
    if [ -z "$pkg_desc" ]; then
        pkg_desc="$pkg_name package for Linux"
    fi

    echo ""
    process_upload "$input_file" "$pkg_name" "$pkg_version" "$os_type" "$pkg_desc" "false"
}

# CLI Argument parsing
CLI_FILE=""
CLI_NAME=""
CLI_VER=""
CLI_OS=""
CLI_DESC=""
CLI_FORCE="false"

if [ $# -eq 0 ]; then
    interactive_wizard
    exit 0
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -u|--upload)
            interactive_wizard
            exit 0
            ;;
        -l|--list)
            list_packages
            exit 0
            ;;
        -s|--search)
            shift
            search_packages "$1"
            exit 0
            ;;
        --delete)
            shift
            delete_package "$1"
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--file)
            shift
            CLI_FILE="$1"
            ;;
        -n|--name)
            shift
            CLI_NAME="$1"
            ;;
        -v|--version)
            shift
            CLI_VER="$1"
            ;;
        -o|--os)
            shift
            CLI_OS="$1"
            ;;
        -d|--desc)
            shift
            CLI_DESC="$1"
            ;;
        -r|--replace|--force)
            CLI_FORCE="true"
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
    shift
done

# If arguments were provided via flags, execute direct upload
if [ -n "$CLI_FILE" ] && [ -n "$CLI_NAME" ] && [ -n "$CLI_VER" ] && [ -n "$CLI_OS" ]; then
    process_upload "$CLI_FILE" "$CLI_NAME" "$CLI_VER" "$CLI_OS" "$CLI_DESC" "$CLI_FORCE"
else
    echo -e "${RED}Missing required parameters for CLI upload.${NC}"
    echo "Usage: ./upload.sh -f <file> -n <name> -v <version> -o <debian|fedora|arch|universal>"
    echo "Or run './upload.sh -u' for the interactive wizard."
    exit 1
fi
