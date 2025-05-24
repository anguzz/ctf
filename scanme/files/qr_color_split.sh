
# --- CONFIGURATION: UPDATE HEX VALUES FOR YOUR IMAGE ---
PURPLE="#5C005C"  # Finder patterns
RED="#FF0000"     # Data color 1
BLUE="#0000FF"    # Data color 2
FUZZ="15%"        # Fuzziness for color matching
DATA="black"
BG="white"
INPUT="qr1.png"

# --- check imageMagick install---
if ! command -v convert &>/dev/null; then
    echo "[!] ImageMagick not found. Installing..."
    for mgr in apt-get yum dnf pacman zypper; do
        if command -v $mgr &>/dev/null; then
            sudo $mgr install -y imagemagick && break
        fi
    done
    command -v convert &>/dev/null || { echo "Install failed. Please install ImageMagick manually."; exit 1; }
fi

[ -f "$INPUT" ] || { echo "Missing $INPUT. Place it in the current directory."; exit 1; }

echo "[*] Processing QR variants..."

convert "$INPUT" -fuzz $FUZZ -fill $DATA -opaque "$PURPLE" -fill $DATA -opaque "$RED" -fill $BG -opaque "$BLUE" qr_red_is_data.png

convert "$INPUT" -fuzz $FUZZ -fill $DATA -opaque "$PURPLE" -fill $DATA -opaque "$BLUE" -fill $BG -opaque "$RED" qr_blue_is_data.png

convert "$INPUT" -fuzz $FUZZ -fill $DATA -opaque "$PURPLE" -fill $DATA -opaque "$RED" -fill $DATA -opaque "$BLUE" qr_both_red_blue_is_data.png

echo "[+] Done. Try scanning:"
echo "- qr_red_is_data.png"
echo "- qr_blue_is_data.png"
echo "- qr_both_red_blue_is_data.png"

