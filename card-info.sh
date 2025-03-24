#!/bin/bash
# Creative PCI Slot Information and Usage Checker Script
# This script gathers detailed information about a specified PCI slot.
# It uses dmidecode for slot info, lspci for device details, checks for
# associated network interfaces (and MAC addresses), verifies driver usage,
# and checks if the PCI device is used for passthrough (via mappings or VM configs).
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

# Temporary file for slot info.
SLOT_INFO_FILE="/tmp/slot_info.txt"

# Refresh slot info from dmidecode.
echo -e "${CYAN}Fetching PCI slot information...${NC}"
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

# Get device details via lspci.
DEVICE_DETAILS=$(lspci | grep "$DEVICE_BUS")
if [[ -z "$DEVICE_DETAILS" ]]; then
    echo -e "${RED}No device details found for Bus Address $BUS_ADDR.${NC}"
else
    echo -e "${YELLOW}Device Details (lspci):${NC}"
    echo "$DEVICE_DETAILS"
fi

# Optionally, get verbose details for the device.
echo -e "\n${YELLOW}Verbose Device Details:${NC}"
lspci -v -s 0000:"$DEVICE_BUS" 2>/dev/null

# Check for network interface association.
PCI_PATH="/sys/bus/pci/devices/0000:$DEVICE_BUS"
if [ -d "$PCI_PATH/net" ]; then
    echo -e "\n${YELLOW}Network Interface(s) Found:${NC}"
    for IFACE in "$PCI_PATH"/net/*; do
        iface=$(basename "$IFACE")
        MAC=$(cat /sys/class/net/"$iface"/address 2>/dev/null)
        echo " - Interface: ${iface}, MAC Address: ${MAC:-Unavailable}"
    done
else
    echo -e "\n${YELLOW}No network interfaces associated with this PCI slot.${NC}"
fi

# Check for driver information.
if [ -L "$PCI_PATH/driver" ]; then
    DRIVER=$(basename "$(readlink -f "$PCI_PATH/driver")")
    echo -e "\n${YELLOW}Driver in use: ${NC}$DRIVER"
else
    echo -e "\n${YELLOW}No driver information found for this device.${NC}"
fi

# --- Check if the PCI device is used for passthrough ---

# 1. Check Proxmox PCI resource mappings.
echo -e "\n${CYAN}Checking PCI resource mappings for passthrough usage...${NC}"
# pvesh command output (if available) might list the device mapping.
MAPPINGS=$(pvesh get /cluster/mapping/pci 2>/dev/null | grep "$DEVICE_BUS")
if [[ -z "$MAPPINGS" ]]; then
    echo -e "${YELLOW}No PCI mappings found using device $DEVICE_BUS.${NC}"
else
    echo -e "${GREEN}Found the following PCI mapping(s):${NC}"
    echo "$MAPPINGS"
fi

# 2. Check VM configurations for PCI passthrough usage.
echo -e "\n${CYAN}Checking VM configuration for PCI passthrough usage...${NC}"
VM_USAGE=$(grep -R "hostpci.*$DEVICE_BUS" /etc/pve/qemu-server/ 2>/dev/null)
if [[ -z "$VM_USAGE" ]]; then
    echo -e "${YELLOW}No VM configuration found using PCI device $DEVICE_BUS.${NC}"
else
    echo -e "${GREEN}Found PCI passthrough usage in VM config(s):${NC}"
    echo "$VM_USAGE"
fi

echo -e "\n${CYAN}All available data for PCI slot $SLOT has been gathered.${NC}"