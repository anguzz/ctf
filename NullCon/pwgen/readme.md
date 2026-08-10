# Pwgen (104 pts)

**Category:** Web
**Author:** @gehaxelt


## Challenge

> Password policies aren't always great. That's why we generate passwords for our users based on a strong master password!
> `http://52.59.124.14:5003`

At the homepage we see:

```
Bad shuffle count! We won't have more than 1000 users anyway, but we can't tell you the master password!
Take a look at /?source
```

At `/?source` the source code (`src.php`) is revealed:

```php
$shuffle_count = abs(intval($_GET['nthpw']));

if($shuffle_count > 1000 or $shuffle_count < 1) {
    echo "Bad shuffle count!";
    die();
}

srand(0x1337); // fixed seed

for($i = 0; $i < $shuffle_count; $i++) {
    $password = str_shuffle($FLAG);
}

if(isset($password)) {
    echo "Your password is: '$password'";
}
```

---

## Analysis

* The flag is stored in `$FLAG`.
* `srand(0x1337)` fixes the seed, so every shuffle is deterministic.
* `str_shuffle` is implemented with the **Fisher–Yates algorithm** using `rand()`.
* Visiting `/?nthpw=k` runs the shuffle `k` times. Only the last shuffled result is printed.

This means the string we see on the site is not random junk it’s a reproducible permutation of the real flag.

---

## Approach

When PHP shuffles, it builds a permutation table:

* Example: `"ABCD"` → `"CADB"` might correspond to:

  ```
  new[0] = old[2]
  new[1] = old[0]
  new[2] = old[3]
  new[3] = old[1]
  ```
* To reverse this, we need to **rebuild the same permutation** using the known seed and then invert it.

---

## Exploit

1. Grab the observed string from the service:

```
http://52.59.124.14:5003/?nthpw=1
Your password is: '7F6_23Ha8:5E4N3_/e27833D4S5cNaT_1i_O46STLf3r-4AH6133bdTO5p419U0n53Rdc80F4_Lb6_65BSeWb38f86{dGTf4}eE8__SW4Dp86_4f1VNH8H_C10e7L62154'
```

2. Reproduce PHP’s shuffle locally:

   * Re-seed RNG with `srand(0x1337)`.
   * Build the Fisher–Yates permutation.
   * If `k > 1`, burn the RNG calls for earlier discarded shuffles.
   * Invert the permutation to map characters back to original positions.

3. I had an LLM help me generate a PHP script (`unshuffle.php`) that automates this process. Running it with the observed string recovers the flag.

---

## Result

```bash
$ php unshuffle.php
ENO{N3V3r_SHUFFLE_W1TH_STAT1C_S333D_OR_B4D_TH1NGS_WiLL_H4pp3n:-/_0d68ea85d88ba14eb6238776845542cf6fe560936f128404e8c14bd5544636f7}
```

---

## Flag

```
ENO{N3V3r_SHUFFLE_W1TH_STAT1C_S333D_OR_B4D_TH1NGS_WiLL_H4pp3n:-/_0d68ea85d88ba14eb6238776845542cf6fe560936f128404e8c14bd5544636f7}
```

---

## References

* [PHP manual: `str_shuffle`](https://www.php.net/manual/en/function.str-shuffle.php)
* [PHP source code: `shuffle()` implementation (Fisher–Yates)](https://github.com/php/php-src/blob/master/ext/standard/array.c)
* [StackOverflow: Is it possible to reverse PHP `str_shuffle`](https://stackoverflow.com/questions/52750337/is-it-possible-to-reverse-php-str-shuffe)

