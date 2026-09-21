#!/usr/bin/env bash
set -euo pipefail
cd kernel_workspace/kernel_platform

if [[ -d common ]]; then
  KERNEL_ROOT="$PWD/common"
elif [[ -d msm-kernel ]]; then
  KERNEL_ROOT="$PWD/msm-kernel"
else
  echo "Unable to locate kernel root." >&2
  exit 1
fi

echo "KERNEL_ROOT=$KERNEL_ROOT" >> "$GITHUB_ENV"

if [[ -f "$KERNEL_ROOT/Makefile" ]]; then
  KV="$(awk -F= '/^VERSION/{v=$2} /^PATCHLEVEL/{p=$2} /^SUBLEVEL/{s=$2} END{gsub(/ /,"",v);gsub(/ /,"",p);gsub(/ /,"",s); print v"."p"."s}' "$KERNEL_ROOT/Makefile")"
  echo "KERNEL_VERSION=$KV" >> "$GITHUB_ENV"
  echo "Detected kernel: $KV"
fi

if [[ -x tools/bazel ]]; then
  echo "BUILD_SYSTEM=bazel" >> "$GITHUB_ENV"
elif [[ -f build/build.sh ]]; then
  echo "BUILD_SYSTEM=buildsh" >> "$GITHUB_ENV"
else
  echo "No supported OnePlus build system found." >&2
  exit 1
fi
