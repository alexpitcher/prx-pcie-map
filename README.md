# Proxmox PCI Resource Mapping Tools

This repository contains scripts to assist with managing PCI devices in a Proxmox environment. These tools provide detailed information about PCI devices, help with resource mapping, and facilitate passthrough configurations for virtual machines.

## Quick Start

To get going straight away, download the script using wget and mark it as excecutable:

```bash
wget https://raw.githubusercontent.com/alexpitcher/prx-pcie-tools/refs/heads/main/pcinfo.sh
chmod +x pcinfo.sh
```

## Table of Contents
- [Overview](#overview)
- [Scripts](#scripts)
    - [pcinfo.sh](#pcinfosh)
    - [prx-pcie-map.sh](#prx-pcie-mapsh)
- [Usage](#usage)
    - [pcinfo.sh Usage](#pcinfosh-usage)
    - [prx-pcie-map.sh Usage](#prx-pcie-mapsh-usage)
- [Requirements](#requirements)
- [License](#license)

---

## Overview

Managing PCI devices in a virtualized environment can be complex. These scripts simplify the process by:
- Providing detailed information about PCI devices.
- Filtering devices to show only Ethernet or Network controllers.
- Assisting with PCI passthrough configurations for Proxmox virtual machines.

---

## Scripts

### pcinfo.sh

The `pcinfo.sh` script is an enhanced PCI device information and passthrough checker. It gathers detailed information about PCI devices and displays only Ethernet or Network controllers.

#### Features:
- **Modes**:
    - `/h` or `/help`: Show help.
    - `/a` or `/all`: Process all network devices.
    - `/s` or `/slot <n>`: Process a specific PCI slot using `dmidecode`.
    - `/p` or `/pci <id>`: Process a specific PCI device.
    - `/l` or `/list`: List all PCI devices (default mode).
- **Display Flags**:
    - `/m` or `/mapping`: Show PCI resource mapping info.
    - `/v` or `/vms`: Show VM passthrough usage info.
    - `/n` or `/net`: Show network interface info.
    - `/d` or `/driver`: Show driver info.
    - `/V` or `/verbose`: Enable verbose `lspci` output.
- **Output Redirection**:
    - `/o` or `/output <path>`: Redirect output to a file.

### prx-pcie-map.sh

The `prx-pcie-map.sh` script helps create PCI resource mappings in Proxmox. It uses `dmidecode` to display slot information and `lspci` to get device details.

#### Features:
- Fetches PCI slot information using `dmidecode`.
- Displays device details for a given slot.
- Prompts the user for mapping parameters and executes the mapping command.

---

## Usage

### pcinfo.sh Usage

Run the script as root to gather PCI device information. Examples:

- List all network devices:
    ```bash
    ./pcinfo.sh /l
    ```

- Process all network devices:
    ```bash
    ./pcinfo.sh /a
    ```

- Process a specific PCI slot:
    ```bash
    ./pcinfo.sh /s <slot_number>
    ```

- Process a specific PCI device:
    ```bash
    ./pcinfo.sh /p <pci_id>
    ```

- Redirect output to a file:
    ```bash
    ./pcinfo.sh /a /o output.txt
    ```

### prx-pcie-map.sh Usage

Run the script as root to create PCI resource mappings. Example workflow:

1. Start the script:
     ```bash
     ./prx-pcie-map.sh
     ```

2. Enter the slot number to map.

3. Review the slot and device details.

4. Provide mapping parameters:
     - Mapping name.
     - Proxmox node name.
     - PCI path (e.g., `0000:01:00.0`).
     - Device ID (e.g., `0002:0001`).

5. Confirm and execute the mapping command.

---

## Requirements

- **Proxmox VE**: Ensure Proxmox is installed and configured.
- **Root Access**: Both scripts require root privileges.
- **Dependencies**:
    - `lspci` (part of `pciutils` package)
    - `dmidecode`
    - `pvesh` (Proxmox CLI tool)

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.