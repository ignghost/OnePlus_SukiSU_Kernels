#!/usr/bin/env bash
set -euo pipefail

cd kernel

if [[ -z "${KERNEL_DEFCONFIG:-}" ]]; then
  echo "KERNEL_DEFCONFIG is not set" >&2
  exit 1
fi

make O="$PWD/out" ARCH=arm64 "$KERNEL_DEFCONFIG"
