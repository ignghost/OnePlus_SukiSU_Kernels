#!/usr/bin/env bash
set -euo pipefail
cd kernel_workspace/kernel_platform

export PATH="/usr/lib/ccache:$PATH"
export ARCH=arm64
export LLVM=1
export LLVM_IAS=1

if [[ "$CCACHE_MODE" == "Use CCache" ]]; then
  export CCACHE_DIR="$HOME/.cache/ccache"
  mkdir -p "$CCACHE_DIR"
fi

if [[ "$BUILD_SYSTEM" == bazel ]]; then
  mkdir -p "$PWD/out/dist"
  if [[ "$KERNEL_VERSION" == 6.12* ]]; then
    tools/bazel run --config=fast --config=stamp \
      --//build/kernel/kleaf:defconfig_fragment="$FEATURE_FRAGMENT_LABEL" \
      --verbose_failures \
      //common:kernel_aarch64_dist -- --destdir="$PWD/out/dist"
  else
    tools/bazel run --config=fast --config=stamp \
      --//build/kernel/kleaf:defconfig_fragment="$FEATURE_FRAGMENT_LABEL" \
      --verbose_failures \
      //common:kernel_aarch64_dist -- --destdir="$PWD/out/dist"
  fi
elif [[ "$BUILD_SYSTEM" == buildsh ]]; then
  if [[ -f build/build.sh ]]; then
    BUILD_CONFIG="${BUILD_CONFIG:-common/build.config.gki.aarch64}" \
      LTO=thin \
      OUT_DIR="$PWD/out" \
      build/build.sh -j"$(nproc)"
  else
    echo "build.sh is unavailable." >&2
    exit 1
  fi
fi
