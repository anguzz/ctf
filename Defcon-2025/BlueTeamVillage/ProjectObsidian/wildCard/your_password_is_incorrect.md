
# Overview
```
 Your Password Is Incorrect
300
password

You're a security analyst at POTATO PETE LLC investigating a potential password breach.

Your mission: Crack the password hashes and analyze compliance with the company's password policy.

Company Password Policy:

    Minimum 8 characters
    Must contain uppercase, lowercase, numbers, and special characters
    No common words, usernames, or company names
    No sequential characters (123, abc, etc.)

Some of these passwords are so weak, they're practically begging to be cracked. Others... well, let's just say someone actually read the security policy.

You'll need to find your own wordlist - just like in real investigations!

Flag format: btv{weakestpassword_strongestuser}

Example: If weakest password is "password" and strongest user is "elmo": btv{password_elmo}

Need help? Check the hints or ask in Discord!

Good luck, defender! 🔐

Flag format is btv{....}


View Hint

Start by identifying the hash types in hashes.txt. MD5 hashes are 32 characters, SHA1 are 40 characters, SHA256 are 64 characters, and bcrypt starts with $2a$12$.
View Hint

For password cracking, you can use online tools for simple hashes or download tools like hashcat. Try common wordlists like rockyou.txt - it contains millions of real passwords.
View Hint

Some hashes might be from common passwords like "password", "123456", "admin". Check if any usernames appear in the wordlist. Look for patterns: username + "123", username + "!", etc.
```


# Hashes Text
```
POTATO PETE LLC - PASSWORD HASH DATABASE
=========================================

Format: username:hash_type:hash_value

jsmith:MD5:258752c6b0652a69c52ceed3c65dbf00
mjones:MD5:7ec34a103ee9aac2759e17d7beac3c3e
rwilson:SHA1:b863c49eada14e3a8816220a7ab7054c28693664
akumar:SHA1:18894f1267c3c76dd205481258c7d8df23cd0097
lchen:SHA256:7479396390a7de70f8ee7b6b218fdc0c87dda468ca555444fe594cc15655391c
tnguyen:SHA256:324ca5355e9d7d5f60fb23b379f5bad7d4a12013a8b89b46ec2392c3021d3a27
sbrown:SHA256:8de33123f9ba573b37066a867067e50db5c15784fa68b0e9dcd2b6492eaec3aa
dgarcia:bcrypt:$2b$12$zTKBFu8kr81cE3Zwooq86uvHL9K5aQbhWG2vWb6WJiprFRDzaDy5a
mpatel:bcrypt:$2b$12$v3KmuhSfIN/lkLKNoAVZa.51BnDrMoHOMXg53UX4adKtUg.W5CsgS
jlee:bcrypt:$2b$12$ARXbbnsTHFBzx0uWmEejkuYSDFJdHDkaewWAO1aIOY7ni/cDDD81C

HASH TYPES USED:
---------------
MD5: 32 characters, hexadecimal
SHA1: 40 characters, hexadecimal  
SHA256: 64 characters, hexadecimal
bcrypt: Starts with $2a$12$, 60 characters total

NOTES:
------
- Hashes were extracted during security audit
- Some users may have changed passwords since extraction
- Hash types vary based on system requirements
- All hashes are from active user accounts
- Extraction date: 2024-03-15 14:30:00 UTC 
```

# Cracking output

```
angus@aLT:~/Documents/GitHub/ctf/Defcon-2025/BlueTeamVillage/ProjectObsidian/wildCard/files$ bash decrypt.sh
[*] Cracking mode 0...
258752c6b0652a69c52ceed3c65dbf00:mittens
7ec34a103ee9aac2759e17d7beac3c3e:pinkgirl
[*] Cracking mode 100...
b863c49eada14e3a8816220a7ab7054c28693664:summertime
18894f1267c3c76dd205481258c7d8df23cd0097:softball3
[*] Cracking mode 1400...
7479396390a7de70f8ee7b6b218                                           fdc0c87dda468ca555444fe594cc15655391c:gregory1
8de33123f9ba573b37066a867067e50db5c15784fa68b0e9dcd2b6492eaec3aa:almendra
324ca5355e9d7d5f60fb23b379f5bad7d4a12013a8b89b46ec2392c3021d3a27:santi
[*] Cracking mode 3200...
```

It got stuck at on the bcrypt hashes at the end.
