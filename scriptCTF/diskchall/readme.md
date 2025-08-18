# diskchall

```
 diskchal
100

Connor Chang

i accidentally vanished my flag, can u find it for me
Attachments

    stick.img
```

1) I inspected the image file on mintoS and noticed and its a `Raw disk image (application/vnd.efi.img)`

2) I mounted it with 

```bash
mkdir /mnt/stick
sudo mount -o loop stick.img /mnt/stick
ls -la /mnt/stick
```

2) This is what I found in the directory and in the file contents

```bash
angus@angusMintDev:~/Documents/GitHub/ctf/scriptCTF/diskchall$ ls -la /mnt/stick
total 6
drwxr-xr-x 2 root root  512 Dec 31  1969 .
drwxr-xr-x 3 root root 4096 Aug 17 12:11 ..
-rwxr-xr-x 1 root root   76 Jul 17 15:27 notes.txt
-rwxr-xr-x 1 root root   56 Jul 17 15:27 random_thoughts.txt

angus@angusMintDev:/mnt/stick$ cat notes.txt
Notes:
- practice my zarrow shuffle
- learn some false cuts
- play some sts

angus@angusMintDev:/mnt/stick$ cat random_thoughts.txt 
i wonder where i put the flag. did i palm it somewhere?
```

3) I checked them with exiftool to see if I saw anything funky or hidden data fields
```bash
angus@angusMintDev:/mnt/stick$ exiftool notes.txt
ExifTool Version Number         : 12.76
File Name                       : notes.txt
Directory                       : .
File Size                       : 76 bytes
File Modification Date/Time     : 2025:07:17 15:27:22-07:00
File Access Date/Time           : 2025:08:16 17:00:00-07:00
File Inode Change Date/Time     : 2025:07:17 15:27:22-07:00
File Permissions                : -rwxr-xr-x
File Type                       : TXT
File Type Extension             : txt
MIME Type                       : text/plain
MIME Encoding                   : us-ascii
Newlines                        : Unix LF
Line Count                      : 4
Word Count                      : 15

angus@angusMintDev:/mnt/stick$ exiftool random_thoughts.txt
ExifTool Version Number         : 12.76
File Name                       : random_thoughts.txt
Directory                       : .
File Size                       : 56 bytes
File Modification Date/Time     : 2025:07:17 15:27:22-07:00
File Access Date/Time           : 2025:08:16 17:00:00-07:00
File Inode Change Date/Time     : 2025:07:17 15:27:22-07:00
File Permissions                : -rwxr-xr-x
File Type                       : TXT
File Type Extension             : txt
MIME Type                       : text/plain
MIME Encoding                   : us-ascii
Newlines                        : Unix LF
Line Count                      : 1
Word Count                      : 12
```

4) The files looked fine via exiftool to so I tried running strings on the img since this also tells us about deleted entries.

``` bash
angus@angusMintDev:~/Documents/GitHub/ctf/scriptCTF/diskchall$ strings -td stick.img 
      3 mkfs.fat
     71 NO NAME    FAT32   
    119 This is not a bootable disk.  Please insert a bootable floppy and
    186 press any key to try again ... 
    512 RRaA
    996 rrAa
   3075 mkfs.fat
   3143 NO NAME    FAT32   
   3191 This is not a bootable disk.  Please insert a bootable floppy and
   3258 press any key to try again ... 
   3584 RRaA
   4068 rrAa
 403488 NOTES   TXT 
 403584 RANDOM~1TXT 
 403681 ECRET~1GZ  
 403968 Notes:
 403975 - practice my zarrow shuffle
 404004 - learn some false cuts
 404028 - play some sts
 404480 i wonder where i put the flag. did i palm it somewhere?
 405002 flag.txt
 405029 513L
 405034 7/2L
```

5) I noticed there was a flag.txt string at disk offset 405002.

*(got stuck here for a while but was able to find out the following)*

If we hex dump that data offset on the image `xxd -s 404992 -l 100 stick.img` we get

```
00062e00: 1f8b 0808 ca78 7968 0003 666c 6167 2e74  .....xyh..flag.t
00062e10: 7874 002b 4e2e ca2c 2871 0e71 ab36 8ccf  xt.+N..,(q.q.6..
00062e20: 3128 338e cf35 3133 4c8e 372f 324c ce36  1(3..513L.7/2L.6
00062e30: ade5 0200 0ba1 b6db 1f00 0000 0000 0000  ................
```

`1f 8b 08` is a gzip signature header, so flag.txt was actually stored as a gzip/compressed file.

6) Running a carve and decompress with gzip to try to open that file gave me the flag

```bash
 dd if=stick.img bs=1 skip=404992 count=2048 of=flag.gz
 gzip -dc flag.gz
 ```

# flag
`scriptCTF{1_l0v3_m461c_7r1ck5}`


notes on what I learned:

* **Mount first**  maybe the flag is obvious.
* Try to exiftool on file types for sanity check
* If not, **strings on the image** often reveals deleted files.
* If you see something suspicious, use **xxd** to confirm headers/magic numbers.
* Use **dd** to carve from that offset, then the right tool (`gzip` here) to open it.

---
