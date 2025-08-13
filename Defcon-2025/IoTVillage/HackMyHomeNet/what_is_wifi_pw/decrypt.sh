for algo in aes-256-cbc aes-192-cbc aes-128-cbc des3 bf-cbc rc4; do
  for hash in md5 sha1 sha256; do
    echo "Trying $algo with $hash..."
    if openssl enc -d -$algo -md $hash -in password.txt.enc -out password.txt -pass pass:qwerty123 2>/dev/null; then
      echo "[SUCCESS] $algo $hash"
      cat password.txt
      exit
    fi
  done
done
sleep 10
