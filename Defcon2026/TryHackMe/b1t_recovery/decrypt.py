
data = open('encrypted.bin','rb').read()
known = b'THM{'
key = bytes(a ^ b for a, b in zip(data[:4], known))
print('Key:', key.hex())
out = bytes(data[i] ^ key[i % len(key)] for i in range(len(data)))
print(out)
