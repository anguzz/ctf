 Login Panel

 ```
100
31 (72% liked) 12

login
https://tommytheduck.github.io/login 

```



I went to the login page and tried some simple xss payloads, none worked so decided to curl the site and see what it would return.

```bash
angus@angusMintDev:~$ curl https://tommytheduck.github.io/login/
```

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Login Panel</title>
</head>
<body>
  <script>
    async function toHex(buffer) {
      const bytes = new Uint8Array(buffer);
      let hex = '';
      for (let i = 0; i < bytes.length; i++) {
        hex += bytes[i].toString(16).padStart(2, '0');
      }
      return hex;
    }

    async function sha256Hex(str) {
      const enc = new TextEncoder();
      const data = enc.encode(str);
      const digest = await crypto.subtle.digest('SHA-256', data);
      return toHex(digest);
    }

    function timingSafeEqualHex(a, b) {
      if (a.length !== b.length) return false;
      let diff = 0;
      for (let i = 0; i < a.length; i++) {
        diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
      }
      return diff === 0;
    }

    (async () => {
      const ajnsdjkamsf = 'ba773c013e5c07e8831bdb2f1cee06f349ea1da550ef4766f5e7f7ec842d836e'; // replace
      const lanfffiewnu = '48d2a5bbcf422ccd1b69e2a82fb90bafb52384953e77e304bef856084be052b6'; // replace

      const username = prompt('Enter username:');
      const password = prompt('Enter password:');

      if (username === null || password === null) {
        alert('Missing username or password');
        return;
      }

      const uHash = await sha256Hex(username);
      const pHash = await sha256Hex(password);

      if (timingSafeEqualHex(uHash, ajnsdjkamsf) && timingSafeEqualHex(pHash, lanfffiewnu)) {
        alert(username+ '{'+password+'}');
      } else {
        alert('Invalid credentials');
      }
    })();
  </script>
</body>
angus@angusMintDev:~$ 
```

The hashes stuck out to me since they were hardcoded values so I put them in crackstation.net

```
Hash	Type	Result
ba773c013e5c07e8831bdb2f1cee06f349ea1da550ef4766f5e7f7ec842d836e	sha256	v1t
48d2a5bbcf422ccd1b69e2a82fb90bafb52384953e77e304bef856084be052b6	sha256	p4ssw0rd
```

The flag ended up being the login. 

# Flag 
`v1t{p4ssw0rd}`