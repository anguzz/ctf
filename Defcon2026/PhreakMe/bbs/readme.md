# Learning My First BBS Through the PhreakMe CTF

## Where I Started

When I opened the BBS challenge, I honestly did not know what a **BBS** was or how I was supposed to interact with one.

The challenge was listed as:

```text
BBS

Log On
50
+10% (first 2) (-5%/solve)

Just log on to the BBS, that's it. Pretty simple.
```

The description made it sound straightforward:

> Step back in time with our authentic Bulletin Board System experience. Dial (or SSH) in with your favorite ANSI terminal and explore message boards, file libraries, and door games just like the old days. ANSI art and 2400 baud nostalgia included at no extra charge!

The provided page was:

```text
https://phreakme.com/bbs
```

A friend in my group also sent me the SyncTERM download link because he said I would need it for the BBS challenges:

```text
https://sourceforge.net/projects/syncterm/files/latest/download
```

At that point, I did not know what SyncTERM was, what ANSI-BBS meant, or why I needed a special terminal application just to log in.

The web page opened a retro terminal and drew a lot of text and graphics. At first, it looked almost like some kind of virtual machine. I did not yet realize that it was ANSI art being rendered by a browser-based BBS client.


## The DEF CON Network Made It Frustrating

The main reason I kept disconnecting was the poor network connection at DEF CON.

I could sometimes get into the BBS and begin exploring, but the network would drop and the browser client would show:

```text
Disconnected from phreakme.com:11235
```

The frustrating part was not only the disconnect itself. Every reconnect meant logging in again, waiting for all the ANSI screens to redraw, navigating back through several menus, and trying to remember exactly where I had been.

The conference network was the main cause of the repeated disconnects, but the problem pushed me to understand how the BBS connection actually worked and eventually build a better way to record my progress.

## Figuring Out What the Web Page Was Doing

My first useful step was inspecting the page rather than continuing to fight the browser terminal.

I tried requesting the HTTP page:

```bash
curl phreakme.com/bbs
```

That returned an HTTP redirect.

I then requested the HTTPS version:

```bash
curl https://phreakme.com/bbs
```

The returned HTML showed that the page was loading **fTelnet**, a browser-based terminal client. It also exposed the BBS connection settings:

```javascript
Options.ConnectionType = 'telnet';
Options.Emulation = 'ansi-bbs';
Options.Font = 'CP437';
Options.Hostname = 'phreakme.com';
Options.Port = 11235;
Options.ScreenColumns = 80;
Options.ScreenRows = 25;
```

From that, I learned that the BBS expected:

- ANSI-BBS terminal emulation
- CP437 character encoding
- An 80-by-25 terminal
- A connection associated with port `11235`

The web page was not simulating a fake computer,it was acting as a client for a real Synchronet BBS.

## Trying to Connect Directly

Once I knew the host and port, I tried treating it like a normal Telnet service:

```bash
telnet phreakme.com 11235
```

The TCP connection opened:

```text
Trying 23.95.47.254...
Connected to phreakme.com.
Escape character is '^]'.
```

However, when I entered text, the server returned an HTTP response instead of a BBS prompt:

```text
HTTP/1.1 400 Bad Request
Server: nginx/1.29.8
Connection: close
```

I also tested the port with Netcat:

```bash
nc phreakme.com 11235
```

This confirmed that simply opening a raw TCP or Telnet session to the public port was not enough.

The public-facing service was expecting a **WebSocket handshake** through nginx before carrying the BBS traffic.

## Capturing the WebSocket Details

To understand what the browser client was doing differently, I opened the browser's network tools, filtered for WebSocket traffic, and saved a HAR capture.

The HAR confirmed the required connection:

```text
URL:         wss://phreakme.com:11235/
Origin:      https://phreakme.com
Subprotocol: binary
Status:      101 Switching Protocols
```

The `101 Switching Protocols` response meant the WebSocket upgrade succeeded.

This explained the earlier result:

```
Raw Telnet to phreakme.com:11235 > nginx expects a WebSocket handshake > HTTP 400 Bad Request
```

The browser based fTelnet client performed the WebSocket handshake first and then carried the BBS traffic through the upgraded connection.

## Installing and Using `websocat`

I installed `websocat` so I could reproduce the browser's WebSocket connection locally.

```bash
sudo apt update
sudo apt install -y curl

curl -fL \
  https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl \
  -o /tmp/websocat

sudo install -m 0755 /tmp/websocat /usr/local/bin/websocat
```

I verified the installation with:

```bash
websocat --version
```

I then created a local TCP listener and bridged it to the required remote WebSocket:

```bash
websocat -v -E -b \
  --origin='https://phreakme.com' \
  --protocol='binary' \
  tcp-l:127.0.0.1:2323 \
  wss://phreakme.com:11235/
```

The output confirmed that the WebSocket upgrade worked:

```text
Connected to ws
Connection: upgrade
Upgrade: websocket
Sec-WebSocket-Protocol: binary
```

The connection path was now:

```text
Local terminal client
        |
        | Telnet-style connection
        v
127.0.0.1:2323
        |
        | websocat bridge
        v
wss://phreakme.com:11235/
        |
        v
PhreakMe Synchronet BBS

```

## Reaching the BBS but Getting Expunged

After starting the bridge, I connected locally:

```bash
telnet 127.0.0.1 2323
```

This time I actually reached the Synchronet server:

```bash
Redirecting to server...

Synchronet BBS for Linux Version 3.22
Telnet connection from: 127.0.0.1
Resolving hostname...
```

That proved that the WebSocket bridge was working.

The server then rejected my normal terminal:

```bash
Only ANSI CP437 terminals are allowed, lamer.

Charset: UTF-8
YOU ARE EXPUNGED
Connection closed by foreign host.
```

Some related ascii art I later found calling this out.

<img width="863" height="690" alt="Screenshot from 2026-08-07 20-40-07" src="https://github.com/user-attachments/assets/b974ba0a-1f34-43b0-9228-36e86cb16bff" />


The BBS appeared to be deliberately enforcing the use of an ANSI/CP437-capable terminal. This was not only a visual preference. It detected my UTF-8 terminal and disconnected me.

I had reproduced the correct network transport, but ordinary `telnet` still did not behave like the terminal that the challenge creators expected.

## Learning About SyncTERM

The practical answer was **SyncTERM**.

SyncTERM is designed for old school BBS systems and supports the ANSI BBS and CP437 behavior that this server appeared to enforce.

I downloaded it from:

```text
https://sourceforge.net/projects/syncterm/files/latest/download
```

Downloading it over the slow DEF CON network took a while, like half an hour. The Linux download was source code rather than a simple installer, so I then had to compile it and install before I could even begin solving the actual challenge.

I did not preserve the exact shell history, but the build steps I remember were something like:

```bash
sudo apt update
sudo apt install -y build-essential libncurses-dev libsdl2-dev

tar -xzf syncterm-*-src.tgz
cd syncterm-*/src/syncterm

SRC_ROOT=$(cd .. && pwd) make
sudo make install
```

The exact extracted directory name depended on the version that SourceForge downloaded. The important part was entering the extracted project's `src/syncterm` directory, compiling it with `make`, and then installing the resulting program.

After the compilation finished, I could launch it from the terminal:

```bash
syncterm
```

Once SyncTERM opened, I was placed in its address book. I then:

1. Pressed `Insert` to create a new BBS entry.
2. Gave the entry a recognizable name.
3. Selected `Telnet` as the connection type.
4. Entered `127.0.0.1` as the address.
5. Entered `2323` as the port, which connects to `127.0.0.1:2323`.
6. Set the terminal to ANSI-BBS/CP437.
7. Saved the entry, selected it, and pressed `Enter` to connect.


That would send raw Telnet negotiation to nginx instead of performing the required WebSocket handshake, producing the same `400 Bad Request` response.

Instead, I kept the `websocat` bridge running in one terminal window:

```bash
websocat -v -E -b \
  --origin='https://phreakme.com' \
  --protocol='binary' \
  tcp-l:127.0.0.1:2323 \
  wss://phreakme.com:11235/
```

I then launched SyncTERM in another terminal and connected it to the local listener:

```text
Connection type: Telnet
Address:         127.0.0.1
Port:            2323
Terminal:        ANSI-BBS
Encoding:        CP437
Screen size:     80x25
```

In other words, SyncTERM was dialing `127.0.0.1:2323`. That local port was not the BBS itself. It was the local side of the `websocat` bridge, which then performed the actual WebSocket connection to the PhreakMe server.


> **Note added later:** After I'd already gotten both flags, I realized I probably didn't need the `websocat` bridge at all. SyncTERM's "Connection Type" field isn't limited to Telnet. It also supports SSH, RLogin, and raw TCP connections, and Synchronet's own terminal server natively speaks Telnet, RLogin, SSH, and raw TCP as well. If `phreakme.com` exposed an SSH-based BBS port, SyncTERM could likely have connected to it directly, with no WebSocket handshake involved, since the WS-only requirement I ran into was specific to nginx on port 11235, not necessarily every port on the box. I never went back to test this against phreakme.com specifically, so I can't say for certain it would have worked, but it's the first thing I'd try next time before building out a bridge. 

The complete working path was:


```text
SyncTERM
   |
   | ANSI-BBS / CP437 over local Telnet
   v
127.0.0.1:2323
   |
   | websocat
   v
wss://phreakme.com:11235/
   |
   v
PhreakMe BBS
```
<img width="1920" height="1200" alt="Screenshot from 2026-08-07 15-33-51" src="https://github.com/user-attachments/assets/d755fb3a-8fd3-4a1f-9795-3544590d73f0" />

When I selected the saved SyncTERM entry and pressed `Enter`, it successfully connected through `127.0.0.1:2323`, passed through the `websocat` bridge, and reached the PhreakMe BBS. The ANSI art finally rendered correctly, and the BBS stopped expunging me for using UTF-8.

There were therefore two practical ways for me to view the BBS:

1. The browser's built-in fTelnet client
2. SyncTERM through the local `websocat` bridge

This was also when I started to understand what a BBS actually was. Instead of a modern website with pages and buttons, it was a menu driven system containing:

- Message boards
- File libraries
- Door programs
- User accounts
- Online-user information
- Text and ANSI artwork


<img width="874" height="687" alt="Screenshot from 2026-08-07 20-38-04" src="https://github.com/user-attachments/assets/7dd3923a-cd86-4742-81f4-9fcb2f70bde5" />

<img width="874" height="687" alt="Screenshot from 2026-08-07 20-38-58" src="https://github.com/user-attachments/assets/3e0f2dec-0bbd-40e9-ae91-5b3515b6d12f" />

<img width="873" height="687" alt="Screenshot from 2026-08-07 22-34-55" src="https://github.com/user-attachments/assets/4e972c14-b394-4dce-afb6-97db4e29bedf" />


The web page was only one possible client. The real system was the Synchronet BBS behind it.

## Learning How to Navigate

Even after connecting successfully, I did not immediately know how to move around.

The interface relied heavily on single-letter commands, arrow keys, Enter, Space, and context specific help menus. I gradually learned how to:

- Open the message-board area
- Change message groups and sub-boards
- Read and search messages
- Switch between subject-only and full-body searches
- Open the file libraries
- Move between libraries and directories
- View file information
- Enter door programs
- Back out of nested menus without accidentally disconnecting

A useful discovery was that message searches could be limited to subjects. Broad searches often returned nothing in that mode. Searching full message bodies was much more useful.

The BBS also used older file transfer protocols. Its download menu offered:


```text
XMODEM
YMODEM
ZMODEM
```

<img width="851" height="667" alt="image" src="https://github.com/user-attachments/assets/8072fab6-db03-4f6f-bd46-25efee788083" />

<img width="1920" height="1200" alt="img1" src="https://github.com/user-attachments/assets/59226249-0bbe-4a5a-b9df-ad6905051558" />

I had the most success with **ZMODEM**, which SyncTERM could handle directly.

SyncTERM was therefore important for two things that my custom logging tool did not fully replace:

1. Correctly rendering and interacting with the BBS
2. Downloading files through ZMODEM

## Why I Built `bbs_recorder.py`

SyncTERM solved the terminal compatibility problem, but I still had a research problem.

The DEF CON network could drop at any time. When that happened, I had to reconnect, log in again, wait for screens to redraw, and navigate back to wherever I had been. There were also a lot of menus, messages, and files, so manually clicking through everything made it difficult to remember my path.

I wanted a way to preserve what I had already seen, search it afterward, and continue researching without depending entirely on a fragile live session.

My earlier direct Python WebSocket and TCP attempts were rejected or disconnected because they did not reproduce enough of the Telnet negotiation and terminal behavior expected by the BBS.

I created:

```text
bbs_recorder.py
```

The goal was not to completely replace SyncTERM. It was to reproduce enough of the working terminal behavior to let me browse while recording the session.

It was also useful for sharing the logs with an LLM or other team members for collaboration because I was completely out of my element with BBS software.

The program used a CP437 aware Telnet connection and identified itself like a BBS terminal. It saved every session into a timestamped folder:

```text
bbs-captures/
└── session-YYYYMMDD-HHMMSS/
    ├── ansi.log
    ├── clean.log
    └── events.jsonl
```

Each file served a different purpose:

- `ansi.log` preserved the raw terminal output, including ANSI control codes.
- `clean.log` removed most control sequences and produced searchable text.
- `events.jsonl` recorded connection events and the keys sent during the session.

I could run it with:

```bash
python3 bbs_recorder.py
```

Or automatically advance common pager prompts:

```bash
python3 bbs_recorder.py --auto-more
```

The recorder was especially helpful for:

- Looking back at screens I had already passed
- Searching message text with `grep`
- Keeping evidence of how I reached something
- Recording long file lists
- Comparing multiple sessions
- Avoiding the need to screenshot every screen

It was not perfect. BBS software constantly redraws an 80-by-25 screen using cursor movement, so the cleaned logs sometimes contained repeated or out-of-order-looking text. Still, searchable messy text was much better than having no record at all.

## Making the BBS Easier to Search

Once I had a reliable interactive client and a recorder, I started rapidly clicking through message boards and file libraries so that the recorder would capture as much visible information as possible.

I could then open `clean.log` in a code editor or search it from the command line:

```bash
grep -in "flag" clean.log
grep -in "found me" clean.log
grep -in "secret" clean.log
```

### The CSV File Came From a Friend

A friend on my team sent us phreakme_files_dump.csv. It contained a large list of the files visible in the BBS libraries, with fields such as:

```text
library
directory
filename
size
description
```

It did **not** contain the contents of those files.

That distinction mattered. The CSV was useful as an index because I could quickly search the filenames without manually browsing every directory.

However, finding a filename in the CSV did not give me the actual file. I still had to return to the live BBS in SyncTERM, navigate to the correct library and directory, and download the file through ZMODEM.

The two sources complemented each other:

- My recorder captured message text, menus, navigation, and whatever appeared on my screen in a clean ansi log.
- My friend's CSV provided a searchable inventory of BBS file listings.
- SyncTERM was still required to accurately interact with the BBS and retrieve the actual files.

## Solve 1: Something to prove

The challenge clue was:

> Ultra Lazer claims he hacked a Gibson and says he left evidence on the BBS in some sort of SECRET file.

The friend-provided CSV helped with filename enumeration because I could search its listings for words related to the clue. It only told me that a potentially relevant file existed; it did not contain the file itself.

I then had to:

1. Connect to the BBS through SyncTERM.
2. Navigate to the relevant file library.
3. Locate `secrets.xmi`.
4. Download it using ZMODEM.
5. Inspect the downloaded file locally.
6. Determine that it appeared to be an IBM XMI/XMIT-style container.
7. Open or extract the contents.
8. Examine the resulting files.

One of the extracted items was an email message with the subject:

```text
Password Policy Memo
```

The flag was not in the visible email body. It was stored in a custom message header:

```text
From: "Eugene Belford" <ebelfor@ellingson.com>
Subject: Password Policy Memo
Date: Wed, 13 Sep 1995 01:54:37 -0500
X-CTF-FLAG: phreakme{redacted}
User-Agent: Eudora 5.0
Content-Type: text/plain; charset=utf-8
```

The body was a password-policy memo warning the executive team not to use weak passwords such as `LOVE`, `SEX`, `SECRET`, or `GOD`.

<details>
<summary><strong>Spoiler: solved flag</strong></summary>

```shell
phreakme{redacted}
```


</details>

The main lesson from this solve was to inspect more than the visible body of a file. Headers, metadata, filenames, archive contents, and other structural information can all contain challenge data.

## Solve 2: Find the message

The second challenge prompt was:

> The PhreakTel CEO actually went on the HackStock BBS and left a message!

This solve required searching through the archived BBS messages rather than downloading a file.

I first tried obvious searches such as:

```text
CEO
CHIEF
PRESIDENT
FOUNDER
```

The BBS search interface was confusing because it could search only message subjects or search the full message text. Searching subjects alone often produced no useful results, so I switched to searching message bodies and manually explored the relevant boards.

I also grepped through `clean.log` for the same terms, since I'd already browsed a fair amount of the message base with the recorder running. That turned up a few false leads, unrelated posts that just happened to mention "chief" or "president" in passing, so I went back to manually paging through boards that seemed more likely to be tied to PhreakTel or HackStock specifically, rather than trusting keyword search alone.

Among the archived material, I eventually found an old-looking entry with the timestamp:

```text
Wed Aug 07 13:40:43 1990
```

The message said:

```text
Heh, you found me! Hope it didn't take too long, here's your flag:
```

<details>
<summary><strong>Spoiler: solved flag</strong></summary>

```text
Bbs{redacted}
```

</details>

This solve was exactly why the recording work helped.

The BBS contained enough material that casually clicking around could become overwhelming. Keeping searchable logs meant that once I saw something interesting, I could preserve it, find it again, and document the path rather than hoping I would remember which board or message contained it.

## What I Ended Up Building

By the time I obtained the two flags, I had gone from not knowing what a BBS was to having a small workflow for exploring one:

```text
Browser page and source inspection
              |
              v
WebSocket transport identified
              |
              v
Local websocat bridge
              |
              +---------------------------+
              |                           |
              v                           v
       SyncTERM client             bbs_recorder.py
       - ANSI/CP437                 - ansi.log
       - navigation                 - clean.log
       - ZMODEM downloads           - events.jsonl
              |                           |
              +-------------+-------------+
                            |
                            v
                   local searching
                            ^
                            |
             friend-provided CSV index
             - library
             - directory
             - filename
             - size
             - description
             - no file contents
```

My final workflow was:

1. Use SyncTERM for reliable BBS interaction.
2. Use ZMODEM in SyncTERM to download actual files.
3. Use `bbs_recorder.py` when I wanted a searchable transcript of my own session.
4. Search my friend's CSV when I needed a quick index of available filenames and descriptions.
5. Search `clean.log` for text that had appeared during my own browsing.
6. Return to SyncTERM whenever I needed accurate rendering, navigation, or file transfer.

## Files and Artifacts

The only file from this run included in the repo is:

```text
bbs_recorder.py
```

Session logs, the HAR capture, and the extracted challenge files are kept out of the repo.

# Thoughts

The hardest part was not finding either flag. It was getting reliable access to an unfamiliar system and setting up the initial access.

I started with a browser terminal that kept disconnecting on the DEF CON network and no real understanding of what a BBS was. By inspecting the page, understanding the WebSocket transport, using SyncTERM, learning about ANSI/CP437, and building my own recorder, I turned the BBS into something I could explore more methodically.

I still find the BBS interface confusing, but I am much more comfortable with it than I was at the beginning. The two flags were the immediate result, but the more useful outcome was learning how this older style of system worked and building a workflow that made it manageable. 


# Plovernet

There was a challenge I wasn't able to solve where you had to pop a shell in plovernet, another net within the BBS.  

It had it's own submenus, files, emails, and more.

The login process was hidden in some of files inside the BBS. 

<img width="858" height="675" alt="Screenshot from 2026-08-08 12-14-18" src="https://github.com/user-attachments/assets/2970a9c4-f2e7-458e-a844-64ce884de11a" />


<img width="1016" height="794" alt="Screenshot from 2026-08-07 17-08-12" src="https://github.com/user-attachments/assets/bfedc4bb-bb5c-4c03-bd58-e86a62cd4d4f" />

