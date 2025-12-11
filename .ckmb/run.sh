#! /bin/bash

set -euxo pipefail

NVIDIA_DRIVER_ROOT=${NVIDIA_DRIVER_ROOT:-"/run/nvidia/driver"}

_unload_driver() {
    local gdrdrv_refs=0

    if [ -f /sys/module/gdrdrv/refcnt ]; then
        gdrdrv_refs=$(< /sys/module/gdrdrv/refcnt)
    fi

    if [ ${gdrdrv_refs} -gt 0 ]; then
        # run lsmod to debug module usage
        lsmod | grep gdrdrv
        echo "Could not unload gdrdrv kernel module, module is in use" >&2
        return 1
    fi

    rmmod gdrdrv
    return 0
}

_create_inode() {
    major=$(grep -F gdrdrv /proc/devices | cut -b 1-4)
    echo "INFO: driver major is $major"

    if [ -e "$NVIDIA_DRIVER_ROOT/dev/gdrdrv" ]; then
        rm "$NVIDIA_DRIVER_ROOT/dev/gdrdrv"
    fi

    echo "INFO: creating $NVIDIA_DRIVER_ROOT/dev/gdrdrv inode"
    mknod "$NVIDIA_DRIVER_ROOT/dev/gdrdrv" c $major 0
    chmod a+w+r "$NVIDIA_DRIVER_ROOT/dev/gdrdrv"
}

install() {
    echo "Unloading gdrdrv kernel module"
    _unload_driver || exit 1

    echo "Creating device inode"
    _create_inode

    echo "Done, now waiting for signal"
    sleep infinity &
    trap "echo 'Caught signal'; _unload_driver && { kill $!; exit 0; }" HUP INT QUIT PIPE TERM
    trap - EXIT
    while true; do wait $! || continue; done
    exit 0
}

install
