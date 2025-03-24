#!/bin/bash
# Proxmox PCI Resource Mapping Script
# This script uses dmidecode to display slot information, uses lspci to get device details,
# and then creates a PCI resource mapping in Proxmox based on user input.
# Documentation: https://pve.proxmox.com/wiki/QEMU/KVM_Virtual_Machines#resource_mapping

# Ensure the script is run as root.
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Temporary file to store slot info.
SLOT_INFO_FILE="/tmp/slot_info.txt"

# Fetch and save the slot information.
echo "Fetching PCI slot information..."
dmidecode -t slot > "$SLOT_INFO_FILE"

# Main loop: allow user to process each populated slot.
while true; do
    echo ""
    read -p "Enter slot number to map (or type 'exit' to quit): " SLOT
    if [[ "$SLOT" == "exit" ]]; then
        echo "Exiting."
        exit 0
    fi

    # Extract the block of information for the specified slot.
    SLOT_BLOCK=$(awk "/Slot ${SLOT}/{flag=1} flag && /^$/ {flag=0} flag" "$SLOT_INFO_FILE")
    
    if [[ -z "$SLOT_BLOCK" ]]; then
        echo "No information found for Slot $SLOT. Please check the slot number."
        continue
    fi

    echo "--------------------------"
    echo "Details for Slot $SLOT:"
    echo "--------------------------"
    echo "$SLOT_BLOCK"
    echo "--------------------------"

    # Extract Bus Address from the SLOT_BLOCK
    BUS_ADDR=$(echo "$SLOT_BLOCK" | grep "Bus Address:" | awk '{print $3}')
    # Remove the '0000:' prefix if present
    DEVICE_BUS=${BUS_ADDR#0000:}

    # Use lspci to get device details based on the bus address
    DEVICE_DETAILS=$(lspci | grep "$DEVICE_BUS")

    if [[ -z "$DEVICE_DETAILS" ]]; then
        echo "No device details found for Bus Address $BUS_ADDR."
    else
        echo "Device details from lspci:"
        echo "$DEVICE_DETAILS"
    fi
    echo "--------------------------"

    # Prompt the user for mapping parameters.
    read -p "Enter a name for this PCI mapping: " MAP_NAME
    read -p "Enter the Proxmox node name: " NODE_NAME
    read -p "Enter the PCI path (e.g., 0000:01:00.0): " PCI_PATH
    read -p "Enter the device ID (vendor:device, e.g., 0002:0001): " DEVICE_ID

    # Build the mapping command.
    CMD="pvesh create /cluster/mapping/pci --id ${MAP_NAME} --map node=${NODE_NAME},path=${PCI_PATH},id=${DEVICE_ID}"
    echo ""
    echo "Executing command:"
    echo "$CMD"
    echo ""

    # Execute the command.
    eval "$CMD"
    
    echo ""
    read -p "Mapping complete for Slot $SLOT. Do you want to map another slot? (y/n): " CONTINUE
    if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
        echo "Exiting."
        exit 0
    fi

done