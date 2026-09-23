#!/usr/bin/env bash
# Helper script to generate a sample mock package for testing repository uploads and rollouts

set -e

VERSION="${1:-1.0.0}"
TEMP_BUILD="/tmp/omen_build_$VERSION"
rm -rf "$TEMP_BUILD"
mkdir -p "$TEMP_BUILD/usr/local/bin"

cat << 'EOF' > "$TEMP_BUILD/usr/local/bin/omen-gaming-hub"
#!/usr/bin/env bash
echo "╔═══════════════════════════════════════════════════════╗"
echo "║          HP OMEN GAMING HUB - LINUX EDITION           ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo "Status: Running smoothly! Performance Mode: Active."
EOF

chmod +x "$TEMP_BUILD/usr/local/bin/omen-gaming-hub"

# Build mock standalone universal binary / script
SAMPLE_DIR="./sample_packages"
mkdir -p "$SAMPLE_DIR"
cp "$TEMP_BUILD/usr/local/bin/omen-gaming-hub" "$SAMPLE_DIR/omen-gaming-hub_v$VERSION.run"
chmod +x "$SAMPLE_DIR/omen-gaming-hub_v$VERSION.run"

echo "✅ Created sample package: $SAMPLE_DIR/omen-gaming-hub_v$VERSION.run"
echo "You can test uploading it using:"
echo "  ./upload.sh -u"
echo "Or using flags:"
echo "  ./upload.sh -f $SAMPLE_DIR/omen-gaming-hub_v$VERSION.run -n omen-gaming-hub -v $VERSION -o universal -d 'HP Omen Gaming Hub tool for Linux'"
