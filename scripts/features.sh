#!/usr/bin/env bash
set -euo pipefail
cd kernel_workspace/kernel_platform

normalize() {
  case "$1" in
    "Auto Detect") echo auto ;;
    "Enable") echo enable ;;
    "Disable") echo disable ;;
    *) echo invalid ;;
  esac
}

S="$(normalize "$SUKISU")"
F="$(normalize "$SUSFS")"
K="$(normalize "$KPM")"
B="$(normalize "$BBR")"
B3="$(normalize "$BBRV3")"
N="$(normalize "$NETSYNC")"

[[ "$S" != invalid && "$F" != invalid && "$K" != invalid && "$B" != invalid && "$B3" != invalid && "$N" != invalid ]] || exit 1

# SukiSU Ultra provides a supported source integration method. The builtin
# branch is used here because it is compatible with source-built OnePlus GKI
# trees and also exposes KPM/SUSFS integration.
if [[ "$S" == enable ]]; then
  curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s builtin
fi

CONFIG_ROOT="${KERNEL_ROOT}"
OUT="${CONFIG_ROOT}/out"
CONFIG_FILE="${CONFIG_ROOT}/arch/arm64/configs/gki_defconfig"
[[ -f "$CONFIG_FILE" ]] || CONFIG_FILE="${CONFIG_ROOT}/arch/arm64/configs/vendor/gki_defconfig"
[[ -f "$CONFIG_FILE" ]] || {
  echo "Unable to locate gki_defconfig under $CONFIG_ROOT" >&2
  exit 1
}

# Find scripts/config in the source tree.
CONFIG_TOOL=""
for p in \
  "$CONFIG_ROOT/scripts/config" \
  "$CONFIG_ROOT/scripts/kconfig/merge_config.sh"; do
  [[ -x "$p" ]] && CONFIG_TOOL="$p" && break
done

set_cfg() {
  local key="$1" val="$2"
  local tool="$CONFIG_ROOT/scripts/config"
  if [[ -x "$tool" ]]; then
    case "$val" in
      y) "$tool" --file "$CONFIG_FILE" --enable "$key" ;;
      n) "$tool" --file "$CONFIG_FILE" --disable "$key" ;;
      m) "$tool" --file "$CONFIG_FILE" --module "$key" ;;
    esac
  else
    echo "scripts/config unavailable; will validate after defconfig." >&2
  fi
}

# The manifest's gki_defconfig is the source-of-truth input for the Bazel build.
# We modify it with scripts/config so Bazel will regenerate the final .config.

# SukiSU root config.
if [[ "$S" == enable ]]; then
  grep -q '^CONFIG_KSU' "$CONFIG_FILE" || set_cfg CONFIG_KSU y
  if grep -Rqs 'config KSU_MANUAL_HOOK' "$PWD/KernelSU" 2>/dev/null; then
    set_cfg CONFIG_KSU_MANUAL_HOOK n || true
  fi
fi

if [[ "$F" == enable || "$F" == auto ]]; then
  if grep -Rqs 'config KSU_SUSFS' "$PWD/KernelSU" 2>/dev/null; then
    set_cfg CONFIG_KSU_SUSFS y
  fi
fi

# KPM is explicitly documented by SukiSU as CONFIG_KPM=y.
if [[ "$K" == enable || "$K" == auto ]]; then
  if grep -Rqs 'config KPM' "$PWD"/common "$PWD"/msm-kernel 2>/dev/null; then
    set_cfg CONFIG_KPM y
    echo "KPM=enabled" >> "$GITHUB_ENV"
  elif [[ "$K" == enable ]]; then
    echo "KPM was explicitly enabled but this source has no KPM Kconfig." >&2
    exit 1
  else
    echo "KPM=disabled" >> "$GITHUB_ENV"
  fi
else
  set_cfg CONFIG_KPM n || true
  echo "KPM=disabled" >> "$GITHUB_ENV"
fi

# BBR: use the kernel's native BBR implementation when available.
if grep -Rqs 'config TCP_CONG_BBR' "$CONFIG_ROOT/net/ipv4" "$CONFIG_ROOT/net" 2>/dev/null; then
  if [[ "$B" == enable || "$B" == auto ]]; then
    set_cfg CONFIG_TCP_CONG_BBR y
    set_cfg CONFIG_DEFAULT_BBR y || true
    echo "BBR=enabled" >> "$GITHUB_ENV"
  else
    set_cfg CONFIG_TCP_CONG_BBR n || true
    echo "BBR=disabled" >> "$GITHUB_ENV"
  fi
elif [[ "$B" == enable ]]; then
  echo "BBR was explicitly enabled but this source has no BBR Kconfig." >&2
  exit 1
else
  echo "BBR=disabled" >> "$GITHUB_ENV"
fi

# BBRv3: do not pretend BBRv1 is BBRv3. Use native CONFIG_TCP_CONG_BBR3
# when the source already provides it. For older trees, only an audited,
# version-specific backport should be enabled; this starter refuses to apply
# an unverified cross-version patch.
if grep -Rqs 'config TCP_CONG_BBR3' "$CONFIG_ROOT/net" "$CONFIG_ROOT/include" 2>/dev/null; then
  if [[ "$B3" == enable || "$B3" == auto ]]; then
    set_cfg CONFIG_TCP_CONG_BBR3 y
    echo "BBRv3=enabled" >> "$GITHUB_ENV"
  else
    set_cfg CONFIG_TCP_CONG_BBR3 n || true
    echo "BBRv3=disabled" >> "$GITHUB_ENV"
  fi
elif [[ "$B3" == enable ]]; then
  echo "BBRv3 was explicitly requested, but this kernel tree does not provide a native BBRv3 Kconfig. No unsafe generic patch will be applied." >&2
  exit 1
else
  echo "BBRv3=disabled" >> "$GITHUB_ENV"
fi

# NTSYNC is the Linux kernel feature commonly referred to as ntsync/NetSync.
if grep -Rqs 'config NTSYNC' "$CONFIG_ROOT" 2>/dev/null; then
  if [[ "$N" == enable || "$N" == auto ]]; then
    set_cfg CONFIG_NTSYNC y
    echo "NETSYNC=enabled" >> "$GITHUB_ENV"
  else
    set_cfg CONFIG_NTSYNC n || true
    echo "NETSYNC=disabled" >> "$GITHUB_ENV"
  fi
elif [[ "$N" == enable ]]; then
  echo "NetSync/NTSYNC was explicitly enabled but is not present in this source." >&2
  exit 1
else
  echo "NETSYNC=disabled" >> "$GITHUB_ENV"
fi

# SUSFS is provided through SukiSU's susfs-aware integration. If the requested
# source does not expose KSU SUSFS configs, fail only for explicit Enable.
if [[ "$F" == enable || "$F" == auto ]]; then
  if grep -Rqs 'KSU_SUSFS' "$PWD/KernelSU" "$CONFIG_ROOT" 2>/dev/null; then
    echo "SUSFS=enabled" >> "$GITHUB_ENV"
  elif [[ "$F" == enable ]]; then
    echo "SUSFS was explicitly enabled but SukiSU did not expose SUSFS Kconfig." >&2
    exit 1
  else
    echo "SUSFS=disabled" >> "$GITHUB_ENV"
  fi
else
  echo "SUSFS=disabled" >> "$GITHUB_ENV"
fi

# Resolve compiler optimization.
case "$OPTIMIZATION" in
  O2) echo 'KCFLAGS=-O2' >> "$GITHUB_ENV" ;;
  O3) echo 'KCFLAGS=-O3' >> "$GITHUB_ENV" ;;
  Oz) echo 'KCFLAGS=-Oz' >> "$GITHUB_ENV" ;;
  "Auto Detect") echo 'KCFLAGS=' >> "$GITHUB_ENV" ;;
  *) echo "Invalid compiler optimization." >&2; exit 1 ;;
esac
