#!/bin/sh
set -e

# ==============================================================================
# Fix script for currently installed burpsuite-pro package on local system
# Cleans corrupted /var/lib/dpkg/info/burpsuite-pro.list and updates postrm
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Error: This script must be run as root (use sudo)." >&2
    exit 1
fi

echo "[*] Cleaning /var/lib/dpkg/info/burpsuite-pro.list..."
LIST_FILE="/var/lib/dpkg/info/burpsuite-pro.list"

if [ -f "$LIST_FILE" ]; then
    TMP_LIST=$(mktemp)
    
    # Strip trailing slashes, remove root / and /.
    sed -e 's/\/$//' "$LIST_FILE" | grep -v -E '^(\/|\/\.)$' | grep -v '^$' > "$TMP_LIST"

    # Remove generic base system directories
    grep -v -E '^/(bin|boot|dev|etc|lib|lib32|lib64|media|mnt|opt|proc|root|run|sbin|srv|sys|tmp|usr|usr/bin|usr/sbin|usr/lib|usr/share|usr/share/applications|usr/share/icons|usr/share/pixmaps|var)$' "$TMP_LIST" | sort -u > "$LIST_FILE"
    
    rm -f "$TMP_LIST"
    echo "[✔] DPKG list file cleaned successfully!"
fi

echo "[*] Updating /var/lib/dpkg/info/burpsuite-pro.postrm for complete uninstallation..."
cat << 'EOF' > /var/lib/dpkg/info/burpsuite-pro.postrm
#!/bin/sh
set -e

clean_user_data() {
    target_dir="$1"
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir/.java/.userPrefs/burp" 2>/dev/null || true
        rm -rf "$target_dir/.BurpSuite" 2>/dev/null || true
        rm -rf "$target_dir/.burpsuite-pro" 2>/dev/null || true
        rm -f "$target_dir/.config.ini" 2>/dev/null || true
        rm -rf "$target_dir/.local/share/burpsuite-pro" 2>/dev/null || true
        rm -rf "$target_dir/.config/burpsuite-pro" 2>/dev/null || true
    fi
}

case "$1" in
    remove|purge)
        rm -rf /usr/share/burpsuite-pro 2>/dev/null || true
        rm -rf /usr/lib/repo-helper/burpsuite-pro 2>/dev/null || true
        rm -f /usr/bin/burpsuite-pro /bin/burpsuite-pro /usr/bin/burpsuitepro /bin/burpsuitepro 2>/dev/null || true
        rm -f /usr/share/applications/burpsuite-pro.desktop /usr/share/applications/burpsuite-pro-keygen.desktop 2>/dev/null || true
        rm -f /usr/share/pixmaps/burpsuite-pro.png 2>/dev/null || true
        rm -f /usr/share/icons/hicolor/*/apps/burpsuite-pro.png 2>/dev/null || true
        rm -f /var/cache/repo-helper/burpsuite-pro*.deb* 2>/dev/null || true

        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true
        fi
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database -q /usr/share/applications 2>/dev/null || true
        fi

        if [ "$1" = "purge" ]; then
            for u_home in /home/*; do
                clean_user_data "$u_home"
            done
            clean_user_data "/root"
            if [ -n "$SUDO_USER" ]; then
                s_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
                if [ -n "$s_home" ] && [ -d "$s_home" ]; then
                    clean_user_data "$s_home"
                fi
            fi
        fi
        ;;

    upgrade|failed-upgrade|abort-install|abort-upgrade|disappear)
        ;;
esac

exit 0
EOF
chmod 755 /var/lib/dpkg/info/burpsuite-pro.postrm

echo "[✔] Burp Suite Pro system configuration and uninstaller repaired!"
echo "[*] Now 'sudo apt remove burpsuite-pro', 'sudo apt update', and 'sudo apt full-upgrade' will work cleanly."
