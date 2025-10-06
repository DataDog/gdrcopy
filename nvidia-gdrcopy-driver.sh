#! /bin/bash

set -eux

DRIVER_BRANCH=${DRIVER_BRANCH:?"Missing driver branch"}
KERNEL_MODULE_TYPE=${KERNEL_MODULE_TYPE:-auto}
NVIDIA_DRIVER_ROOT=${NVIDIA_DRIVER_ROOT:-"/run/nvidia/driver"}
KERNEL_VERSION=$(uname -r)

# Following function is inspired by the ubuntu22.04/precompiled/nvidia-driver script from the DataDog/gpu-driver-container repository
# _resolve_kernel_suffix determines if the "-open" kernel suffix should be applied.
#
# KERNEL_MODULE_TYPE is the frontend interface that users can use to configure which module
# to install. Valid values for KERNEL_MODULE_TYPE are 'auto' (default), 'open', and 'proprietary'.
# When 'auto' is configured, we resolve from the driver branch.
_resolve_kernel_suffix() {
  if [ "${KERNEL_MODULE_TYPE}" == "proprietary" ]; then
    KERNEL_SUFFIX=""
  elif [ "${KERNEL_MODULE_TYPE}" == "open" ]; then
    KERNEL_SUFFIX="-open"
  elif [ "${KERNEL_MODULE_TYPE}" == "auto" ]; then
    [[ "${DRIVER_BRANCH}" -lt 560 ]] && KERNEL_SUFFIX="" || KERNEL_SUFFIX="-open"
  else
    echo "invalid value for the KERNEL_MODULE_TYPE variable: ${KERNEL_MODULE_TYPE}"
    return 1
  fi
}

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

_install_prerequisites() {
    echo "Installing Linux kernel headers"
    apt-get -qq install --no-install-recommends \
    linux-headers-${KERNEL_VERSION} \
    nvidia-kernel-source-${DRIVER_BRANCH}${KERNEL_SUFFIX} \
    > /dev/null
}

_build_and_load() {
    cd /work/build
    dpkg -i gdrdrv-dkms_*_*.deb

    depmod -a
    modprobe gdrdrv
}

install() {
    # Determine the kernel suffix from $KERNEL_MODULE_TYPE
    _resolve_kernel_suffix || exit 1

    echo "Unloading gdrdrv kernel module"
    _unload_driver || exit 1

    echo "Updating the package cache"
    apt-get update -qq

    echo "Installing prerequisites"
    _install_prerequisites

    echo "Building and loading gdrdrv kernel module"
    _build_and_load

    echo "Done, now waiting for signal"
    sleep infinity &
    trap "echo 'Caught signal'; _unload_driver && { kill $!; exit 0; }" HUP INT QUIT PIPE TERM
    trap - EXIT
    while true; do wait $! || continue; done
    exit 0
}

usage() {
    cat >&2 <<EOF
Usage: $0 COMMAND [ARG...]

Commands:
  install - install the gdrcopy kernel-mode driver and create the gdrdrv device node
EOF
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi
command=$1; shift
case "${command}" in
    install) ;;
    *) usage ;;
esac
if [ $? -ne 0 ]; then
    usage
fi

$command
