

challenge 2

# BRIEFING
A dealer at the back tables kept a private ledger locked away, scrambled before he vanished into the crowd. Security swept the floor after the fact and pulled a single scrambled file off his terminal, nothing else.
The lock looks solid at a glance, but the house never spends more than it has to. See if you can shake the ledger loose and read what he was hiding.

🎰 THE TABLE
Attachments
-download task files


## First Look

The encryption script challenge.py showed me this:

```python
key = os.urandom(4)
flag = b"THM{FAKE_FLAG_FOR_TESTING}"
encrypted = xor(flag, key)
```

Two things jumped out immediately:

1. **The key is only 4 bytes long.** which is pretty short
2. **The flag is way longer than 4 bytes.** So the key can't cover the whole flag on its own.

## Why That's a Problem (For the Dealer)

When you XOR a short key against a longer message, the encryption tool doesn't just stop it **repeats the key** over and over until it covers the whole message. So instead of one solid lock, you end up with the same short key reused again and again.

This is basically an old-school cipher called a **Vigenère cipher**, and it's known to be breakable, especially if you can guess even a small piece of the original message.

## The Piece I Could Guess

Every flag in this challenge follows the same format: it starts with `THM{`. That's not a guess it's guaranteed, since the key is *exactly* 4 bytes, and `THM{` is *exactly* 4 characters, those first 4 bytes of ciphertext were encrypted using the **entire key**, start to finish. So if I can undo those first 4 bytes, I don't just get a fragment — I get the whole key.

## Undoing the Lock

XOR has a neat property, if you XOR something twice with the same value, you get your original data back. That means:

```
ciphertext XOR key = plaintext
```

can be flipped around to:

```
ciphertext XOR plaintext = key
```

So I took the first 4 bytes of the encrypted file and XORed them against `THM{`:

```python
key = data[:4] ^ b"THM{"
```

That gave me the full 4-byte key the dealer used.

## Cracking the Whole File

Once I had the key, decrypting the rest was easy, I just XORed the entire ciphertext against the key, looping the key back to the start every 4 bytes

```python
flag = bytes(c ^ key[i % len(key)] for i, c in enumerate(data))
```

## The Result

```
THM{X0r_K3y_r3c0verY_H4s_N3veR_B33n_Th1S_E@sy}
```

## The Takeaway

The dealer's mistake was using a short, random key on a message longer than the key itself. Short keys repeat, repeated keys create patterns, and patterns become breakable the moment you can guess even a small chunk of the original text. A 4byte key paired with a predictable prefix like `THM{` is basically an open door.