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
    echo "  -f, --file <path|url>      Path to local file OR remote URL (deb/rpm/zst/AppImage/bin)"
    echo "  -n, --name <name>          Package identifier (e.g. burpsuite-pro)"
    echo "  -v, --version <version>    Package version (e.g. 2026.4.0)"
    echo "  -o, --os <os_type>         Target OS: debian, fedora, arch, or universal"
    echo "  -d, --desc <description>   Package description"
    echo "  -m, --remote-url <url(s)>  Remote download URL(s) for packages > 100MB"
    echo "                             Supports: Google Drive, Mega.nz, Direct IP/Apache/Nginx,"
    echo "                             DuckDNS, TeraBox, GitHub Releases, Dropbox, OneDrive, etc."
    echo "                             Multiple URLs can be comma-separated for failover mirrors."
    echo "  -r, --replace              Force replace existing package without prompting"
    echo ""
    echo -e "${BOLD}SUPPORTED REMOTE PROVIDERS (>100MB PAYLOADS):${NC}"
    echo "  • Google Drive:            https://drive.google.com/file/d/<id>/view"
    echo "  • Mega.nz:                 https://mega.nz/file/<id>#<key>"
    echo "  • Direct IP / Web Host:    http://192.168.1.100:8080/repo/app.deb"
    echo "  • DuckDNS / Apache:        https://jharkhand.duckdns.org/repo/app.deb"
    echo "  • GitHub Releases:         https://github.com/<user>/<repo>/releases/download/v1.0/app.deb"
    echo "  • TeraBox & Mirrors:       https://terabox.com/s/<surl>"
    echo "  • Dropbox / MediaFire:     https://www.dropbox.com/s/... | https://www.mediafire.com/file/..."
    echo "  • Multi-Mirror Failover:   url1, url2 (auto-fallback if primary host goes down)"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  ./upload.sh -u                                       # Interactive wizard"
    echo "  ./upload.sh -l                                       # List all packages"
    echo "  ./upload.sh -f ./app.deb -n myapp -v 1.0 -o debian   # Direct local upload"
    echo "  ./upload.sh -f https://mega.nz/file/ID#KEY -n myapp -v 1.0 -o debian"
    echo "  ./upload.sh -f ./big.deb -n myapp -v 1.0 -o debian -m https://drive.google.com/file/d/ID/view"
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

print("  {:<22} {:<10} {:<12} {:<30} {:<10}".format("NAME", "VERSION", "TARGET OS", "FILENAME", "STORAGE"))
print("  " + "-"*88)
for p in packages:
    name = p["name"]
    ver = p.get("version", "-")
    os_t = p.get("os_type", "-")
    fname = p.get("filename", "-")
    is_rem = p.get("is_remote", False)
    storage = "REMOTE" if is_rem else "GITHUB"
    print("  {:<22} {:<10} {:<12} {:<30} {:<10}".format(name, ver, os_t, fname, storage))
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
        is_rem = p.get("is_remote", False)
        mode = " [REMOTE PAYLOAD]" if is_rem else ""
        print("  • {} (v{}) [{}]{}".format(p["name"], p.get("version", "-"), p.get("os_type", "-"), mode))
        print("    File: {}".format(p.get("filename", "-")))
        if is_rem:
            print("    Remote URL: {}".format(p.get("remote_url", "-")))
        print("    Desc: {}\n".format(p.get("description", "-")))
' "$REGISTRY_FILE" "$query"
}

# Delete package (delegates to delete.sh)
delete_package() {
    local pkg_name="$1"
    "$SCRIPT_DIR/delete.sh" "$pkg_name" -y
}

# Update native APT repository indexes for Debian/Ubuntu/Kali
update_apt_repo() {
    local deb_dir="$DATABASE_DIR/debian"
    if [ ! -d "$deb_dir" ]; then return 0; fi

    echo -e "${BLUE}📦 Updating APT repository indexes (Packages, Packages.gz, Release)...${NC}"
    python3 -c '
import os, hashlib, datetime, sys, json, gzip
import re

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

# Core package process function
process_upload() {
    local input_file="$1"
    local pkg_name="$2"
    local pkg_version="$3"
    local os_type="$4"
    local pkg_desc="$5"
    local force_replace="$6"
    local remote_url="$7"

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

    # File size verification for GitHub 100 MB Limit
    local file_size
    file_size=$(stat -c%s "$input_file" 2>/dev/null || wc -c < "$input_file")
    local max_allowed=$((100 * 1024 * 1024)) # 100 MB
    local is_remote="false"

    if [ "$file_size" -gt "$max_allowed" ] || [ -n "$remote_url" ]; then
        is_remote="true"
        if [ -z "$remote_url" ]; then
            local size_mb
            size_mb=$(python3 -c "import sys; print('{:.2f}'.format(float(sys.argv[1]) / (1024*1024)))" "$file_size")
            echo ""
            echo -e "${YELLOW}${BOLD}⚠️  PACKAGE FILE EXCEEDS GITHUB 100 MB LIMIT (${size_mb} MB):${NC}"
            echo -e "${YELLOW}   GitHub strictly blocks commits containing files larger than 100 MB.${NC}"
            echo -e "${CYAN}${BOLD}   Supported Remote Hosting Providers & Locations:${NC}"
            echo -e "   • ${GREEN}Google Drive:${NC}          https://drive.google.com/file/d/<id>/view"
            echo -e "   • ${GREEN}Mega.nz:${NC}               https://mega.nz/file/<id>#<key>"
            echo -e "   • ${GREEN}Direct IP / Web Host:${NC}  http://192.168.1.100:8080/repo/app.deb"
            echo -e "   • ${GREEN}DuckDNS / Apache:${NC}      https://jharkhand.duckdns.org/repo/app.deb"
            echo -e "   • ${GREEN}GitHub Releases:${NC}       https://github.com/<user>/<repo>/releases/download/v1.0/app.deb"
            echo -e "   • ${GREEN}TeraBox & Mirrors:${NC}     https://terabox.com/s/<surl>"
            echo -e "   • ${GREEN}Dropbox / MediaFire:${NC}   https://www.dropbox.com/s/... | https://www.mediafire.com/file/..."
            echo -e "   • ${PURPLE}Multi-Mirror Failover:${NC} Enter multiple URLs separated by comma (,)"
            echo ""
            read -p "🌐 Enter remote download URL(s): " remote_url
            remote_url=$(echo "$remote_url" | xargs)
            if [ -z "$remote_url" ]; then
                echo -e "${RED}❌ Error: Remote download URL is mandatory for packages exceeding 100 MB.${NC}"
                exit 1
            fi
        fi

        # Auto-normalize URLs in remote_url (supports comma-separated multi-mirror list)
        remote_url=$(python3 -c '
import sys, re
raw = sys.argv[1]
items = [u.strip() for u in re.split(r"[\s,;]+", raw) if u.strip()]
normalized = []
for u in items:
    if not re.match(r"^https?://", u):
        if re.match(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}", u):
            normalized.append("http://" + u)
        else:
            normalized.append("https://" + u)
    else:
        normalized.append(u)
print(", ".join(normalized))
' "$remote_url")

        echo -e "${BLUE}🌐 Configured Remote Source:${NC} ${BOLD}$remote_url${NC}"
        if [ -f "$SCRIPT_DIR/scripts/downloader.py" ]; then
            python3 "$SCRIPT_DIR/scripts/downloader.py" --info $remote_url 2>/dev/null | grep "Provider:" | while read -r line; do
                echo -e "   ${GREEN}✔ $line${NC}"
            done
        fi
    fi

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

        # Remove old physical file and git tracked file
        if [ -n "$old_file" ]; then
            if [ -d "$SCRIPT_DIR/.git" ]; then
                git rm --sparse -f "$old_file" 2>/dev/null || git rm -f "$old_file" 2>/dev/null || true
            fi
            rm -f "$SCRIPT_DIR/$old_file" 2>/dev/null || true
            echo -e "${GREEN}   🗑️  Old package file removed from repository.${NC}"
        fi
    fi

    local orig_size=$file_size
    local orig_sha256
    orig_sha256=$(sha256sum "$input_file" | awk '{print $1}')
    local orig_md5
    orig_md5=$(md5sum "$input_file" | awk '{print $1}')
    local orig_sha1
    orig_sha1=$(sha1sum "$input_file" | awk '{print $1}')

    # Process and build repository package
    if [ "$is_remote" == "true" ]; then
        if [ "$os_type" == "debian" ]; then
            echo -e "${BLUE}⚙️  Generating lightweight payload-fetcher wrapper (.deb) package...${NC}"
            local tmp_build_dir
            tmp_build_dir=$(mktemp -d)
            mkdir -p "$tmp_build_dir/DEBIAN"
            mkdir -p "$tmp_build_dir/usr/lib/repo-helper"

            # Bundle universal multi-provider downloader into wrapper package
            cp "$SCRIPT_DIR/scripts/downloader.py" "$tmp_build_dir/usr/lib/repo-helper/downloader.py"
            chmod 755 "$tmp_build_dir/usr/lib/repo-helper/downloader.py"

            # Extract control and maintainer scripts from input deb
            dpkg-deb -e "$input_file" "$tmp_build_dir/DEBIAN" 2>/dev/null || true

            local ctrl_file="$tmp_build_dir/DEBIAN/control"
            if [ ! -f "$ctrl_file" ]; then
                cat << EOF > "$ctrl_file"
Package: $pkg_name
Version: $pkg_version
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Repository Maintainer
Description: $pkg_desc
EOF
            fi

            # Synchronize Package and Version in control
            sed -i -E "s/^(Package:).*/\1 $pkg_name/" "$ctrl_file"
            sed -i -E "s/^(Version:).*/\1 $pkg_version/" "$ctrl_file"

            # Ensure Depends includes python3, curl | wget, ca-certificates
            if grep -q "^Depends:" "$ctrl_file"; then
                if ! grep -q "python3" "$ctrl_file"; then
                    sed -i -E 's/^(Depends:\s*)(.*)/\1python3, \2/' "$ctrl_file"
                fi
                if ! grep -q "curl" "$ctrl_file" && ! grep -q "wget" "$ctrl_file"; then
                    sed -i -E 's/^(Depends:\s*)(.*)/\1curl | wget, ca-certificates, \2/' "$ctrl_file"
                fi
            else
                echo "Depends: python3, curl | wget, ca-certificates" >> "$ctrl_file"
            fi
            if ! grep -q "^Recommends:" "$ctrl_file"; then
                echo "Recommends: openssl" >> "$ctrl_file"
            fi

            # If original postinst exists, preserve it so wrapper executes it after payload extraction
            if [ -f "$tmp_build_dir/DEBIAN/postinst" ]; then
                mkdir -p "$tmp_build_dir/usr/share/$pkg_name"
                mv "$tmp_build_dir/DEBIAN/postinst" "$tmp_build_dir/usr/share/$pkg_name/.orig_postinst"
                chmod 755 "$tmp_build_dir/usr/share/$pkg_name/.orig_postinst"
            fi

            # Create installer postinst
            cat << 'EOF_POSTINST' > "$tmp_build_dir/DEBIAN/postinst"
#!/bin/sh
set -e

PKG_NAME="__PKG_NAME__"
PKG_VER="__PKG_VERSION__"
REMOTE_URL="__REMOTE_URL__"
EXPECTED_SHA256="__EXPECTED_SHA256__"

echo ""
echo "================================================================================"
echo "  SUJIT KUMAR BHARTI LINUX REPOSITORY - REMOTE PAYLOAD INSTALLER"
echo "  Downloading: $PKG_NAME (v$PKG_VER)"
echo "  Source:      $REMOTE_URL"
echo "================================================================================"

TMP_DEB=$(mktemp /tmp/${PKG_NAME}_payload_XXXXXX.deb)
trap 'rm -f "$TMP_DEB"' EXIT INT TERM

DOWNLOAD_SUCCESS=false

# 1. Primary Engine: Python Multi-Provider Downloader (Google Drive, Mega, IP, TeraBox, Dropbox, etc.)
if command -v python3 >/dev/null 2>&1 && [ -f "/usr/lib/repo-helper/downloader.py" ]; then
    echo "[*] Launching multi-provider payload fetcher..."
    if python3 /usr/lib/repo-helper/downloader.py $REMOTE_URL -o "$TMP_DEB" --sha256 "$EXPECTED_SHA256"; then
        DOWNLOAD_SUCCESS=true
    fi
fi

# 2. Fallback Engine: Direct curl/wget for HTTP/HTTPS/IP mirrors
if [ "$DOWNLOAD_SUCCESS" != "true" ]; then
    echo "[*] Falling back to standard direct transfer (curl/wget)..."
    for url in $(echo "$REMOTE_URL" | tr ',;' ' '); do
        echo "[*] Trying endpoint: $url"
        if command -v curl >/dev/null 2>&1; then
            if curl -fL --progress-bar "$url" -o "$TMP_DEB"; then
                DOWNLOAD_SUCCESS=true
                break
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget --show-progress -qO "$TMP_DEB" "$url"; then
                DOWNLOAD_SUCCESS=true
                break
            fi
        fi
    done
fi

if [ "$DOWNLOAD_SUCCESS" != "true" ]; then
    echo "[-] Error: Failed to download package payload from all remote endpoints." >&2
    exit 1
fi

if [ -n "$EXPECTED_SHA256" ] && command -v sha256sum >/dev/null 2>&1; then
    echo "[*] Verifying package integrity (SHA256)..."
    ACTUAL_SHA256=$(sha256sum "$TMP_DEB" | awk '{print $1}')
    if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "[-] ERROR: Integrity verification failed! Checksum mismatch." >&2
        echo "    Expected: $EXPECTED_SHA256" >&2
        echo "    Actual:   $ACTUAL_SHA256" >&2
        exit 1
    fi
    echo "[+] Checksum verified: $ACTUAL_SHA256"
fi

echo "[*] Extracting package files to system..."
dpkg -x "$TMP_DEB" /

# Register extracted files in /var/lib/dpkg/info/<pkg>.list so dpkg tracks them
if [ -f "/var/lib/dpkg/info/${PKG_NAME}.list" ]; then
    dpkg -c "$TMP_DEB" | awk '{print $6}' | sed 's/^\.//' | grep -v '^$' >> "/var/lib/dpkg/info/${PKG_NAME}.list" || true
    echo "/usr/lib/repo-helper/downloader.py" >> "/var/lib/dpkg/info/${PKG_NAME}.list" 2>/dev/null || true
    sort -u "/var/lib/dpkg/info/${PKG_NAME}.list" -o "/var/lib/dpkg/info/${PKG_NAME}.list" 2>/dev/null || true
fi

rm -f "$TMP_DEB"

# Execute original postinst if present
if [ -f "/usr/share/${PKG_NAME}/.orig_postinst" ]; then
    echo "[*] Running package post-install configuration..."
    sh "/usr/share/${PKG_NAME}/.orig_postinst" "$@" || true
    rm -f "/usr/share/${PKG_NAME}/.orig_postinst" 2>/dev/null || true
fi

echo "[+] $PKG_NAME (v$PKG_VER) successfully installed!"
echo "================================================================================"
echo ""
exit 0
EOF_POSTINST

            # Safe literal substitution without sed corruption
            python3 -c '
import sys
p, name, ver, url, sha = sys.argv[1:6]
with open(p, "r") as f:
    c = f.read()
c = c.replace("__PKG_NAME__", name)
c = c.replace("__PKG_VERSION__", ver)
c = c.replace("__REMOTE_URL__", url)
c = c.replace("__EXPECTED_SHA256__", sha)
with open(p, "w") as f:
    f.write(c)
' "$tmp_build_dir/DEBIAN/postinst" "$pkg_name" "$pkg_version" "$remote_url" "$orig_sha256"
            chmod 755 "$tmp_build_dir/DEBIAN/postinst"

            dpkg-deb --root-owner-group -b "$tmp_build_dir" "$dest_path" >/dev/null 2>&1
            chmod 644 "$dest_path"
            rm -rf "$tmp_build_dir"
            echo -e "${GREEN}   ✔ Lightweight wrapper package created: $dest_filename ($(du -h "$dest_path" | cut -f1))${NC}"
        elif [ "$os_type" == "universal" ]; then
            echo -e "${BLUE}⚙️  Generating universal launcher script for remote payload...${NC}"
            cat << 'EOF_UNI' > "$dest_path"
#!/usr/bin/env bash
# Universal Launcher for __PKG_NAME__ (Remote Payload)
set -e
PKG_NAME="__PKG_NAME__"
REMOTE_URL="__REMOTE_URL__"
EXPECTED_SHA256="__EXPECTED_SHA256__"
CACHE_DIR="$HOME/.local/share/$PKG_NAME"
TARGET_BIN="$CACHE_DIR/__DEST_FILENAME__"

if [ ! -f "$TARGET_BIN" ]; then
    mkdir -p "$CACHE_DIR"
    echo "Downloading $PKG_NAME from remote host ($REMOTE_URL)..."
    DOWNLOAD_SUCCESS=false
    
    # Try Python multi-provider downloader if available
    if command -v python3 >/dev/null 2>&1 && [ -f "/usr/lib/repo-helper/downloader.py" ]; then
        if python3 /usr/lib/repo-helper/downloader.py $REMOTE_URL -o "$TARGET_BIN" --sha256 "$EXPECTED_SHA256"; then
            DOWNLOAD_SUCCESS=true
        fi
    fi

    # Fallback to direct curl / wget
    if [ "$DOWNLOAD_SUCCESS" != "true" ]; then
        for url in $(echo "$REMOTE_URL" | tr ',;' ' '); do
            if command -v curl >/dev/null 2>&1; then
                if curl -fL --progress-bar "$url" -o "$TARGET_BIN"; then
                    DOWNLOAD_SUCCESS=true
                    break
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget --show-progress -qO "$TARGET_BIN" "$url"; then
                    DOWNLOAD_SUCCESS=true
                    break
                fi
            fi
        done
    fi

    if [ "$DOWNLOAD_SUCCESS" != "true" ]; then
        echo "Error: Failed to download payload from remote host." >&2
        exit 1
    fi

    if [ -n "$EXPECTED_SHA256" ] && command -v sha256sum >/dev/null 2>&1; then
        ACTUAL_SHA256=$(sha256sum "$TARGET_BIN" | awk '{print $1}')
        if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
            echo "Checksum mismatch for downloaded payload!" >&2
            rm -f "$TARGET_BIN"
            exit 1
        fi
    fi
    chmod +x "$TARGET_BIN"
fi

exec "$TARGET_BIN" "$@"
EOF_UNI
            python3 -c '
import sys
p, name, url, sha, fname = sys.argv[1:6]
with open(p, "r") as f:
    c = f.read()
c = c.replace("__PKG_NAME__", name)
c = c.replace("__REMOTE_URL__", url)
c = c.replace("__EXPECTED_SHA256__", sha)
c = c.replace("__DEST_FILENAME__", fname)
with open(p, "w") as f:
    f.write(c)
' "$dest_path" "$pkg_name" "$remote_url" "$orig_sha256" "$dest_filename"
            chmod 755 "$dest_path"
            echo -e "${GREEN}   ✔ Universal remote launcher created: $dest_filename${NC}"
        else
            cp "$input_file" "$dest_path"
            chmod 644 "$dest_path"
        fi
    else
        # Standard local package copy
        cp "$input_file" "$dest_path"
        chmod 644 "$dest_path"

        # Synchronize internal deb control version if Debian package
        if [ "$os_type" == "debian" ]; then
            if command -v dpkg-deb >/dev/null 2>&1; then
                local deb_internal_ver
                deb_internal_ver=$(dpkg-deb -f "$dest_path" Version 2>/dev/null || echo "")
                local deb_internal_pkg
                deb_internal_pkg=$(dpkg-deb -f "$dest_path" Package 2>/dev/null || echo "")

                if [ -n "$deb_internal_ver" ] && [ "$deb_internal_ver" != "$pkg_version" ]; then
                    echo -e "${YELLOW}⚙️  Syncing internal DEBIAN/control Version ($deb_internal_ver -> $pkg_version)...${NC}"
                    local tmp_deb_dir
                    tmp_deb_dir=$(mktemp -d)
                    dpkg-deb -R "$dest_path" "$tmp_deb_dir/pkg" >/dev/null 2>&1
                    if [ -f "$tmp_deb_dir/pkg/DEBIAN/control" ]; then
                        sed -i -E "s/^(Version:).*/\1 $pkg_version/" "$tmp_deb_dir/pkg/DEBIAN/control"
                        if [ -n "$pkg_name" ]; then
                            sed -i -E "s/^(Package:).*/\1 $pkg_name/" "$tmp_deb_dir/pkg/DEBIAN/control"
                        fi
                        dpkg-deb --root-owner-group -b "$tmp_deb_dir/pkg" "$dest_path" >/dev/null 2>&1
                        echo -e "${GREEN}   ✔ Internal package Version successfully synchronized to $pkg_version!${NC}"
                    fi
                    rm -rf "$tmp_deb_dir"
                fi
            fi
        fi
    fi

    # Clean up temp input file if it was a downloaded remote URL
    if [[ "$input_file" == /tmp/remote_pkg_* ]]; then
        rm -f "$input_file" 2>/dev/null || true
    fi

    # Compute checksums, size, and metadata for registry and package index
    local sha256
    sha256=$(python3 -c '
import os, hashlib, subprocess, tarfile, io, json, sys, datetime, re

reg_file = sys.argv[1]
dest_path = sys.argv[2]
name = sys.argv[3]
ver = sys.argv[4]
os_t = sys.argv[5]
fname = sys.argv[6]
fpath = sys.argv[7]
desc = sys.argv[8]
is_remote = sys.argv[9].lower() == "true"
remote_url = sys.argv[10]
orig_size = int(sys.argv[11]) if sys.argv[11].isdigit() else 0
orig_sha256 = sys.argv[12]

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
    "updated_at": now_iso,
    "is_remote": is_remote
}

if is_remote:
    pkg_entry["remote_url"] = remote_url
    pkg_entry["original_size"] = orig_size
    pkg_entry["original_sha256"] = orig_sha256
    mirrors = [u.strip() for u in re.split(r"[\s,;]+", remote_url) if u.strip()]
    pkg_entry["remote_mirrors"] = mirrors

if control_info:
    control_info = re.sub(r"(?m)^Version:\s*.*$", f"Version: {ver}", control_info)
    control_info = re.sub(r"(?m)^Package:\s*.*$", f"Package: {name}", control_info)
    pkg_entry["control_info"] = control_info

packages.append(pkg_entry)
data["packages"] = packages
data["updated_at"] = now_iso

with open(reg_file, "w") as f:
    json.dump(data, f, indent=2)

print(sha256)
' "$REGISTRY_FILE" "$dest_path" "$pkg_name" "$pkg_version" "$os_type" "$dest_filename" "$rel_path" "$pkg_desc" "$is_remote" "$remote_url" "$orig_size" "$orig_sha256")

    if [ "$os_type" == "debian" ]; then
        update_apt_repo
    fi

    # Safety check: strictly ensure NO file exceeding 100 MB exists in database/ before committing!
    echo -e "${BLUE}🛡️  Verifying database files for GitHub limits...${NC}"
    local oversized
    oversized=$(find "$DATABASE_DIR" -type f -size +100M 2>/dev/null || true)
    if [ -n "$oversized" ]; then
        echo -e "${RED}${BOLD}❌ ERROR: Found file(s) exceeding GitHub 100 MB limit in database/:${NC}"
        echo "$oversized"
        echo -e "${RED}Aborting commit to prevent GitHub push rejection!${NC}"
        exit 1
    fi
    echo -e "${GREEN}   ✔ All database files are strictly within GitHub's 100 MB limit!${NC}"

    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}🎉 SUCCESS! Package rolled out and indexed in database:${NC}"
    echo -e "   • Name:        ${BOLD}$pkg_name${NC}"
    echo -e "   • Version:     ${BOLD}$pkg_version${NC}"
    echo -e "   • Target OS:   ${BOLD}$os_type${NC}"
    if [ "$is_remote" == "true" ]; then
        local orig_mb
        orig_mb=$(python3 -c "import sys; print('{:.2f}'.format(float(sys.argv[1]) / (1024*1024)))" "$orig_size")
        echo -e "   • Mode:        ${CYAN}${BOLD}REMOTE PAYLOAD (>100MB)${NC}"
        echo -e "   • Remote URL:  ${CYAN}$remote_url${NC}"
        echo -e "   • Wrapper Deb: ${PURPLE}$rel_path ($(du -h "$dest_path" | cut -f1))${NC}"
        echo -e "   • Payload Size:${BOLD}$orig_mb MB${NC}"
        echo -e "   • Payload Hash:${PURPLE}$orig_sha256${NC}"
    else
        echo -e "   • Stored File: ${CYAN}$rel_path${NC}"
        echo -e "   • SHA256:      ${PURPLE}$sha256${NC}"
    fi
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}📦 Automatically staging, committing, and pushing to GitHub...${NC}"
    git config advice.updateSparsePath false 2>/dev/null || true
    git add --sparse database/
    git commit -m "feat: roll out $pkg_name v$pkg_version for $os_type" || true
    echo -e "${BLUE}🚀 Pushing package to GitHub...${NC}"
    if git push; then
        echo -e "${BLUE}🧹 Automatically cleaning local binary to free disk space...${NC}"
        git sparse-checkout set --no-cone '/*' '!database/*/*.deb' '!database/*/*.rpm' '!database/*/*.pkg.tar.zst' '!database/*/*.run' '!database/*/*.AppImage' 2>/dev/null || true
        echo ""
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}🎉 SUCCESS! Package '$pkg_name' is live on GitHub! ✨${NC}"
        echo -e "${GREEN}${BOLD}🧹 Local disk space cleaned: 0 MB wasted locally!${NC}"
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    else
        echo -e "${YELLOW}⚠️ Git push was not completed. You can push manually with: ${CYAN}git push${NC}"
    fi
    echo ""
}

# Interactive wizard
interactive_wizard() {
    print_banner
    echo -e "${BOLD}Welcome to the Interactive Package Upload & Rollout Wizard!${NC}\n"

    # Step 1: File location
    local input_file=""
    local remote_url=""

    while [ -z "$input_file" ]; do
        read -e -p "📁 Step 1/5: Please enter file location (path to package): " input_file
        input_file="${input_file/#\~/$HOME}"
        
        # Check if user entered a remote URL directly at step 1
        if [[ "$input_file" =~ ^https?:// ]] || [[ "$input_file" =~ ^mega\.(nz|co\.nz) ]] || [[ "$input_file" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            remote_url="$input_file"
            if [[ ! "$remote_url" =~ ^https?:// ]]; then
                if [[ "$remote_url" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                    remote_url="http://$remote_url"
                else
                    remote_url="https://$remote_url"
                fi
            fi
            echo -e "   ${BLUE}🌐 Remote download URL detected: ${BOLD}$remote_url${NC}"
            if [ -f "$SCRIPT_DIR/scripts/downloader.py" ]; then
                local prov
                prov=$(python3 "$SCRIPT_DIR/scripts/downloader.py" --info "$remote_url" 2>/dev/null | grep "Provider:" | cut -d: -f2- | xargs)
                if [ -n "$prov" ]; then
                    echo -e "   ${GREEN}✔ Recognized Provider: ${BOLD}$prov${NC}"
                fi
            fi
            local tmp_fetch
            tmp_fetch=$(mktemp /tmp/remote_pkg_XXXXXX)
            echo -e "   ${BLUE}⏳ Fetching package from remote host to analyze metadata...${NC}"
            if python3 "$SCRIPT_DIR/scripts/downloader.py" "$remote_url" -o "$tmp_fetch"; then
                input_file="$tmp_fetch"
            else
                echo -e "${RED}   Failed to fetch package from '$remote_url'. Check URL, network, or permissions.${NC}"
                input_file=""
                remote_url=""
                continue
            fi
        elif [ ! -f "$input_file" ]; then
            echo -e "${RED}   File '$input_file' not found! Please enter a valid path.${NC}"
            input_file=""
        else
            # Check local file size against GitHub 100 MB limit
            local f_size
            f_size=$(stat -c%s "$input_file" 2>/dev/null || wc -c < "$input_file")
            local max_allowed=$((100 * 1024 * 1024)) # 100 MB
            
            if [ "$f_size" -gt "$max_allowed" ]; then
                local f_size_mb
                f_size_mb=$(python3 -c "import sys; print('{:.2f}'.format(float(sys.argv[1]) / (1024*1024)))" "$f_size")
                echo ""
                echo -e "   ${YELLOW}${BOLD}⚠️  LARGE PACKAGE DETECTED (${f_size_mb} MB):${NC}"
                echo -e "   ${YELLOW}GitHub strictly limits git files to ${BOLD}100 MB${NC}${YELLOW}. Large binaries cannot be stored directly in Git.${NC}"
                echo -e "   ${CYAN}${BOLD}Supported Remote Hosting Providers & Locations:${NC}"
                echo -e "     • ${GREEN}Google Drive:${NC}          https://drive.google.com/file/d/<id>/view"
                echo -e "     • ${GREEN}Mega.nz:${NC}               https://mega.nz/file/<id>#<key>"
                echo -e "     • ${GREEN}Direct IP / Web Host:${NC}  http://192.168.1.100:8080/repo/app.deb"
                echo -e "     • ${GREEN}DuckDNS / Apache:${NC}      https://jharkhand.duckdns.org/repo/app.deb"
                echo -e "     • ${GREEN}GitHub Releases:${NC}       https://github.com/<user>/<repo>/releases/download/v1.0/app.deb"
                echo -e "     • ${GREEN}TeraBox & Mirrors:${NC}     https://terabox.com/s/<surl>"
                echo -e "     • ${GREEN}Dropbox / MediaFire:${NC}   https://www.dropbox.com/s/... | https://www.mediafire.com/file/..."
                echo -e "     • ${PURPLE}Multi-Mirror Failover:${NC} Enter multiple URLs separated by comma (,)"
                echo ""
                
                while [ -z "$remote_url" ]; do
                    read -p "🌐 Enter remote download URL(s): " remote_url
                    remote_url=$(echo "$remote_url" | xargs)
                    if [ -z "$remote_url" ]; then
                        echo -e "${RED}   Remote URL is required for packages larger than 100 MB!${NC}"
                    else
                        remote_url=$(python3 -c '
import sys, re
raw = sys.argv[1]
items = [u.strip() for u in re.split(r"[\s,;]+", raw) if u.strip()]
norm = []
for u in items:
    if not re.match(r"^https?://", u):
        if re.match(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}", u):
            norm.append("http://" + u)
        else:
            norm.append("https://" + u)
    else:
        norm.append(u)
print(", ".join(norm))
' "$remote_url")
                        echo -e "   ${BLUE}Configured URL -> ${BOLD}$remote_url${NC}"
                        if [ -f "$SCRIPT_DIR/scripts/downloader.py" ]; then
                            python3 "$SCRIPT_DIR/scripts/downloader.py" --info $remote_url 2>/dev/null | grep "Provider:" | while read -r line; do
                                echo -e "   ${GREEN}✔ $line${NC}"
                            done
                        fi
                    fi
                done
            fi
        fi
    done

    # Auto-detect file attributes
    local base_fname=$(basename "$input_file")
    local ext="${base_fname##*.}"
    local detected_os=""
    local detected_name=""
    local detected_ver=""
    local detected_desc=""

    case "$ext" in
        deb)
            detected_os="debian"
            if command -v dpkg-deb >/dev/null 2>&1; then
                detected_name=$(dpkg-deb -f "$input_file" Package 2>/dev/null || echo "")
                detected_ver=$(dpkg-deb -f "$input_file" Version 2>/dev/null || echo "")
                detected_desc=$(dpkg-deb -f "$input_file" Description 2>/dev/null | head -n 1 || echo "")
            fi
            ;;
        rpm)
            detected_os="fedora"
            if command -v rpm >/dev/null 2>&1; then
                detected_name=$(rpm -qp --qf "%{NAME}" "$input_file" 2>/dev/null || echo "")
                detected_ver=$(rpm -qp --qf "%{VERSION}" "$input_file" 2>/dev/null || echo "")
                detected_desc=$(rpm -qp --qf "%{SUMMARY}" "$input_file" 2>/dev/null || echo "")
            fi
            ;;
        zst|xz)
            if [[ "$base_fname" == *".pkg.tar."* ]]; then
                detected_os="arch"
            fi
            ;;
        AppImage|run|bin)
            detected_os="universal"
            ;;
    esac

    # Filename fallback for name & version
    local file_name_guess=$(echo "$base_fname" | cut -d_ -f1 | cut -d- -f1)
    local file_ver_guess=$(echo "$base_fname" | grep -oP '(?<=_)[0-9]+(\.[0-9]+)+([a-zA-Z0-9.-]*)' | head -n 1 || echo "")

    local default_name="${detected_name:-$file_name_guess}"
    local default_ver="${detected_ver:-$file_ver_guess}"
    default_ver="${default_ver:-1.0.0}"

    # If filename has a different version than internal control, inform the user!
    if [ -n "$file_ver_guess" ] && [ -n "$detected_ver" ] && [ "$file_ver_guess" != "$detected_ver" ]; then
        echo -e "   ${YELLOW}ℹ️  Notice: Package internal DEBIAN/control has Version '${BOLD}$detected_ver${NC}${YELLOW}', but filename indicates '${BOLD}$file_ver_guess${NC}${YELLOW}'.${NC}"
        default_ver="$file_ver_guess"
    fi

    # Step 2: Package Name
    local pkg_name=""
    while [ -z "$pkg_name" ]; do
        if [ -n "$default_name" ]; then
            read -p "📦 Step 2/5: Enter package name [$default_name]: " pkg_name
            pkg_name="${pkg_name:-$default_name}"
        else
            read -p "📦 Step 2/5: Enter package name (e.g. omen-gaming-hub): " pkg_name
        fi
        pkg_name=$(echo "$pkg_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._-')
        if [ -z "$pkg_name" ]; then
            echo -e "${RED}   Package name is required! (letters, numbers, dashes, dots)${NC}"
        fi
    done

    # Step 3: Version
    local pkg_version=""
    while [ -z "$pkg_version" ]; do
        if [ -n "$default_ver" ]; then
            read -p "🔖 Step 3/5: Enter package version [$default_ver]: " pkg_version
            pkg_version="${pkg_version:-$default_ver}"
        else
            read -p "🔖 Step 3/5: Enter package version (e.g. 1.0.0): " pkg_version
        fi
        if [ -z "$pkg_version" ]; then
            echo -e "${RED}   Version is required!${NC}"
        fi
    done

    # Step 4: Target OS
    echo ""
    local os_type=""
    if [ -n "$detected_os" ]; then
        echo -e "${BLUE}${BOLD}🐧 Step 4/5: Target Distribution auto-detected: ${GREEN}$detected_os${NC}"
        echo "   1) Ubuntu / Kali / Debian / Linux Mint / Pop!_OS (.deb)"
        echo "   2) Fedora / RHEL / CentOS / Rocky Linux (.rpm)"
        echo "   3) Arch Linux / Manjaro / EndeavourOS (.pkg.tar.zst)"
        echo "   4) Universal (AppImage / Standalone Binary / Script - works on ALL distros)"
        
        local default_os_num=1
        case "$detected_os" in
            debian) default_os_num=1 ;;
            fedora) default_os_num=2 ;;
            arch) default_os_num=3 ;;
            universal) default_os_num=4 ;;
        esac

        read -p "   Confirm target OS option [$default_os_num]: " os_choice
        os_choice="${os_choice:-$default_os_num}"
        case "$os_choice" in
            1) os_type="debian" ;;
            2) os_type="fedora" ;;
            3) os_type="arch" ;;
            4) os_type="universal" ;;
            *) os_type="$detected_os" ;;
        esac
    else
        echo -e "${BLUE}${BOLD}🐧 Step 4/5: Select Target Linux Distribution / Type:${NC}"
        echo "   1) Ubuntu / Kali / Debian / Linux Mint / Pop!_OS (.deb)"
        echo "   2) Fedora / RHEL / CentOS / Rocky Linux (.rpm)"
        echo "   3) Arch Linux / Manjaro / EndeavourOS (.pkg.tar.zst)"
        echo "   4) Universal (AppImage / Standalone Binary / Script - works on ALL distros)"
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
    fi

    # Step 5: Description
    echo ""
    local default_desc="${detected_desc:-$pkg_name package for Linux}"
    read -p "📝 Step 5/5: Enter short description [$default_desc]: " pkg_desc
    pkg_desc="${pkg_desc:-$default_desc}"

    echo ""
    process_upload "$input_file" "$pkg_name" "$pkg_version" "$os_type" "$pkg_desc" "false" "$remote_url"
}

# CLI Argument parsing
CLI_FILE=""
CLI_NAME=""
CLI_VER=""
CLI_OS=""
CLI_DESC=""
CLI_REMOTE_URL=""
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
        -m|--remote-url)
            shift
            CLI_REMOTE_URL="$1"
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
    # Check if CLI_FILE is a remote URL
    if [[ "$CLI_FILE" =~ ^https?:// ]] || [[ "$CLI_FILE" =~ ^mega\.(nz|co\.nz) ]] || [[ "$CLI_FILE" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        if [ -z "$CLI_REMOTE_URL" ]; then
            CLI_REMOTE_URL="$CLI_FILE"
        fi
        echo -e "${BLUE}🌐 Remote package URL provided via CLI: ${BOLD}$CLI_FILE${NC}"
        tmp_cli_fetch=$(mktemp /tmp/remote_pkg_XXXXXX)
        echo -e "${BLUE}⏳ Downloading package to inspect and index metadata...${NC}"
        if python3 "$SCRIPT_DIR/scripts/downloader.py" "$CLI_FILE" -o "$tmp_cli_fetch"; then
            CLI_FILE="$tmp_cli_fetch"
        else
            echo -e "${RED}❌ Failed to fetch remote package: $CLI_FILE${NC}"
            exit 1
        fi
    fi
    process_upload "$CLI_FILE" "$CLI_NAME" "$CLI_VER" "$CLI_OS" "$CLI_DESC" "$CLI_FORCE" "$CLI_REMOTE_URL"
else
    echo -e "${RED}Missing required parameters for CLI upload.${NC}"
    echo "Usage: ./upload.sh -f <file|url> -n <name> -v <version> -o <debian|fedora|arch|universal> [-m <remote_url>]"
    echo "Or run './upload.sh -u' for the interactive wizard."
    exit 1
fi

