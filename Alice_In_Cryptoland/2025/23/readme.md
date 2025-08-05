# Page 23

**The Mad Hatter leans in close, his hat askew and his eyes wide with excitement.**

> “Ah, binary!” he exclaims, as though it’s the most delightful flavor of tea. “A most curious little language, just ones and zeros, but oh, the stories they tell!”

> “Looks like gibberish, doesn’t it?” he says, pouring cream into his boot. “But it’s just a matter of thinking like a machine, which, as it turns out, is not all that different from thinking like a madman.”

He picks up a biscuit and bites it in half. “Each group of eight bits, that's what you call a set of ones and zeros, is one letter. Eight bits make a byte, and bytes make words, and words make sentences, and sentences make delightful nonsense!”

> “Binary code,” he continues, “is used in computing systems. These systems use this code to understand operational instructions and user input and to present a relevant output to the user. Binary numbers can be translated into text characters using American Standard Code for Information Interchange (ASCII) codes to store information in the computer’s RAM or CPU. ASCII-capable applications, like word processors, can read text information from the RAM or CPU. They can also store text information that can then be retrieved by the user at a later time. ASCII codes are stored in the ASCII table, which consists of 128 text or special characters. Each character has an associated decimal value.”

He beams. “Just convert each byte into its decimal form, like 01001000 is 72, then look it up on the ASCII table to find the letter! It's like decoding whispers from a typewriter.”

He pauses, then winks. “But remember, if you miss a bit or flip a one into a zero, your tea might come out as mud instead of milk. And nobody wants binary mud.”

---

*You can find ASCII Tables and binary decoders online.*



`011100110110001101101111011011100110010101110011`


**Return to view the menu on page 11.**


--------

### Decoded 
I just spaced it out every byte(8 digits)

gives us 

`01110011 01100011 01101111 01101110 01100101 01110011`


`115 99 111 110 101 115`


if you have `ascii` installed you can run `ascii -d` and get

```bash
angus@aLT:~$ ascii -d
    0 NUL    16 DLE    32      48 0    64 @    80 P    96 `   112 p 
    1 SOH    17 DC1    33 !    49 1    65 A    81 Q    97 a   113 q 
    2 STX    18 DC2    34 "    50 2    66 B    82 R    98 b   114 r 
    3 ETX    19 DC3    35 #    51 3    67 C    83 S    99 c   115 s 
    4 EOT    20 DC4    36 $    52 4    68 D    84 T   100 d   116 t 
    5 ENQ    21 NAK    37 %    53 5    69 E    85 U   101 e   117 u 
    6 ACK    22 SYN    38 &    54 6    70 F    86 V   102 f   118 v 
    7 BEL    23 ETB    39 '    55 7    71 G    87 W   103 g   119 w 
    8 BS     24 CAN    40 (    56 8    72 H    88 X   104 h   120 x 
    9 HT     25 EM     41 )    57 9    73 I    89 Y   105 i   121 y 
   10 LF     26 SUB    42 *    58 :    74 J    90 Z   106 j   122 z 
   11 VT     27 ESC    43 +    59 ;    75 K    91 [   107 k   123 { 
   12 FF     28 FS     44 ,    60 <    76 L    92 \   108 l   124 | 
   13 CR     29 GS     45 -    61 =    77 M    93 ]   109 m   125 } 
   14 SO     30 RS     46 .    62 >    78 N    94 ^   110 n   126 ~ 
   15 SI     31 US     47 /    63 ?    79 O    95 _   111 o   127 DEL 
```

This maps the value `115 99 111 110 101 115` to `scones` 

*you can run this from the binary or from the decimal directly on cyberchef as well*