# CTF Challenge: Polyglots! Three – Solution

Steps I took to solve the *Polyglots! Three* CTF challenge at LayerOne2025. The file was a `.gif` polyglot hiding a Java archive that, once decompiled and reversed, revealed the flag.

commands
- `exiftool polyglot.gif`

- `mv polyglot.gif polyglot.zip`

- `unzip polyglot.zip`

- `Java CheckFlag`

- enter the password from exiftool `unzip polyglot.zip`


### pre-reqs
- exiftool
- jdk 



```bash
angus@aLT:~/Downloads$ dir
polyglot.gif
angus@aLT:~/Downloads$ exiftool polyglot.gif
ExifTool Version Number         : 12.76
File Name                       : polyglot.gif
Directory                       : .
File Size                       : 405 kB
File Modification Date/Time     : 2025:05:24 14:00:40-07:00
File Access Date/Time           : 2025:05:24 14:00:42-07:00
File Inode Change Date/Time     : 2025:05:24 14:00:40-07:00
File Permissions                : -rw-rw-r--
File Type                       : GIF
File Type Extension             : gif
MIME Type                       : image/gif
GIF Version                     : 89a
Image Width                     : 1024
Image Height                    : 545
Has Color Map                   : Yes
Color Resolution Depth          : 8
Bits Per Pixel                  : 8
Background Color                : 0
Comment                         : password=flagplskthx
Transparent Color               : 252
Image Size                      : 1024x545
Megapixels                      : 0.558
angus@aLT:~/Downloads$ mv polyglot.gif polyglot.zip
angus@aLT:~/Downloads$ dir
polyglot.zip
angus@aLT:~/Downloads$ unzip polyglot.zip
Archive:  polyglot.zip
warning [polyglot.zip]:  404159 extra bytes at beginning or within zipfile
  (attempting to process anyway)
   creating: META-INF/
  inflating: META-INF/MANIFEST.MF    
  inflating: CheckFlag.class         
angus@aLT:~/Downloads$ java CheckFlag
Enter password: flagplskthx
LayerOneCTF{g1f4r5_0r_j1f4r5??}
```

**Flag**: `LayerOneCTF{g1f4r5_0r_j1f4r5??}`