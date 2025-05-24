# CTF Challenge: Polyglots! Four – Solution

This challenge involved a `.jpg` file hiding a PHAR (PHP Archive) payload with an XOR-encoded flag. The hint: *“These were a favorite tool in the phisher’s kit.”* led us to inspect embedded PHP logic.

---

## Summary of Steps

### 1. **Initial Clue & Analysis**

- Ran:
  ```bash
  strings polyglot.jpg > strings_output.txt
  ```
- Found embedded PHP code with `__HALT_COMPILER();`, indicating a PHAR archive structure.
- The PHP snippet revealed how the flag was stored and XOR-decoded using the key `"secret"`.

```php
<?php __HALT_COMPILER(); ?>
flag.dat.
decode.php
<?php
$flag = file_get_contents('phar://polyglot.jpg/flag.dat');
$key = "secret";
$out = '';
for ($i = 0; $i < strlen($flag); $i++) {
    $out .= $flag[$i] ^ $key[$i % strlen($key)];
echo $out;%t
GBMB
}
```

### 2. **PHAR Extraction**

- Binwalk didn’t give much insight:
  ```bash
  binwalk polyglot.jpg
  ```
  Output only showed basic JPEG headers and TIFF info.

- Tried:
  ```bash
  exiftool -Padding -b polyglot.jpg > padding.bin
  ```
  (Didn’t help much directly.)

- Renamed the file for easier PHP processing:
  ```bash
  mv polyglot.jpg polyglot.phar
  ```


- Used a custom script (`extract_phar.php`) and executed:
  ```bash
  php -d phar.readonly=0 extract_phar.php
  ```

### 3. **Flag Decryption**

- The PHP logic discovered in the strings output XOR-decodes the flag using the key `"secret"`.
- After extraction, a `decode.php` file was also found. This file, when run with PHP, outputs the decoded flag.

  ```bash
  php decode.php
  ```

- That revealed the flag directly without needing to recreate the logic manually.

---

## Flag

```
LayerOneCTF{jp3gs_4nd_phar5_4nd_crypt0_0h_my!}
```

---

## Tools Used

- `strings`
- `exiftool`
- `binwalk`
- `php-cli`