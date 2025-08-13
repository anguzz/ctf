#!/bin/bash
WORDLIST="./rockyou.txt"
HASHFILE="./hashes.txt"
OUTPUT="decrypted_hashes.txt"

# Temp files
MD5_FILE=$(mktemp)
SHA1_FILE=$(mktemp)
SHA256_FILE=$(mktemp)
BCRYPT_FILE=$(mktemp)

declare -A MAP

# Split hashes by type
while IFS=: read -r user type hash; do
    MAP[$hash]="$user:$type:$hash"
    case "$type" in
        MD5) echo "$hash" >> $MD5_FILE ;;
        SHA1) echo "$hash" >> $SHA1_FILE ;;
        SHA256) echo "$hash" >> $SHA256_FILE ;;
        bcrypt) echo "$hash" >> $BCRYPT_FILE ;;
    esac
done < "$HASHFILE"

# Crack & output
crack_and_output() {
    local mode=$1
    local file=$2
    if [ -s "$file" ]; then
        echo "[*] Cracking mode $mode..."
        hashcat -m $mode "$file" "$WORDLIST" --quiet
        hashcat -m $mode "$file" "$WORDLIST" --show --quiet | while IFS=: read -r hash pass; do
            echo "${MAP[$hash]}:$pass" >> "$OUTPUT"
        done
    fi
}

> "$OUTPUT"

crack_and_output 0    "$MD5_FILE"
crack_and_output 100  "$SHA1_FILE"
crack_and_output 1400 "$SHA256_FILE"
crack_and_output 3200 "$BCRYPT_FILE"

rm -f "$MD5_FILE" "$SHA1_FILE" "$SHA256_FILE" "$BCRYPT_FILE"

echo "[+] Results saved to $OUTPUT"
