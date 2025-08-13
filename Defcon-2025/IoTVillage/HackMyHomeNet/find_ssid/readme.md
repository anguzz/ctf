# Overview

```
 Find the SSID
100

Hello. I'm visiting my grandma in Romania and I was wondering what I could order for dinner. Can you help me choose from these options? The reservation is at 6 pm.
```

# steps

1. My first thought is to look at meta data of the 5 image files we were given. 
Ran `stat` command on all files the `img` folder but did not see anything that stuck out to me.

```bash
angus@aLT:~/Documents/GitHub/ctf/Defcon-2025/HackMyHomeNet/challenges/findSSID/img$ 
  stat 1.Caesar_salad.jpeg 
  stat 2.Tuna_mushroom_pasta.jpg
  stat 3.Fish_and_chips.jpg 
  stat 4.Boeuf_salad.jpg 
  stat 5.Dumplings.jpg
  File: 1.Caesar_salad.jpeg
  Size: 167424          Blocks: 328        IO Block: 4096   regular file
Device: 259,2   Inode: 19158094    Links: 1
Access: (0664/-rw-rw-r--)  Uid: ( 1000/   angus)   Gid: ( 1000/   angus)
Access: 2025-08-09 13:53:23.075942094 -0700
Modify: 2025-08-09 13:53:23.076943380 -0700
Change: 2025-08-09 13:53:28.648786481 -0700
 Birth: 2025-08-09 13:53:23.075942094 -0700
  File: 2.Tuna_mushroom_pasta.jpg```bash
  Size: 208911          Blocks: 416        IO Block: 4096   regular file
Device: 259,2   Inode: 19158095    Links: 1
Access: (0664/-rw-rw-r--)  Uid: ( 1000/   angus)   Gid: ( 1000/   angus)
Access: 2025-08-09 13:53:23.098971667 -0700
Modify: 2025-08-09 13:53:23.098971667 -0700
Change: 2025-08-09 13:53:30.836288566 -0700
 Birth: 2025-08-09 13:53:23.098971667 -0700
  File: 3.Fish_and_chips.jpg
  Size: 328201          Blocks: 648        IO Block: 4096   regular file
Device: 259,2   Inode: 19158096    Links: 1
Access: (0664/-rw-rw-r--)  Uid: ( 1000/   angus)   Gid: ( 1000/   angus)
Access: 2025-08-09 13:53:23.128008955 -0700
Modify: 2025-08-09 13:53:23.129010241 -0700
Change: 2025-08-09 13:53:33.236924616 -0700
 Birth: 2025-08-09 13:53:23.128008955 -0700
  File: 4.Boeuf_salad.jpg
  Size: 135298          Blocks: 272        IO Block: 4096   regular file
Device: 259,2   Inode: 19158098    Links: 1
Access: (0664/-rw-rw-r--)  Uid: ( 1000/   angus)   Gid: ( 1000/   angus)
Access: 2025-08-09 13:53:45.834201254 -0700
Modify: 2025-08-09 13:53:41.292044073 -0700
Change: 2025-08-09 13:53:45.513916196 -0700
 Birth: 2025-08-09 13:53:41.291043129 -0700
  File: 5.Dumplings.jpg
  Size: 150708          Blocks: 296        IO Block: 4096   regular file
Device: 259,2   Inode: 19158099    Links: 1
Access: (0664/-rw-rw-r--)  Uid: ( 1000/   angus)   Gid: ( 1000/   angus)
Access: 2025-08-09 13:53:52.332716212 -0700
Modify: 2025-08-09 13:53:52.332716212 -0700
Change: 2025-08-09 13:53:52.333717025 -0700
 Birth: 2025-08-09 13:53:52.332716212 -0700
 ```  

 2. I then ran `exiftool` to check out anything else on all the files I may have missed
 
  `exiftool 1.Caesar_salad.jpeg  exiftool 2.Tuna_mushroom_pasta.jpg exiftool 3.Fish_and_chips.jpg  exiftool 4.Boeuf_salad.jpg  exiftool 5.Dumplings.jpg`


Nothing stuck out except the description img 1. 

- `Image Description : Taskrk xkzkrko colo kyzk vxosg rozkxg jot lokigxk lkr jk sgtigxk ia ixgzosg otzxk g zxkog yo g vgzxg rozkxg`


3) I threw this to https://www.dcode.fr/caesar-cipher and got romini text in 6 rot 20 that read
`Numele retelei wifi este prima litera din fiecare fel de mancare cu cratima intre a treia si a patra litera`

4) Throwing it to google translate it says

`The name of the wifi network is the first letter of each type of food with a hyphen between the third and fourth letter`. 

# Flag 
`CTF-BD`
