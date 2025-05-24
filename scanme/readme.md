
# Scanme
We were given a color QR code `qr1.png` that failed to scan using normal readers. It turned out the QR used color encoding, requiring image processing before decoding.


- `qr_color_split.sh` was used to test different colors by converting colored QR modules into black-and-white:

Generates three grayscale variants:
- `qr_red_is_data.png`
- `qr_blue_is_data.png`
- `qr_both_red_blue_is_data.png`

After scanning:
  - `qr_blue_is_data.png`= `LayerOneCTF{c0l0r_`

  - `qr_red_is_data/png` = `f1lt3r5_4r3_fun!!}`
 

 flag: `LayerOneCTF{c0l0r_ f1lt3r5_4r3_fun!!}`



