#!/usr/bin/env bash

show_help() {
    echo "Usage: ${0##*/} [-h] [-u cloudimgurl] [-p rootpw] [-a pve_alias] [-s pve_shell] [-t pve_storage] [-i template_id] [-m vm_mem] [-c vm_cpu]"
    echo
    echo "Description:"
    echo " This script downloads a cloud image of your choosing, installs a qemu-agent for Proxmox, sets a root password, installs it as a cloud_init template in your proxmox envirionment."
    echo
    echo "Options:"
    echo "  -u    URL to cloud image (default: https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img)"
    echo "  -p    Root Password for Cloud Image"
    echo "  -a    Address of the Proxmox Node"
    echo "  -s    Shell for Proxmox (default: /bin/bash)"
    echo "  -t    Local storage where we import template"
    echo "  -i    ID for template VM"
    echo "  -m    Memory for VM (MB)"
    echo "  -c    CPU cores for VM"
    echo "  -h    Show this help message"
    echo
}

cloudimgurl="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
pve_shell="/bin/bash"

while getopts "hu:p:a:s:t:i:m:c:" opt; do
    case ${opt} in
        h)
            show_help
            exit 0
            ;;
        u)
            cloudimgurl=$OPTARG
            ;;
        p)
            rootpw=$OPTARG
            ;;
        a)
            pve_alias=$OPTARG
            ;;
        s)
            pve_shell=$OPTARG
            ;;
        t)
            pve_storage=$OPTARG
            ;;
        i)
            template_id=$OPTARG
            ;;
        m)
            vm_mem=$OPTARG
            ;;
        c)
            vm_cpu=$OPTARG
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
done

# Check for missing arguments and prompt the user if necessary
if [ -z "$rootpw" ]; then
    read -sp "Enter Root Password for Cloud Image: " rootpw
    echo
fi

if [ -z "$pve_alias" ]; then 
    read -p "Enter the address of the Proxmox Node: " pve_alias
fi

if [ -z "$pve_storage" ]; then
    read -p "Enter local storage where we import template: " pve_storage
fi

if [ -z "$template_id" ]; then
    read -p "Specify ID for template VM: " template_id
fi

if [ -z "$vm_cpu" ]; then
    read -p "Specify CPU cores for VM: " vm_cpu
fi

if [ -z "$vm_mem" ]; then
    read -p "Specify memory for VM (MB): " vm_mem
fi

wget  $cloudimgurl
cloudimg=$(echo $cloudimgurl | rev | cut-d/ -f 1 | rev)
cloud_template="$(echo $img_name | rev | cut -d. -f2- | rev)-cloudinit-template"
#Install Shit directly into image

sudo apt update -y && sudo apt install libguestfs-tools -y

sudo virt-customize -a $cloudimg --install qemu-guest-agent
sudo virt-customize -a $cloudimg --root-password password:"${rootpw}"

sftp ${pve_alias} <<< "put ${cloudimg}"

ssh ${pve_alias} ${pve_shell} << EOF
qm create 9000 --name "${cloud_template}" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 ${cloudimg} ${pve_storage}
qm set 9000 --scsihw virtio-scsi-pci --scsi0 ${pve_storage}:vm-9000-disk-0
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --ide2 ${pve_storage}:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1
EOF