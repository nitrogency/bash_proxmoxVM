#!/bin/bash

OPTSTRING=":p:n:a:i:"

MEMORY=2048
CORE=2
DEST=local
DISK_SIZE=+45G
DISK_NAME=vm-$ID-disk-0
DISK_ID=$DEST:$DISK_NAME
DISK_DEVICE=scsi0
START=True
HOSTBOOT=True
IP=""
GATEWAY=""

usage() {
  echo "Usage: $0 [-p /path/to/image] [-n name] [-a ip] [-i id]"
  echo "Options (required):"
  echo "  -p(--path): path to image"
  echo "  -n(--name): name of the VM you want to create"
  echo "  -i(--id): ID of the VM you want to create"
  echo "Options (optional):"
  echo "  -c(--cpu): number of CPU cores (default - 2)"
  echo "  -a(--ip): IPv4 address of the VM you want to create in CIDR notation (default - auto)"
  echo "  -g(--gateway): gateway IPv4 address of the VM you want to create (default - auto)"
  echo "  -m(--memory): amount of RAM in MB (default - 2048)"
  echo "  -s(--nostart): does not start the VM after creation (default - false)"
  echo "  -b(--noboot): does not automatically start the VM when the host system boots (default - false)"
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
    if [ "$START" == "True" ]; then
        qm start $ID
    fi
    if [ "$HOSTBOOT" == "True" ]; then
        qm set $ID -onboot 1
    fi
    if [ "$IP" != "" ] && [ "$GATEWAY" != "" ]; then
        qm set $ID -ipconfig0 ip=$IP,gw=$GATEWAY
    fi
    
    qm set $ID --ide2 local:iso/$ISO_NAME,media=cdrom
    qm set $ID --boot order=ide2
}

if [ $# -eq 0 ]; then
    usage
else
    menu "$@"
fi