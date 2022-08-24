#!/usr/bin/env bash
#
# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

[ "$DEBUG" == 'true' ] && set -x

scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)/..
# shellcheck disable=SC1091,SC1090
source "$scripts_dir"/vm/vm_default_variables.sh

SHARED_VOLUME=${SHARED_VOLUME:-.}
DRIVE_TO_BOOT=${DRIVE_TO_BOOT:-${SHARED_VOLUME}/vm.qcow2}
HOST_TARGET_SERVICE_PORT=${HOST_TARGET_SERVICE_PORT:-50051}
HOST_TARGET_SERVICE_PORT_IN_VM=${HOST_TARGET_SERVICE_PORT_IN_VM:-50051}

qemu_serial="-serial stdio"
if [ -n "$UNIX_SERIAL" ]; then
  qemu_serial="-serial unix:${SHARED_VOLUME}/${UNIX_SERIAL},server,nowait"
fi

export DRIVE_TO_BOOT
export HOST_TARGET_SERVICE_PORT_IN_VM
"${scripts_dir}"/vm/prepare_vm.sh
"${scripts_dir}"/allocate_hugepages.sh

run_vm="sudo qemu-system-x86_64 \
  ${qemu_serial} \
  -m 1G -object memory-backend-file,id=mem0,size=1G,mem-path=/dev/hugepages,share=on -numa node,memdev=mem0 \
  -smp 2 \
  -drive file=${DRIVE_TO_BOOT},if=none,id=disk \
  -device ide-hd,drive=disk,bootindex=0 \
  -device pci-bridge,chassis_nr=1,id=${IPDK_PCI_BRIDGE_0} \
  -device pci-bridge,chassis_nr=2,id=${IPDK_PCI_BRIDGE_1} \
  -net nic,model=e1000 \
  -net user,hostfwd=tcp::${HOST_TARGET_SERVICE_PORT}-:${HOST_TARGET_SERVICE_PORT_IN_VM} \
  -qmp tcp:${DEFAULT_QMP_ADDRESS}:${DEFAULT_QMP_PORT},server,wait=off \
  --nographic \
  $*"

$run_vm
