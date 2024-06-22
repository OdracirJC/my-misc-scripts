#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' 

usage() {
  printf "${RED}Usage: $0 CLOUDIMGLINK VMID VMNAME LOCALSTR BRIDGE MODEL${NC}\n"
  exit 1
}

if [ "$#" -ne 6 ]; then
  usage
fi

CLOUDIMGLINK=$1
VMID=$2
VMNAME=$3
LOCALSTR=$4
BRIDGE=$5
MODEL=$6

# Extract the ISO file name from the cloud image link
ISOFILE=$(echo $CLOUDIMGLINK | rev | cut -d/ -f1 | rev)

# Download the cloud image
printf "${YELLOW}Downloading cloud image...${NC}\n"
wget -qO "${ISOFILE}" "${CLOUDIMGLINK}"

# Create the VM
printf "${YELLOW}Creating VM with ID $VMID and name $VMNAME...${NC}\n"
qm create $VMID --name $VMNAME --net0 "${MODEL},bridge=${BRIDGE}"

# Import the disk
printf "${YELLOW}Importing disk...${NC}\n"
qm importdisk $VMID $ISOFILE $LOCALSTR

# Set VM disk
printf "${YELLOW}Configuring VM disk...${NC}\n"
qm set $VMID --scsihw virtio-scsi-pci --scsi0 "${LOCALSTR}:vm-${VMID}-disk-0"

# Attach Cloud-Init disk
printf "${YELLOW}Attaching Cloud-Init disk...${NC}\n"
qm set $VMID --ide2 "${LOCALSTR}:cloudinit"

# Set boot options
printf "${YELLOW}Setting boot options...${NC}\n"
qm set $VMID --boot c --bootdisk scsi0

# Configure serial console
printf "${YELLOW}Configuring serial console...${NC}\n"
qm set $VMID --serial0 socket --vga serial0

printf "${GREEN}VM $VMID ($VMNAME) has been successfully created and configured.${NC}\n"
