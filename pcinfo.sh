#!/bin/bash
# Enhanced PCI Device Information and Passthrough Checker Script
# This script gathers detailed information about PCI devices,
# but only displays those that are Ethernet or Network controllers.
#
# Modes (one-letter abbreviations available):
#   /h or /help       : Show help.
#   /a or /all        : Process all network devices (from lspci, filtered to network devices).
#   /s or /slot <n>   : Process a specific PCI slot using dmidecode.
#   /p or /pci <id>   : Process a specific PCI device (e.g., 0000:c2:00.0 or 0000:e3:00.{0-3}).
#   /l or /list       : List all PCI devices (grouped by base); default mode.
#
# Display flags (one-letter abbreviations; if none are provided, all are enabled):
#   /m or /mapping    : Show PCI resource mapping info.
#   /v or /vms        : Show VM passthrough usage info.
#   /n or /net        : Show network interface info.
#   /d or /driver     : Show driver info.
#   /V or /verbose    : Enable verbose lspci output.
#
# Output redirection:
#   /o or /output <path> : Redirect output to the given file (plaintext).
#
# Multi‑port grouping is automatic: devices sharing the same base address (domain:bus:device)
# are grouped; common details are printed only once (from the first port),
# then each port’s mapping/VM info is printed (labeled as Port 1, Port 2, etc.).
#
# IMPORTANT: Only devices that are Ethernet or Network controllers (per lspci) will be shown.
#
# Run as root.

# Define color codes.
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Ensure running as root.
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root.${NC}"
    exit 1
fi

############################################
# Defaults: If no display flag is provided, enable ALL.
############################################
FLAG_MAPPING=
FLAG_VMS=
FLAG_NET=
FLAG_DRIVER=
FLAG_VERBOSE=
DISPLAY_FLAGS_PROVIDED=0

############################################
# Mode selection variables.
############################################
MODE_ALL=0
MODE_SLOT=0
MODE_PCI=0
MODE_LIST=0
SLOT_VAL=""
PCI_VAL=""

# Output file variable.
OUTPUT_FILE=""

############################################
# Parse arguments (supporting one-letter abbreviations)
############################################
while [[ $# -gt 0 ]]; do
    case "$1" in
        /h|/help)
            echo -e "${CYAN}Usage: $0 [options]${NC}"
            echo "Modes:"
            echo "  /h or /help           : Show help."
            echo "  /a or /all            : Process all network devices (from lspci)."
            echo "  /s or /slot <n>       : Process a specific PCI slot using dmidecode."
            echo "  /p or /pci <id>       : Process a specific PCI device (e.g., 0000:c2:00.0 or 0000:e3:00.{0-3})."
            echo "  /l or /list           : List all PCI devices (grouped by base). [Default mode]"
            echo "Display flags (if none are provided, ALL are enabled):"
            echo "  /m or /mapping        : Show PCI mapping info."
            echo "  /v or /vms            : Show VM passthrough usage info."
            echo "  /n or /net            : Show network interface info."
            echo "  /d or /driver         : Show driver info."
            echo "  /V or /verbose        : Enable verbose lspci output."
            echo "Output redirection:"
            echo "  /o or /output <path>   : Redirect output to the given file (plaintext)."
            exit 0
            ;;
        /a|/all)
            MODE_ALL=1
            shift
            ;;
        /s|/slot)
            MODE_SLOT=1
            SLOT_VAL="$2"
            shift 2
            ;;
        /p|/pci)
            MODE_PCI=1
            PCI_VAL="$2"
            shift 2
            ;;
        /l|/list)
            MODE_LIST=1
            shift
            ;;
        /m|/mapping)
            FLAG_MAPPING=1
            DISPLAY_FLAGS_PROVIDED=1
            shift
            ;;
        /v|/vms)
            FLAG_VMS=1
            DISPLAY_FLAGS_PROVIDED=1
            shift
            ;;
        /n|/net)
            FLAG_NET=1
            DISPLAY_FLAGS_PROVIDED=1
            shift
            ;;
        /d|/driver)
            FLAG_DRIVER=1
            DISPLAY_FLAGS_PROVIDED=1
            shift
            ;;
        /V|/verbose)
            FLAG_VERBOSE=1
            DISPLAY_FLAGS_PROVIDED=1
            shift
            ;;
        /o|/output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# If no mode flag is provided, default to /list.
if [ $MODE_ALL -eq 0 ] && [ $MODE_SLOT -eq 0 ] && [ $MODE_PCI -eq 0 ] && [ $MODE_LIST -eq 0 ]; then
    MODE_LIST=1
fi

# If no display flag was provided, set defaults (all enabled).
if [ $DISPLAY_FLAGS_PROVIDED -eq 0 ]; then
    FLAG_MAPPING=1
    FLAG_VMS=1
    FLAG_NET=1
    FLAG_DRIVER=1
    FLAG_VERBOSE=1
fi

# If output file is specified, redirect output.
if [[ -n "$OUTPUT_FILE" ]]; then
    exec > "$OUTPUT_FILE" 2>&1
fi

############################################
# Function: is_network_device
# Returns 0 if the device (by its full PCI address) is an Ethernet or Network controller.
############################################
is_network_device() {
    local devbus="$1"
    local summary
    summary=$(lspci -s "$devbus")
    echo "$summary" | grep -q -E "Ethernet controller|Network controller"
}

############################################
# Utility function: Group PCI devices by base (domain:bus:device)
############################################
group_pci_devices() {
    local -n in_array=$1
    declare -A groups
    for addr in "${in_array[@]}"; do
        base="${addr%.*}"
        groups["$base"]+="$addr "
    done
    echo "$(declare -p groups)"
}

############################################
# Functions to Process PCI Devices
############################################

# Print common details for a given PCI device.
process_common() {
    local device_bus="$1"  # full PCI address with 0000: prefix
    if ! is_network_device "$device_bus"; then
        echo -e "${RED}Device $device_bus is not an Ethernet or Network controller. Skipping.${NC}"
        return 1
    fi
    echo -e "\n${GREEN}===== Device $device_bus Common Details =====${NC}"
    DEVICE_LINE=$(lspci -s "$device_bus")
    if [[ -z "$DEVICE_LINE" ]]; then
        echo -e "${RED}No device details found for $device_bus.${NC}"
        return 1
    else
        echo -e "${YELLOW}lspci summary:${NC}"
        echo "$DEVICE_LINE"
    fi
    if [ $FLAG_VERBOSE -eq 1 ]; then
        echo -e "\n${YELLOW}Verbose lspci details:${NC}"
        lspci -v -s "$device_bus" 2>/dev/null
    fi
    if [ $FLAG_NET -eq 1 ]; then
        PCI_PATH="/sys/bus/pci/devices/$device_bus"
        if [ -d "$PCI_PATH/net" ]; then
            echo -e "\n${YELLOW}Network Interface(s) Found:${NC}"
            for IFACE in "$PCI_PATH"/net/*; do
                iface=$(basename "$IFACE")
                MAC=$(cat /sys/class/net/"$iface"/address 2>/dev/null)
                echo " - Interface: ${iface}, MAC Address: ${MAC:-Unavailable}"
                # Extra section: check if the interface is enslaved to vmbr0.
                if ip -o link show "$iface" 2>/dev/null | grep -q "master vmbr0"; then
                    echo "   -> Interface ${iface} is bridged on vmbr0."
                fi
            done
        else
            echo -e "\n${YELLOW}No network interfaces associated with this device.${NC}"
        fi
    fi
    if [ $FLAG_DRIVER -eq 1 ]; then
        PCI_PATH="/sys/bus/pci/devices/$device_bus"
        if [ -L "$PCI_PATH/driver" ]; then
            DRIVER=$(basename "$(readlink -f "$PCI_PATH/driver")")
            echo -e "\n${YELLOW}Driver in use: ${NC}$DRIVER"
        else
            echo -e "\n${YELLOW}No driver information found for this device.${NC}"
        fi
    fi
}

# Print mapping and VM passthrough details.
process_mapping_vm() {
    local device_bus="$1"
    local bus_no_prefix=${device_bus#0000:}
    echo -e "\n${CYAN}Checking PCI resource mappings for passthrough usage on $device_bus...${NC}"
    MAPPINGS=$(pvesh get /cluster/mapping/pci 2>/dev/null | grep "$bus_no_prefix")
    if [[ -z "$MAPPINGS" ]]; then
        echo -e "${YELLOW}No PCI mappings found for $bus_no_prefix.${NC}"
    else
        echo -e "${GREEN}Found PCI mapping(s):${NC}"
        echo "$MAPPINGS"
    fi
    echo -e "\n${CYAN}Checking VM configuration for PCI passthrough usage on $device_bus...${NC}"
    VM_USAGE=$(grep -R "hostpci.*$bus_no_prefix" /etc/pve/qemu-server/ 2>/dev/null)
    if [[ -z "$VM_USAGE" ]]; then
        echo -e "${YELLOW}No VM configuration found for PCI device $bus_no_prefix.${NC}"
    else
        echo -e "${GREEN}Found PCI passthrough usage in VM config(s):${NC}"
        echo "$VM_USAGE"
    fi
}

# Process a group of PCI devices.
# The common details (from the first port) are printed once, then each port’s mapping/VM info is printed.
process_group() {
    local base="$1"
    shift
    local ports=("$@")
    echo -e "\n${GREEN}######## Group for base [$base] ########${NC}"
    echo -e "${GREEN}Common details (from first port: ${ports[0]}):${NC}"
    if ! process_common "${ports[0]}"; then
        echo -e "${RED}Skipping group for base [$base] as the device is not a network controller.${NC}"
        return
    fi
    for idx in "${!ports[@]}"; do
        port_label=$((idx+1))
        echo -e "\n${CYAN}--- Port ${port_label} (${ports[$idx]}) - Mapping & VM passthrough details ---${NC}"
        process_mapping_vm "${ports[$idx]}"
    done
    echo -e "\n${CYAN}######## End of Group for base [$base] ########${NC}"
}

############################################
# Mode Handling
############################################

# MODE_ALL: Process all network devices from lspci.
if [ $MODE_ALL -eq 1 ]; then
    echo -e "${CYAN}Processing all network devices (Ethernet & Network controllers) from lspci...${NC}"
    mapfile -t all_lines < <(lspci | grep -E "Ethernet controller|Network controller")
    devices=()
    for line in "${all_lines[@]}"; do
        pci_id=$(echo "$line" | awk '{print $1}')
        devices+=("$pci_id")
    done
    eval "$(group_pci_devices devices)"
    for base in "${!groups[@]}"; do
        read -ra group_ports <<< "${groups[$base]}"
        process_group "$base" "${group_ports[@]}"
    done
    exit 0
fi

# MODE_SLOT: Process a specific PCI slot using dmidecode.
if [ $MODE_SLOT -eq 1 ]; then
    SLOT_INFO_FILE="/tmp/slot_info.txt"
    echo -e "${CYAN}Fetching PCI slot information using dmidecode...${NC}"
    dmidecode -t slot > "$SLOT_INFO_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to retrieve slot information. Ensure dmidecode is installed and run as root.${NC}"
        exit 1
    fi
    SLOT_BLOCK=$(awk "/Slot ${SLOT_VAL}/{flag=1} flag && /^$/ {flag=0} flag" "$SLOT_INFO_FILE")
    if [[ -z "$SLOT_BLOCK" ]]; then
        echo -e "${RED}No information found for Slot $SLOT_VAL. Verify the slot number and try again.${NC}"
        exit 1
    fi
    echo -e "\n${GREEN}===== Slot $SLOT_VAL Details =====${NC}"
    echo "$SLOT_BLOCK"
    echo -e "${GREEN}===============================${NC}\n"
    BUS_ADDR=$(echo "$SLOT_BLOCK" | grep "Bus Address:" | awk '{print $3}')
    if [[ -z "$BUS_ADDR" ]]; then
        echo -e "${RED}Bus Address not found in the slot details.${NC}"
        exit 1
    fi
    device_bus=${BUS_ADDR#0000:}
    echo -e "${YELLOW}PCI Bus Address: ${device_bus}${NC}"
    if ! is_network_device "0000:${device_bus}"; then
        echo -e "${RED}The device at 0000:${device_bus} is not a network controller. Exiting.${NC}"
        exit 1
    fi
    process_mapping_vm "0000:${device_bus}"
    exit 0
fi

# MODE_PCI: Process a specific PCI device.
if [ $MODE_PCI -eq 1 ]; then
    if [[ "$PCI_VAL" =~ \{.*\} ]]; then
        ports=( $(eval echo "$PCI_VAL") )
    else
        base="${PCI_VAL%.*}"
        mapfile -t ports < <(lspci | awk -v b="$base" '$1 ~ "^"b"\\." {print $1}')
        if [ ${#ports[@]} -eq 0 ]; then
            ports=("$PCI_VAL")
        fi
    fi
    if ! is_network_device "${ports[0]}"; then
        echo -e "${RED}Device ${ports[0]} is not an Ethernet or Network controller. Exiting.${NC}"
        exit 1
    fi
    base="${ports[0]%%.*}"
    process_group "$base" "${ports[@]}"
    exit 0
fi

# MODE_LIST: Default mode: list all network devices (grouped by base) from lspci.
if [ $MODE_LIST -eq 1 ]; then
    echo -e "${CYAN}Listing all network devices from lspci (grouped by base)...${NC}"
    mapfile -t all_lines < <(lspci | grep -E "Ethernet controller|Network controller")
    devices=()
    for line in "${all_lines[@]}"; do
        pci_id=$(echo "$line" | awk '{print $1}')
        devices+=("$pci_id")
    done
    eval "$(group_pci_devices devices)"
    for base in "${!groups[@]}"; do
        read -ra group_ports <<< "${groups[$base]}"
        process_group "$base" "${group_ports[@]}"
    done
    exit 0
fi

echo -e "${RED}No valid mode selected. Use /h for help.${NC}"
exit 1