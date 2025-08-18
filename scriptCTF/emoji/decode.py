
emojis = "🁳🁣🁲🁩🁰🁴🁃🁔🁆🁻🀳🁭🀰🁪🀱🁟🀳🁮🁣🀰🁤🀱🁮🁧🁟🀱🁳🁟🁷🀳🀱🁲🁤🁟🀴🁮🁤🁟🁦🁵🁮🀡🀱🁥🀴🀶🁤🁽"

decoded = ""

for e in emojis:
    code_point = ord(e)           # full Unicode code point
    low_byte = code_point & 0xFF  # just the last byte
    char = chr(low_byte)          # convert to ASCII character
    
    print(f"{e} -> U+{code_point:X} -> {low_byte} -> {char}")
    decoded += char

print("\nDecoded message:", decoded)
