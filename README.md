```md
# PCI Resource Mapping Tools

This repository contains scripts to assist with PCI resource mapping and slot information retrieval, particularly useful for Proxmox environments.

## Scripts

### `card-info.sh`
A script to gather detailed information about a specified PCI slot. It uses `dmidecode` for slot information, `lspci` for device details, and checks for associated network interfaces and drivers.

#### Features:
- Fetches PCI slot details using `dmidecode`.
- Displays device details using `lspci`.
- Identifies associated network interfaces and drivers.

#### Usage:
Run the script as root:
```bash
sudo ./card-info.sh
```

### `prx-pcie-map.sh`
A script to create PCI resource mappings in Proxmox based on user input. It uses `dmidecode` and `lspci` to gather slot and device details.

#### Features:
- Displays PCI slot information.
- Prompts for mapping parameters to create Proxmox PCI mappings.
- Executes the mapping command using `pvesh`.

#### Usage:
Run the script as root:
```bash
sudo ./prx-pcie-map.sh
```

## Requirements
- `dmidecode`
- `lspci`
- Proxmox environment for `prx-pcie-map.sh`

## License
This project is licensed under the MIT License.
```