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
FRAGMENT_FILE="${CONFIG_ROOT}/arch/arm64/configs/oneplus_features_defconfig"
FRAGMENT_LABEL="//common:oneplus_features_defconfig"

# Kleaf/GKI verifies the base gki_defconfig with savedefconfig. Never edit that
# file directly. Feature changes belong in a Kleaf defconfig fragment.
mkdir -p "$(dirname "$FRAGMENT_FILE")"
: > "$FRAGMENT_FILE"

add_cfg() {
  local key="$1" value="$2"
  case "$value" in
    y) printf 'CONFIG_%s=y\n' "${key#CONFIG_}" >> "$FRAGMENT_FILE" ;;
    m) printf 'CONFIG_%s=m\n' "${key#CONFIG_}" >> "$FRAGMENT_FILE" ;;
    n) printf '# CONFIG_%s is not set\n' "${key#CONFIG_}" >> "$FRAGMENT_FILE" ;;
  esac
}

has_symbol() {
  local symbol="$1"
  grep -RqsE "^[[:space:]]*config[[:space:]]+${symbol#CONFIG_}([[:space:]]|$)" \
    "$CONFIG_ROOT" "$PWD/KernelSU" 2>/dev/null
}

# SukiSU/SUSFS source integration must happen before feature detection.
if [[ "$S" == enable ]]; then
  echo "[+] Setting up SukiSU..."
  curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s builtin
fi

# SukiSU source integration can add Kconfig files after setup.
if [[ "$S" == enable ]]; then
  has_symbol CONFIG_KSU || {
    echo "SukiSU setup completed but CONFIG_KSU was not found." >&2
    exit 1
  }
  add_cfg CONFIG_KSU y
fi

if [[ "$F" == enable || "$F" == auto ]]; then
  if has_symbol CONFIG_KSU_SUSFS; then
    add_cfg CONFIG_KSU_SUSFS y
  elif [[ "$F" == enable ]]; then
    echo "SUSFS was explicitly enabled but CONFIG_KSU_SUSFS is unavailable." >&2
    exit 1
  fi
fi

# KPM is optional. Explicit Disable is represented only when the symbol exists.
if has_symbol CONFIG_KPM; then
  case "$K" in
    enable) add_cfg CONFIG_KPM y; echo "KPM=enabled" >> "$GITHUB_ENV" ;;
    disable) add_cfg CONFIG_KPM n; echo "KPM=disabled" >> "$GITHUB_ENV" ;;
    auto) add_cfg CONFIG_KPM y; echo "KPM=enabled" >> "$GITHUB_ENV" ;;
  esac
else
  if [[ "$K" == enable ]]; then
    echo "KPM was explicitly enabled but CONFIG_KPM is unavailable." >&2
    exit 1
  fi
  echo "KPM=disabled" >> "$GITHUB_ENV"
fi

# Native BBR only. Auto Detect enables it when the selected kernel exposes it.
if grep -RqsE '^[[:space:]]*config[[:space:]]+TCP_CONG_BBR([[:space:]]|$)' \
    "$CONFIG_ROOT/net" 2>/dev/null; then
  case "$B" in
    enable|auto)
      add_cfg CONFIG_TCP_CONG_BBR y
      if grep -RqsE '^[[:space:]]*config[[:space:]]+DEFAULT_BBR([[:space:]]|$)' "$CONFIG_ROOT" 2>/dev/null; then
        add_cfg CONFIG_DEFAULT_BBR y
      fi
      echo "BBR=enabled" >> "$GITHUB_ENV" ;;
    disable)
      add_cfg CONFIG_TCP_CONG_BBR n
      if grep -RqsE '^[[:space:]]*config[[:space:]]+DEFAULT_BBR([[:space:]]|$)' "$CONFIG_ROOT" 2>/dev/null; then
        add_cfg CONFIG_DEFAULT_BBR n
      fi
      echo "BBR=disabled" >> "$GITHUB_ENV" ;;
  esac
elif [[ "$B" == enable ]]; then
  echo "BBR was explicitly enabled but the kernel has no native BBR Kconfig." >&2
  exit 1
else
  echo "BBR=disabled" >> "$GITHUB_ENV"
fi

# BBRv3 is enabled only when this source already provides its Kconfig.
if grep -RqsE '^[[:space:]]*config[[:space:]]+TCP_CONG_BBR3([[:space:]]|$)' \
    "$CONFIG_ROOT/net" "$CONFIG_ROOT/include" 2>/dev/null; then
  case "$B3" in
    enable|auto) add_cfg CONFIG_TCP_CONG_BBR3 y; echo "BBRv3=enabled" >> "$GITHUB_ENV" ;;
    disable) add_cfg CONFIG_TCP_CONG_BBR3 n; echo "BBRv3=disabled" >> "$GITHUB_ENV" ;;
  esac
elif [[ "$B3" == enable ]]; then
  echo "BBRv3 was explicitly requested, but this kernel tree has no native BBRv3 Kconfig. No generic backport will be applied." >&2
  exit 1
else
  echo "BBRv3=disabled" >> "$GITHUB_ENV"
fi

# NetSync option maps to the kernel's NTSYNC Kconfig when present.
if grep -RqsE '^[[:space:]]*config[[:space:]]+NTSYNC([[:space:]]|$)' \
    "$CONFIG_ROOT" 2>/dev/null; then
  case "$N" in
    enable|auto) add_cfg CONFIG_NTSYNC y; echo "NETSYNC=enabled" >> "$GITHUB_ENV" ;;
    disable) add_cfg CONFIG_NTSYNC n; echo "NETSYNC=disabled" >> "$GITHUB_ENV" ;;
  esac
elif [[ "$N" == enable ]]; then
  echo "NetSync/NTSYNC was explicitly enabled but CONFIG_NTSYNC is unavailable." >&2
  exit 1
else
  echo "NETSYNC=disabled" >> "$GITHUB_ENV"
fi

case "$OPTIMIZATION" in
  O2) echo 'KCFLAGS=-O2' >> "$GITHUB_ENV" ;;
  O3) echo 'KCFLAGS=-O3' >> "$GITHUB_ENV" ;;
  Oz) echo 'KCFLAGS=-Oz' >> "$GITHUB_ENV" ;;
  "Auto Detect") echo 'KCFLAGS=' >> "$GITHUB_ENV" ;;
  *) echo "Invalid compiler optimization." >&2; exit 1 ;;
esac

# Make the fragment visible to the //common package. This is the only source
# tree metadata change needed for the command-line Kleaf fragment flag.
if [[ -f "$CONFIG_ROOT/BUILD.bazel" ]] && ! grep -q 'oneplus_features_defconfig' "$CONFIG_ROOT/BUILD.bazel"; then
  printf '\nexports_files(["arch/arm64/configs/oneplus_features_defconfig"])\n' >> "$CONFIG_ROOT/BUILD.bazel"
fi

printf '%s\n' "[+] Generated Kleaf feature fragment:" "$FRAGMENT_FILE"
cat "$FRAGMENT_FILE"
echo "FEATURE_FRAGMENT_LABEL=$FRAGMENT_LABEL" >> "$GITHUB_ENV"
