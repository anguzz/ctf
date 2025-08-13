# IoT Seagate Hacking — Brain Dump Notes (Interactive Demo)

## 1. Finding Information on IoT Devices
- Ask: **How do we find info on IoT devices?**
- Look for **cheap/older devices** (< $100) at thrift stores — good for practice and teardown.
- Many older hubs are excellent targets:
  - Can monitor traffic on **all serial communication ports** (same data across ports).
  - Easier than setting up Wireshark in promiscuous mode.
  - Some older hubs have **VNC enabled**.
  - Often found for ~$5.

## 2. Tools & Techniques
- **“Live off the land”**: Use available built-in or common tools first.
- Recommended tools:
  - `FTK Imager`
  - `binwalk`
  - `Autopsy`
  - Nessus (open-source scanner)
- CVE systems aren’t meaningful for **EOL devices** — new CVEs may still apply.

## 3. IoT Device Behavior & Exploitation
- Certain IoT devices **automatically provision** themselves:
  - May **bypass firewall rules** during provisioning.
  - Often register **dynamic DNS** automatically.
- **DNS hacking**:
  - Effective for APTs (Advanced Persistent Threats).
  - Workflow: Request → DNS server → exfiltration via DNS.

## 4. Hardware & Firmware
- **Repository**: [`github.com/SYNgularity1/defcon-iotvillage-seagate`](https://github.com/SYNgularity1/defcon-iotvillage-seagate)
- **Firmware**:
  - OpenWRT firmware flashing.
  - Install U-Boot.
- **Hardware Access**:
  - Pins connect directly into the device (no soldering needed).
  - Use **USB-to-serial** adapters for access.

## 5. Added Capabilities
- Neural Compute Stick.
- Reinforcement Neural Network.
- “World’s smallest CAPTCHA MFA bypass”:
  - Can train small devices to perform automated bypass.
