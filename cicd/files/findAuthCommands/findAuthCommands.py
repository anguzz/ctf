import subprocess
import re
import shlex

jenkins_url = "http://glitch-two.3f30795e908a7c17.ctf.land:7756/"
cli_jar = "jenkins-cli.jar"  
output_file = "unauthenticated_command_check_results.txt"

auth_error_patterns = [
    re.compile(r"authentication required", re.IGNORECASE),
    re.compile(r"is missing the .* permission", re.IGNORECASE),
    re.compile(r"user is anonymous", re.IGNORECASE), #  "User is anonymous"
    re.compile(r"access denied", re.IGNORECASE),
    re.compile(r"lacks permission", re.IGNORECASE),
    re.compile(r"must be authenticated", re.IGNORECASE)
]

def get_all_cli_commands_from_help():
    """
    Runs 'jenkins-cli.jar help' and parses its output to get a list of commands.
    """
    print("[+] Attempting to fetch all CLI commands from 'help'...")
    commands = []
    try:
        cmd_list_proc = subprocess.run(
            ["java", "-jar", cli_jar, "-s", jenkins_url, "help"],
            capture_output=True, text=True, timeout=30, check=False, # Increased timeout
            errors='replace' # Handle potential decoding errors in help output
        )

        # Regex to find lines starting with 2-4 spaces, then a command name, then a description
        # Example: "  add-job-to-view     Adds jobs to view."
        # Command names typically consist of letters, numbers, and hyphens.
        for line in cmd_list_proc.stdout.splitlines():
            match = re.match(r"^\s{2,4}([a-zA-Z0-9][a-zA-Z0-9-]*)\s{2,}(.+)$", line)
            if match:
                command_name = match.group(1).strip()
                # Avoid adding "COMMAND" or other non-command headers if they match
                if command_name.upper() != "COMMAND" and command_name not in commands:
                    commands.append(command_name)
        
        if commands:
            print(f"    [+] Found {len(commands)} potential commands from 'help' output.")
        else:
            print("    [!] No commands reliably parsed from 'help' output. The format might be unexpected.")
            print("    [!] Consider manually running 'java -jar jenkins-cli.jar -s JENKINS_URL help' to inspect.")

    except subprocess.TimeoutExpired:
        print("    [!] Timeout when trying to fetch all commands via 'help'.")
    except Exception as e:
        print(f"    [!] Error fetching all commands via 'help': {e}")
    
    # Ensure the known good ones from your image are included as a fallback for testing
    # and in case parsing fails
    known_from_image = ["help", "who-am-i", "install-plugin"]
    for ku in known_from_image:
        if ku not in commands:
            print(f"    [i] Adding known command '{ku}' to the list for testing.")
            commands.append(ku)
    
    if not commands: # If still no commands, add some very common ones
        print("    [!] No commands found at all, adding a few very common ones for a last-ditch effort.")
        commands.extend(["version", "list-plugins", "list-jobs"])

    print(f"[+] Final list of commands to test: {sorted(list(set(commands)))}") # Unique and sorted
    return sorted(list(set(commands)))

def check_command_auth_status(command_name):
    """
    Tries to run a command (e.g., by asking for its help or just running it)
    and checks if it fails due to authentication for its *normal operation*.
    This doesn't mean it can't be used for the CVE if it's unauth for arg processing.
    """
    try:
        # if it's not an auth error for merely invoking the command.
        cmd_array = ["java", "-jar", cli_jar, "-s", jenkins_url, command_name]
        
        proc = subprocess.run(
            cmd_array,
            capture_output=True, text=True, timeout=20, check=False,
            errors='replace'
        )
        # Combine stdout and stderr for checking patterns
        output_text = proc.stdout + "\n" + proc.stderr

        for pattern in auth_error_patterns:
            if pattern.search(output_text):
                # This suggests the command's normal function likely requires auth
                return False, f"Auth Error Detected for '{command_name}':\n{output_text.strip()}"

        # If no explicit auth error as defined, it's "Potentially Usable" for CVE purposes
        # or its normal function doesn't immediately scream "auth error".
        # It might still require auth for specific actions but not for initial invocation.
        return True, f"No immediate auth error for '{command_name}'. Output:\n{output_text.strip()}"
        
    except subprocess.TimeoutExpired:
        return False, f"Timeout when checking command '{command_name}'."
    except Exception as e:
        return False, f"Error checking command '{command_name}': {e}"

# --- Main script execution ---
all_commands_to_check = get_all_cli_commands_from_help()

if not all_commands_to_check:
    print("\n[CRITICAL] Could not retrieve or define any command list to check. Exiting.")
else:
    with open(output_file, "w", encoding="utf-8") as f_out:
        f_out.write(f"Jenkins CLI Unauthenticated Command Check for {jenkins_url}\n")
        f_out.write(f"Timestamp: {subprocess.check_output(['date'], text=True).strip()}\n") # Optional: add timestamp
        f_out.write("="*70 + "\n\n")

        if not all_commands_to_check: # Should not happen if fallback worked
             f_out.write("Could not automatically determine list of commands to check.\n")

        for cmd_name in all_commands_to_check:
            print(f"[+] Checking command: {cmd_name}")
            is_potentially_usable_for_cve, details = check_command_auth_status(cmd_name)
            
            f_out.write(f"--- Command: {cmd_name} ---\n")
            if is_potentially_usable_for_cve:
                f_out.write("Status: Potentially usable by anonymous user OR for CVE argument injection (no immediate auth error for invocation).\n")
                print(f"    [✔] {cmd_name} - Potentially usable for CVE / No immediate auth error.")
            else:
                f_out.write("Status: Likely requires authentication for normal operation, or failed.\n")
                print(f"    [✘] {cmd_name} - Likely requires auth for normal op / Other error.")
            f_out.write("Details:\n" + details + "\n") # details already has .strip()
            f_out.write("-" * 70 + "\n\n")

    print(f"\n[+] Command check complete. Results are in: {output_file}")