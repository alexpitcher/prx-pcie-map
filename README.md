# Proxmox PCI Resource Mapping Tools

This repository contains scripts to assist with managing PCI devices in a Proxmox environment. These tools provide detailed information about PCI devices, help with resource mapping, and facilitate VM passthrough configuration.

## Scripts Overview

### 1. `card-info.sh`
This script provides enhanced PCI device information and checks for VM passthrough usage. It supports various modes for listing, filtering, and analyzing PCI devices.

#### Key Features:
- **Modes**:
    - `/all`: Process all network devices (Ethernet & Network controllers).
    - `/slot`: Process a specific PCI slot using `dmidecode`.
    - `/pci`: Process a specific PCI device.
    - `/list`: List all PCI devices (default mode).
- **Display Flags**:
    - `/mapping`: Show PCI resource mapping info.
    - `/vms`: Show VM passthrough usage info.
    - `/net`: Show network interface info.
    - `/driver`: Show driver info.
    - `/verbose`: Enable verbose `lspci` output.
- **Output Redirection**:
    - `/output <path>`: Redirect output to a file.

#### Usage:
Run the script as root and use the appropriate flags to retrieve the desired information.

---

### 2. `prx-pcie-map.sh`
This script simplifies the process of creating PCI resource mappings in Proxmox.

#### Key Features:
- Fetches PCI slot information using `dmidecode`.
- Displays detailed device information using `lspci`.
- Allows interactive creation of PCI mappings for Proxmox.

#### Usage:
Run the script as root and follow the interactive prompts to map PCI devices.

---

## Requirements
- `dmidecode`: For retrieving slot information.
- `lspci`: For detailed PCI device information.
- Proxmox environment with `pvesh` command-line tool.

## Getting Started
1. Clone this repository to your Proxmox server.
2. Ensure the scripts have executable permissions:
     ```bash
     chmod +x card-info.sh prx-pcie-map.sh
     ```
3. Run the scripts as root to explore their functionality.

## License
This project is licensed under the MIT License. See the `LICENSE` file for details.

## Contributing
Contributions are welcome! Please submit a pull request or open an issue for any improvements or bug fixes.

---