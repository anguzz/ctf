# Overview

```
My grandma is struggling to remember the Wi-Fi password, but is also very paranoid. She saved her Wi-Fi password in this encrypted file, but she can't remember the encryption key. So she asked for my help. All that she told me is that the key used for encryption is a weak one and has the following hash: "3fc0a7acf087f549ac2b266baf94b8b1" (Funny she remembered the hash).
```

We have a file `password.txt.enc` and a hash so I wanted to check if the hash could be decrypted or had a known password. 

I threw the hash to https://hashes.com/en/decrypt/hash and found `3fc0a7acf087f549ac2b266baf94b8b1:qwerty123`

With `qwerty123` we could decrypt the password to her wifi in the text file. I tried to do this using aes decryption and

```bash
angus@aLT:~/Documents/GitHub/ctf/Defcon-2025/HackMyHomeNet/challenges/what_is_wifi_pw$ openssl enc -d -aes-256-cbc -md md5 -in password.txt.enc -out password.txt -pass pass:qwerty123
*** WARNING : deprecated key derivation used.
Using -iter or -pbkdf2 would be better.
bad decrypt
4057079D017C0000:error:1C800064:Provider routines:ossl_cipher_unpadblock:bad decrypt:../providers/implementations/ciphers/ciphercommon_block.c:124:
```


I got a bad decrypt so that was incorrect. I grabbed the hint and it said to 
`Try common decryption algorithms :)` 

At this point I just threw a few common decryption algorithsm in `decyrpt.sh` and ran it.

decrypt.sh does the following

1. First for loop picks a cipher
2. Second for loop picks a hash algorithm
3. Runs openssl enc -d with both choices and our known password `qwerty123`
4. If decryption works (exit status 0), prints the success message, creates file, and stops.
5. If not keeps tryin

It's a nested loop brute-force: N ciphers × M hasalgoh algo.

```bash
angus@aLT:~/Documents/GitHub/ctf/Defcon-2025/HackMyHomeNet/what_is_wifi_pw$ bash decrypt.sh 
Trying aes-256-cbc with md5...
Trying aes-256-cbc with sha1...
Trying aes-256-cbc with sha256...
Trying aes-192-cbc with md5...
Trying aes-192-cbc with sha1...
Trying aes-192-cbc with sha256...
Trying aes-128-cbc with md5...
Trying aes-128-cbc with sha1...
Trying aes-128-cbc with sha256...
[SUCCESS] aes-128-cbc sha256
ctfDeFCon25!
```


# Flag
`ctfbd{ctfDeFCon25!}`