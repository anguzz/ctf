``` What is controlling me?
100

There are some Matter devices in my grandma's house. She is old and has trouble walking, so it really helps her to control them all from just a press of a button. Unfortunately, she forgot the name of the application that controls the devices. Can you help me with that?

[Note] The flagValue should be in lowercase, one word, no special characters.
View Hint: Vague hint

Using basic scan techniques and your agile intuition, infer the name of the solution that handles the Matter setup.
```


```bash
angus@aLT:~$ nmap -sn 192.168.1.1/24
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-08-10 12:37 PDT
Nmap scan report for OpenWrt.lan (192.168.1.1)
Host is up (0.17s latency).
Nmap scan report for draco.lan (192.168.1.104)
Host is up (0.19s latency).
Nmap scan report for aLT.lan (192.168.1.177)
Host is up (0.00049s latency).
Nmap scan report for Aqara-Hub-M3-11C3.lan (192.168.1.232)
Host is up (0.29s latency).
Nmap done: 256 IP addresses (4 hosts up) scanned in 13.43 seconds
```

`Aqara-Hub-M3-11C3.lan`

after looking up the name for this I found `ctfbd{aqarahome}`

This was incorrect though the flag was `ctfbd{homeassistant}` which I found after doing a full port scan.