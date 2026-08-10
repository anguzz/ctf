<?php
$obs = '7F6_23Ha8:5E4N3_/e27833D4S5cNaT_1i_O46STLf3r-4AH6133bdTO5p419U0n53Rdc80F4_Lb6_65BSeWb38f86{dGTf4}eE8__SW4Dp86_4f1VNH8H_C10e7L62154';
$k   = 1; // same ?nthpw value 

srand(0x1337); 

$n = strlen($obs);
echo "Observed shuffled string (length $n):\n$obs\n\n";

// -----------------------------------------------------------
// 1: Burn RNG calls if k > 1
// (challenge discards earlier shuffles)
for ($t = 1; $t < $k; $t++) {
    for ($i = $n - 1; $i > 0; $i--) {
        rand(0, $i);
    }
}
if ($k > 1) {
    echo "Burned RNG calls for ".($k-1)." prior shuffle(s).\n\n";
}

// -----------------------------------------------------------
//  2: Build the permutation the *k-th* str_shuffle would use (yac)
$perm = range(0, $n - 1);
for ($i = $n - 1; $i > 0; $i--) {
    $j = rand(0, $i);
    // same swap PHP's str_shuffle does internally
    $tmp = $perm[$i];
    $perm[$i] = $perm[$j];
    $perm[$j] = $tmp;
}

// for debugging: show the first 20 entries of the permutation
echo "Permutation table (first 20 entries):\n";
for ($x = 0; $x < min(20, $n); $x++) {
    echo "new[$x] <- old[".$perm[$x]."]\n";
}
echo "...\n\n";

// -----------------------------------------------------------
//  3: Invert permutation (map shuffled -> original)
$out = array_fill(0, $n, '');
for ($pos = 0; $pos < $n; $pos++) {
    // Character at shuffled position $pos belongs at $perm[$pos]
    $out[$perm[$pos]] = $obs[$pos];
}

// -----------------------------------------------------------
// Step 4: Print result
$flag = implode('', $out);
echo "Recovered original string:\n$flag\n";
