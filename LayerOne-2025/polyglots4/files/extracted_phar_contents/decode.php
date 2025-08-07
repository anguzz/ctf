<?php
$flag = file_get_contents('phar://polyglot.jpg/flag.dat');
$key = "secret";
$out = '';
for ($i = 0; $i < strlen($flag); $i++) {
    $out .= $flag[$i] ^ $key[$i % strlen($key)];
}
echo $out;