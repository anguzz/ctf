# Div
```
392

NoobMaster

I love division
Attachments

    chall.py

Instance Info
Remaining Time: 3587s

nc play.scriptsorcerers.xyz 10455
```

Looked at chall.py and saw we needed our division to be zero to get the flag.

`secret = int(os.urandom(16).hex(),16)` 

The problem is the secret is a massive random number, so our input has to be infinitely large. But the script blocks long numbers and anything with an 'e' or scientific notation in python.

The condition below tells us how to get the flag, make our division = 0, and any number divided by infinity is zero, which gets past the check. 

```bash
if div == 0:
    print(open('flag.txt').read().strip())
```
Using the python string literal `inf` was accepted and got the flag

```bash
angus@angusMintDev:~$ nc play.scriptsorcerers.xyz 10455
Enter a number: inf
scriptCTF{70_1nf1n17y_4nd_b3y0nd_5765d3eed11d}
```


# flag
`scriptCTF{70_1nf1n17y_4nd_b3y0nd_5765d3eed11d}`

