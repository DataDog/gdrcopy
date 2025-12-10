#! /bin/bash

set -euxo pipefail

# Read optional overrides from extra args
# Supported forms:
#   --driver-branch <num> | --driver-branch=<num> | DRIVER_BRANCH=<num>
#   --kernel-module-type <auto|open|proprietary> | --kernel-module-type=<auto|open|proprietary> | KERNEL_MODULE_TYPE=<auto|open|proprietary>
_parse_args() {
  # Seed with env (if provided)
  local _driver_branch="${DRIVER_BRANCH:-}"
  local _kernel_module_type="${KERNEL_MODULE_TYPE:-auto}"

  while (($#)); do
    case "$1" in
      --driver-branch)
        shift
        _driver_branch="${1:-}"
        ;;
      --driver-branch=*)
        _driver_branch="${1#*=}"
        ;;
      --kernel-module-type)
        shift
        _kernel_module_type="${1:-}"
        ;;
      --kernel-module-type=*)
        _kernel_module_type="${1#*=}"
        ;;
      DRIVER_BRANCH=*)
        _driver_branch="${1#*=}"
        ;;
      KERNEL_MODULE_TYPE=*)
        _kernel_module_type="${1#*=}"
        ;;
      *)
        # ignore unrelated args
        ;;
    esac
    shift || true
  done

  # Export final values
  DRIVER_BRANCH="${_driver_branch}"
  KERNEL_MODULE_TYPE="${_kernel_module_type}"
}

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

_install_prerequisites() {
    echo "Installing Linux kernel headers"
    apt-get -qq install --no-install-recommends \
    linux-headers-${CKMB_KERNEL_FULL_VERSION} \
    nvidia-kernel-source-${DRIVER_BRANCH}${KERNEL_SUFFIX} \
    > /dev/null
}

_build() {
    make driver KVER=${CKMB_KERNEL_FULL_VERSION}
    cp src/gdrdrv/gdrdrv.ko gdrdrv.ko
}

main() {
  _parse_args "$@"

  # Validate required/optional variables after parsing args
  if [ -z "${DRIVER_BRANCH:-}" ]; then
    echo "Missing driver branch" >&2
    exit 1
  fi
  KERNEL_MODULE_TYPE="${KERNEL_MODULE_TYPE:-auto}"
  _resolve_kernel_suffix || exit 1

  _install_prerequisites
  _build
}

main "$@"
