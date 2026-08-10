```

wave (100pts) - 290 solves
by Eth007
Description

not a steg challenge i promise
Attachments

wave.wav

```


I ran a `file` and `exiftool` on the file provided, the flag was on the comment data field. 

```bash
angus@angusMintDev:~/Documents/GitHub/ctf/ImaginaryCTF/wave$ file wave.wav
wave.wav: Audio file with ID3 version 2.3.0, contains:\012- RIFF (little-endian) data, WAVE audio, Microsoft PCM, 16 bit, stereo 44100 Hz
angus@angusMintDev:~/Documents/GitHub/ctf/ImaginaryCTF/wave$ exiftool wave.wav
ExifTool Version Number         : 12.76
File Name                       : wave.wav
Directory                       : .
File Size                       : 1051 kB
File Modification Date/Time     : 2025:09:05 15:11:09-07:00
File Access Date/Time           : 2025:09:05 15:14:36-07:00
File Inode Change Date/Time     : 2025:09:05 15:13:33-07:00
File Permissions                : -rw-rw-r--
File Type                       : MP3
File Type Extension             : mp3
MIME Type                       : audio/mpeg
ID3 Size                        : 2194
Comment                         : ictf{obligatory_metadata_challenge}
Title                           : 
Artist                          : 
Album                           : 
Year                            : 
Genre                           : None
```

# Flag
`ictf{obligatory_metadata_challenge}`