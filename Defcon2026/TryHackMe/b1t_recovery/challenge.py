import os
from pwn import *

key = os.urandom(4)
flag = b"THM{FAKE_FLAG_FOR_TESTING}" # fake flag, look at encrypted.bin and figure out the vulnerability in this encryption method.

encrypted = xor(flag, key)

with open("encrypted.bin", "wb") as f:
	f.write(encrypted)
