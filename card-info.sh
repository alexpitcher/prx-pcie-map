#!/bin/bash
# Creative PCI Slot & Network Device Info Script with Passthrough Checks
# This script gathers detailed information about a PCI device.
# It uses dmidecode (for slot info when used interactively), lspci for device details,
# checks for associated network interfaces (and MAC addresses), verifies driver usage,
# and checks if the PCI device is used for passthrough (via mappings or VM configs).
#
# Usage:
#   sudo ./device_info.sh          # interactive mode: supply a PCI slot number.
#   sudo ./device_info.sh /all     # process all network devices (Ethernet & Network controllers) from lspci.
#
# Run as root. Inspired by Proxmox docs and built-in system tools.

# Define color codes for a better UX.
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Ensure the script is run as root.
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root.${NC}"
    exit 1
fi

# Function to check a given device by its PCI bus address.
process_device() {
    local device_bus_raw="$1"  # may be with or without leading "0000:"
    # Ensure the device bus has the "0000:" prefix.
    if [[ "$device_bus_raw" != 0000:* ]]; then
        device_bus="0000:$device_bus_raw"
    else
        device_bus="$device_bus_raw"
    fi

    echo -e "\n${GREEN}===== Device $device_bus Details =====${NC}"

    # Get one-line device details from lspci.
    DEVICE_LINE=$(lspci -s "$device_bus")
    if [[ -z "$DEVICE_LINE" ]]; then
        echo -e "${RED}No device details found for $device_bus.${NC}"
        return
    else
        echo -e "${YELLOW}lspci summary:${NC}"
        echo "$DEVICE_LINE"
    fi

    # Verbose details.
    echo -e "\n${YELLOW}Verbose lspci details:${NC}"
    lspci -v -s "$device_bus" 2>/dev/null

    # Check for network interface(s) in sysfs.
    PCI_PATH="/sys/bus/pci/devices/$device_bus"
    if [ -d "$PCI_PATH/net" ]; then
        echo -e "\n${YELLOW}Network Interface(s) Found:${NC}"
        for IFACE in "$PCI_PATH"/net/*; do
            iface=$(basename "$IFACE")
            MAC=$(cat /sys/class/net/"$iface"/address 2>/dev/null)
            echo " - Interface: ${iface}, MAC Address: ${MAC:-Unavailable}"
        done
    else
        echo -e "\n${YELLOW}No network interfaces associated with this PCI device.${NC}"
    fi

    # Check for driver information.
    if [ -L "$PCI_PATH/driver" ]; then
        DRIVER=$(basename "$(readlink -f "$PCI_PATH/driver")")
        echo -e "\n${YELLOW}Driver in use: ${NC}$DRIVER"
    else
        echo -e "\n${YELLOW}No driver information found for this device.${NC}"
    fi

    # Check if the PCI device is used for passthrough via Proxmox mappings.
    # Note: the pvesh command might require proper authentication/connection to the cluster.
    echo -e "\n${CYAN}Checking PCI resource mappings for passthrough usage...${NC}"
    # For mapping checks, remove the "0000:" prefix.
    bus_no_prefix=${device_bus#0000:}
    MAPPINGS=$(pvesh get /cluster/mapping/pci 2>/dev/null | grep "$bus_no_prefix")
    if [[ -z "$MAPPINGS" ]]; then
        echo -e "${YELLOW}No PCI mappings found using device $bus_no_prefix.${NC}"
    else
        echo -e "${GREEN}Found the following PCI mapping(s):${NC}"
        echo "$MAPPINGS"
    fi

    # Check VM configurations for PCI passthrough usage.
    echo -e "\n${CYAN}Checking VM configuration for PCI passthrough usage...${NC}"
    VM_USAGE=$(grep -R "hostpci.*$bus_no_prefix" /etc/pve/qemu-server/ 2>/dev/null)
    if [[ -z "$VM_USAGE" ]]; then
        echo -e "${YELLOW}No VM configuration found using PCI device $bus_no_prefix.${NC}"
    else
        echo -e "${GREEN}Found PCI passthrough usage in VM config(s):${NC}"
        echo "$VM_USAGE"
    fi

    echo -e "\n${CYAN}Completed checks for device $device_bus.${NC}"
}

# If the first argument is "/all", process all network devices.
if [ "$1" == "/all" ]; then
    echo -e "${CYAN}Processing all network devices (Ethernet and Network controllers) from lspci...${NC}"
    # Use grep to filter for Ethernet controllers or Network controllers.
    lspci | grep -E "Ethernet controller|Network controller" | while read -r line; do
        # The first token in the lspci output is the PCI bus address.
        pci_id=$(echo "$line" | awk '{print $1}')
        echo -e "\n${GREEN}Found device: $pci_id  ${NC}"
        process_device "$pci_id"
    done
    exit 0
fi

# --- Interactive Mode (by Slot) ---
# This branch uses dmidecode to get slot details and then determines the PCI bus from there.

# Temporary file for slot info.
SLOT_INFO_FILE="/tmp/slot_info.txt"

echo -e "${CYAN}Fetching PCI slot information using dmidecode...${NC}"
dmidecode -t slot > "$SLOT_INFO_FILE" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to retrieve slot information. Make sure dmidecode is installed and run as root.${NC}"
    exit 1
fi

# Prompt user for a slot number.
read -p "Enter the PCI slot number to inspect (or type 'exit' to quit): " SLOT
if [[ "$SLOT" == "exit" ]]; then
    echo -e "${YELLOW}Exiting.${NC}"
    exit 0
fi

# Extract slot details.
SLOT_BLOCK=$(awk "/Slot ${SLOT}/{flag=1} flag && /^$/ {flag=0} flag" "$SLOT_INFO_FILE")
if [[ -z "$SLOT_BLOCK" ]]; then
    echo -e "${RED}No information found for Slot $SLOT. Verify the slot number and try again.${NC}"
    exit 1
fi

echo -e "\n${GREEN}===== Slot $SLOT Details =====${NC}"
echo "$SLOT_BLOCK"
echo -e "${GREEN}===============================${NC}\n"

# Extract the Bus Address (if available)
BUS_ADDR=$(echo "$SLOT_BLOCK" | grep "Bus Address:" | awk '{print $3}')
if [[ -z "$BUS_ADDR" ]]; then
    echo -e "${RED}Bus Address not found in the slot details.${NC}"
    exit 1
fi

# Remove the '0000:' prefix if present.
DEVICE_BUS=${BUS_ADDR#0000:}
echo -e "${YELLOW}PCI Bus Address: ${DEVICE_BUS}${NC}"

# Process this device.
process_device "$DEVICE_BUS"