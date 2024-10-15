#!/bin/bash

MEMORY=2048
CORE=2
DEST=local-lvm
DISK_SIZE=30
DISK_NAME=vmdisk
DISK_ID=$DEST:$DISK_NAME
DISK_DEVICE=scsi0
START=True
HOSTBOOT=True
IP=""
GATEWAY=""
NAMESERVER=""

usage() {
    echo "Usage: $0 [-p /path/to/image] [-n name] [-a ip] [-i id]"
    echo "Options (required):"
    echo "  -p(--path): path to image."
    echo "  -n(--name): name of the VM you want to create."
    echo "  -i(--id): ID of the VM you want to create."
    echo "Options (optional):"
    echo "  -c(--cpu): number of CPU cores. (default - 2)"
    echo "  -a(--ip): IPv4 address of the VM you want to create in CIDR notation. NOTE: setting the gateway is required if using this option. (default - DHCP)"
    echo "  -g(--gateway): gateway IPv4 address of the VM you want to create. NOTE: setting the IP address is required if using this option. (default - DHCP)"
    echo "  -m(--memory): amount of RAM in MB. (default - 2048)"
    echo "  -s(--nostart): does not start the VM after creation. (default - false)"
    echo "  -b(--noboot): does not automatically start the VM when the host system boots. (default - false)"
    echo "  -h(--help): display this help and exit."
    echo "  -d(--disksize): disk size in GB. (default - 30G)"
    echo "  -ns(--nameserver): IP address of the nameserver. (default - uses host's)"
    echo "  -dev(--networkdev): specify network devices to include."
    exit 1
}

required=("ID" "NAME" "IMAGE")

check_arg() {
    if [ -z "$2" ]; then
        echo "Error: $1 requires an argument."
        exit 1
    fi
}
check_vars() {
    for option in "${required[@]}"; do
        if [ -z "${!option}" ]; then
            echo "Error: $option is required."
            exit 1
        fi
    done
}
menu() {
    while [ $# -gt 0 ]; do
        case $1 in
            # Required arguments
            -i | --id)
                check_arg $1 $2
                ID=$2
                shift 2
                ;;
            -n | --name)
                check_arg $1 $2
                NAME=$2
                shift 2
                ;;
            -p | --path)
                check_arg $1 $2
                IMAGE=$2
                shift 2
                ;;
            # Optional arguments
            -c | --cpu)
                check_arg $1 $2
                CPU=$2
                shift 2
                ;;
            -m | --memory)
                check_arg $1 $2
                MEMORY=$2
                shift 2
                ;;
            -a | --ip)
                check_arg $1 $2
                IP=$2
                shift 2
                ;;
            -ns | --nameserver)
                check_arg $1 $2
                NAMESERVER=$2
                shift 2
                ;;
            -g | --gateway)
                check_arg $1 $2
                GATEWAY=$2
                shift 2
                ;;
            -s | --nostart)
                START=False
                shift
                ;;
            -b | --noboot)
                HOSTBOOT=False
                shift
                ;;
            -h | --help)
                usage
                exit 1
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    main
}

main() {
    check_vars
    create_vm
}

create_vm() {
    cp $IMAGE /var/lib/vz/template/iso/
    ISO_NAME=$(echo "$IMAGE" | awk -F/ '{print $NF}')

    qm create $ID --memory $MEMORY --core $CORE --name $NAME 
    echo "VM created:"
    echo "IMAGE: $IMAGE"
    echo "ID: $ID"
    echo "NAME: $NAME"
    echo "CPU: $CORE"
    echo "MEMORY: $MEMORY"

    if [ "$HOSTBOOT" == "True" ]; then
        qm set $ID -onboot 1
        echo "HOSTBOOT: True - VM will automatically start with host boot"
    fi
    if [ "$IP" != "" ] && [ "$GATEWAY" != "" ]; then
        qm set $ID -ipconfig0 ip=$IP,gw=$GATEWAY
        echo "IP: $IP - GATEWAY: $GATEWAY"
    fi
    if [ "$NAMESERVER" != "" ]; then
        qm set $ID --nameserver $NAMESERVER
        echo "NAMESERVER: $NAMESERVER"
    fi

    qm set $ID --scsi0 $DEST:${DISK_SIZE}
    qm set $ID -efidisk0 $DEST:${DISK_SIZE},efitype=4m
    qm set $ID -machine q35
    qm set $ID --agent enabled=1
    
    qm set $ID --ide2 local:iso/$ISO_NAME,media=cdrom
    qm set $ID --boot order=ide2
    echo "ISO successfully mounted"

    # UEFI, machine -> q35, QEMU agent, bridge/network device

    if [ "$START" == "True" ]; then
        qm start $ID
        echo "Starting VM..."
    else
        echo "NOTE: You have disabled automatic startup after install. 
        This may result in you having to manually swap the boot order."
    fi

    # Automatically switches the boot order from ide2 (the iso) to scsi0 (the disk)
    # For this to work properly, shutoff after install has to be enabled in cloud-config (user-data)
    while true; do
        VM_STATE=$(qm status $ID | awk '{print $2}')
        if [ "$VM_STATE" == "stopped" ]; then
            echo "Installation complete. Changing boot order..."
            qm set $ID --boot order=scsi0
            echo "Boot order changed. Starting VM..."
            qm start $ID
            echo "VM started. Done!"
            break
        fi
        echo "Waiting for installation to complete..."
        sleep 30
    done

}

if [ $# -eq 0 ]; then
    usage
else
    menu "$@"
fi