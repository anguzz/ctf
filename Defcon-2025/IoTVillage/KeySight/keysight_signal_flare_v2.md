# Keysight CTF — Signal Flare 2.0

Welcome to **Signal Flare 2.0**!

Things are a bit harder this time around:
- No more SNMP.
- No more hidden backdoor.
- The flag location is not disclosed.

There is an **SSH service** that allows limited commands on the device.

**Access:**
- **Username:** `patlite`
- **Password:** `keysight`

**Example SSH session:**
```bash
$ ssh -oKexAlgorithms=diffie-hellman-group14-sha1 -oHostKeyAlgorithms=+ssh-dss patlite@10.0.80.15
patlite@10.0.80.15's password: 
Last login: Fri Jan  1 09:18:48 2010 from 10.0.80.100
-rbash-4.0$ status
000000
```

---

## Steps Taken (work-in-progress)

### 1) SSH in; most common commands disabled
```bash
angus@aLT:~$ ssh -oKexAlgorithms=diffie-hellman-group14-sha1 -oHostKeyAlgorithms=+ssh-dss patlite@10.0.80.15
The authenticity of host '10.0.80.15 (10.0.80.15)' can't be established.
DSA key fingerprint is SHA256:XK6gHf5w0mdOKM40fL/1DsZ8LV6GQ484HbRh8KonN9A.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '10.0.80.15' (DSA) to the list of known hosts.
patlite@10.0.80.15's password: 
Last login: Fri Jan  1 19:43:02 2010 from 10.0.80.52
-rbash-4.0$ dir
-rbash: dir: command not found
-rbash-4.0$ ls
-rbash: ls: command not found
-rbash-4.0$ clear
-rbash: clear: command not found
```

### 2) Check available builtins via `help`
```bash
-rbash-4.0$ help
GNU bash, version 4.0.44(1)-release (sh4-unknown-linux-gnu)
These shell commands are defined internally.  Type `help' to see this list.
Type `help name' to find out more about the function `name'.
Use `info bash' to find out more about the shell in general.
Use `man -k' or `info' to find out more about commands not in this list.

A star (*) next to a name means that the command is disabled.

 job_spec [&]                           *history [-c] [-d offset] [n] or hist>
 (( expression ))                        if COMMANDS; then COMMANDS; [ elif C>
 . filename [arguments]                  jobs [-lnprs] [jobspec ...] or jobs >
 :                                       kill [-s sigspec | -n signum | -sigs>
 [ arg... ]                              let arg [arg ...]
 [[ expression ]]                        local [option] name[=value] ...
 alias [-p] [name[=value] ... ]          logout [n]
 bg [job_spec ...]                       mapfile [-n count] [-O origin] [-s c>
 bind [-lpvsPVS] [-m keymap] [-f filen>  popd [-n] [+N | -N]
 break [n]                               printf [-v var] format [arguments]
 builtin [shell-builtin [arg ...]]       pushd [-n] [+N | -N | dir]
 caller [expr]                           pwd [-LP]
 case WORD in [PATTERN [| PATTERN]...)>  read [-ers] [-a array] [-d delim] [->
 cd [-L|-P] [dir]                        readarray [-n count] [-O origin] [-s>
 command [-pVv] command [arg ...]        readonly [-af] [name[=value] ...] or>
 compgen [-abcdefgjksuv] [-o option]  >  return [n]
 complete [-abcdefgjksuv] [-pr] [-o op>  select NAME [in WORDS ... ;] do COMM>
 compopt [-o|+o option] [name ...]       set [--abefhkmnptuvxBCHP] [-o option>
 continue [n]                            shift [n]
 coproc [NAME] command [redirections]    shopt [-pqsu] [-o] [optname ...]
 declare [-aAfFilrtux] [-p] [name[=val> *source filename [arguments]
 dirs [-clpv] [+N] [-N]                  suspend [-f]
 disown [-h] [-ar] [jobspec ...]        *test [expr]
*echo [-neE] [arg ...]                   time [-p] pipeline
 enable [-a] [-dnps] [-f filename] [na>  times
*eval [arg ...]                          trap [-lp] [[arg] signal_spec ...]
*exec [-cl] [-a name] [command [argume>  true
 exit [n]                                type [-afptP] name [name ...]
 export [-fn] [name[=value] ...] or ex>  typeset [-aAfFilrtux] [-p] name[=val>
 false                                   ulimit [-SHacdefilmnpqrstuvx] [limit>
 fc [-e ename] [-lnr] [first] [last] o>  umask [-p] [-S] [mode]
 fg [job_spec]                           unalias [-a] name [name ...]
 for NAME [in WORDS ... ] ; do COMMAND>  unset [-f] [-v] [name ...]
 for (( exp1; exp2; exp3 )); do COMMAN>  until COMMANDS; do COMMANDS; done
 function name { COMMANDS ; } or name >  variables - Names and meanings of so>
 getopts optstring name [arg]            wait [id]
 hash [-lr] [-p pathname] [-dt] [name >  while COMMANDS; do COMMANDS; done
 help [-ds] [pattern ...]                { COMMANDS ; }
```

### 3) Confirm working directory and restricted `cd`
```bash
-rbash-4.0$ pwd
/home/patlite

-rbash-4.0$ cd home
-rbash: cd: restricted

-rbash-4.0$ cd ..
-rbash: cd: restricted
```

### 4) Device status command and path
```bash
-rbash-4.0$ status
110000

-rbash-4.0$ command -v status
/home/patlite/bin/status   # (note: indicates an executable in $HOME/bin)
```

### 5) Shell options and environment
```bash
-rbash-4.0$ shopt
autocd         	off
cdable_vars    	off
cdspell        	off
checkhash      	off
checkjobs      	off
checkwinsize   	off
cmdhist        	on
compat31       	off
compat32       	off
dirspell       	off
dotglob        	off
execfail       	off
expand_aliases 	on
extdebug       	off
extglob        	off
extquote       	on
failglob       	off
force_fignore  	on
globstar       	off
gnu_errfmt     	off
histappend     	off
histreedit     	off
histverify     	off
hostcomplete   	on
huponexit      	off
interactive_comments	on
lithist        	off
login_shell    	on
mailwarn       	off
no_empty_cmd_completion	off
nocaseglob     	off
nocasematch    	off
nullglob       	off
progcomp       	on
promptvars     	on
restricted_shell	on
shift_verbose  	off
sourcepath     	on
```

```bash
-rbash-4.0$ export
declare -x G_BROKEN_FILENAMES="1"
declare -x HISTSIZE="1000"
declare -x HOME="/home/patlite"
declare -x HOSTNAME="nh.patlite.jp"
declare -x LANG="en_US.UTF-8"
declare -x LESSOPEN="|/usr/bin/lesspipe.sh %s"
declare -x LOGNAME="patlite"
declare -x LS_COLORS="..."
declare -x MAIL="/var/spool/mail/patlite"
declare -x OLDPWD
declare -rx PATH="/home/patlite/bin:/home/patlite/bin"
declare -x PWD="/home/patlite"
declare -rx SHELL="/bin/rbash"
declare -x SHLVL="1"
declare -x SSH_CLIENT="10.0.80.210 42734 22"
declare -x SSH_CONNECTION="10.0.80.210 42734 10.0.80.15 22"
declare -x SSH_TTY="/dev/pts/1"
declare -x TERM="vt100"
declare -x USER="patlite"
```

### 6) Discover files with allowed builtins
```bash
-rbash-4.0$ printf "%s\n" *
bin

-rbash-4.0$ printf "%s\n" bin/*
# (initially produced no listing)
```

Later, confirmed contents:
```bash
-rbash-4.0$ printf "%s\n" bin/*
bin/cut
bin/md5sum
bin/output_flag
bin/status
```

> Note: `rbash` blocks running commands with `/` in the name:
```bash
-rbash-4.0$ ./bin/output_flag
-rbash: ./bin/output_flag: restricted: cannot specify `/' in command names
```

### 7) Attempts to derive the `output_flag` password

Tried direct status value and various transformations/hashes.

#### Raw tries
```bash
-rbash-4.0$ output_flag
usage: output_flag <password>

-rbash-4.0$ output_flag 110000
incorrect password

-rbash-4.0$ status
111000

# Hash of "110000" with newline
-rbash-4.0$ printf "110000" | md5sum
2e07b8c9c22897dbd06cb0888eb7e540  -
-rbash-4.0$ output_flag 2e07b8c9c22897dbd06cb0888eb7e540
incorrect password

# Various combos (HOSTNAME + status, etc.)
-rbash-4.0$ output_flag $(status | md5sum | cut -d' ' -f1)
incorrect password

-rbash-4.0$ output_flag $(printf "%s" "$HOSTNAME$(status)" | md5sum | cut -d' ' -f1)
incorrect password

-rbash-4.0$ output_flag $(md5sum bin/status | cut -d' ' -f1)
incorrect password

-rbash-4.0$ output_flag $(md5sum bin/output_flag | cut -d' ' -f1)
incorrect password

-rbash-4.0$ s=$(status); printf "%s" "$s" | md5sum | cut -d' ' -f1
# (produces hash, but still rejected when passed to output_flag)
```

#### Other transformations tried
```bash
-rbash-4.0$ echo "111000" | md5sum
-rbash: echo: command not found

-rbash-4.0$ echo -n "111000" | md5sum
-rbash: echo: command not found

-rbash-4.0$ echo -n "111000patlite" | md5sum
-rbash: echo: command not found

-rbash-4.0$ echo -n "111000nh.patlite.jp" | md5sum
-rbash: echo: command not found

-rbash-4.0$ echo -n "111000" | base64
-rbash: echo: command not found

# Trying a known MD5 for "111111" as a sanity check
-rbash-4.0$ output_flag 96e79218965eb72c92a549dd5a330112
incorrect password
```

**Environment values used:**
```bash
-rbash-4.0$ printf "%s\n" "$HOSTNAME"
nh.patlite.jp
```

---

## Notes & Observations

- Shell is **restricted bash** (`/bin/rbash`) with `restricted_shell=on` and `PATH` locked to `$HOME/bin`.
- Many common utilities are missing/disabled, but **`printf`**, **`md5sum`**, **`cut`**, and the challenge binaries **`status`** and **`output_flag`** exist in `$HOME/bin`.
- `rbash` **blocks executing with slashes** (e.g., `./bin/output_flag`), but calling `output_flag` by name works since `$HOME/bin` is on `PATH`.
- `status` outputs a **6‑digit binary-like string** (observed values: `110000`, `111000`).
- Passing the raw value, its MD5, or combinations with `HOSTNAME` did **not** satisfy `output_flag`.

---

## TODO / Next Ideas (unable to finish)

- Check if `status` output changes over time or with session state; try multiple calls and compare.
- Investigate if `output_flag` expects a **specific format** (e.g., hex, base64, uppercase/lowercase).
- Explore whether `output_flag` wants **MD5 of something else**: e.g., `md5(status + newline)`, `md5(status without newline)`, `md5(status + secret salt)`, or `md5sum` of the **bytes produced by `status` piped directly**.
- Use only allowed builtins to **introspect strings**: `printf` is available; try length checks, hexdumps if any are present in `$HOME/bin` (currently not).
- Try **timing-based** or **sequence-based** inputs (e.g., two consecutive `status` reads concatenated).
- If any other tools appear in `$HOME/bin`, attempt to leverage them with `printf` pipelines.

---

_This document is a formatted transcript of in-progress notes and attempts. It intentionally preserves unfinished work for later reference.
