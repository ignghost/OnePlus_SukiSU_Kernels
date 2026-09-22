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
  grep -RqsE "^[[:space:]]*(config|menuconfig)[[:space:]]+${symbol#CONFIG_}([[:space:]]|$)" \
    "$CONFIG_ROOT" --include='Kconfig*' 2>/dev/null
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

# BBRv3 is NEVER backported generically. Only use a native symbol already
# present in this kernel tree. Auto Detect safely skips unsupported BBRv3.
BBR3_SYMBOL=""
for candidate in TCP_CONG_BBR3 TCP_CONG_BBR_V3 TCP_CONG_BBRV3; do
  if has_symbol "CONFIG_${candidate}"; then
    BBR3_SYMBOL="$candidate"
    break
  fi
done

if [[ -n "$BBR3_SYMBOL" ]]; then
  case "$B3" in
    enable|auto)
      add_cfg "CONFIG_${BBR3_SYMBOL}" y
      echo "BBRv3=enabled" >> "$GITHUB_ENV"
      ;;
    disable)
      add_cfg "CONFIG_${BBR3_SYMBOL}" n
      echo "BBRv3=disabled" >> "$GITHUB_ENV"
      ;;
  esac
else
  case "$B3" in
    enable)
      echo "ERROR: BBRv3 was explicitly enabled, but this kernel tree has no native BBRv3 Kconfig." >&2
      echo "       No generic or unverified BBRv3 backport will be applied." >&2
      echo "       Select BBRv3=Auto Detect or BBRv3=Disable." >&2
      exit 1
      ;;
    auto|disable)
      echo "[i] BBRv3: native support not found; skipping." 
      echo "BBRv3=disabled" >> "$GITHUB_ENV"
      ;;
  esac
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

# Make the fragment a real Bazel target in the //common package.
# Kleaf's --defconfig_fragment expects a label, so the file must be declared
# by the package BUILD file.
BUILD_FILE="$CONFIG_ROOT/BUILD.bazel"
if [[ ! -f "$BUILD_FILE" ]]; then
  echo "ERROR: common/BUILD.bazel was not found at $BUILD_FILE" >&2
  exit 1
fi

if ! grep -qE 'name[[:space:]]*=[[:space:]]*"oneplus_features_defconfig"' "$BUILD_FILE"; then
  cat >> "$BUILD_FILE" <<'EOF'

# Generated by the OnePlus Universal Kernel workflow.
exports_files([
    "arch/arm64/configs/oneplus_features_defconfig",
])
EOF
fi

if ! grep -q 'oneplus_features_defconfig' "$BUILD_FILE"; then
  echo "ERROR: failed to declare oneplus_features_defconfig in common/BUILD.bazel" >&2
  exit 1
fi

printf '%s\n' "[+] Generated Kleaf feature fragment:" "$FRAGMENT_FILE"
cat "$FRAGMENT_FILE"
echo "FEATURE_FRAGMENT_LABEL=$FRAGMENT_LABEL" >> "$GITHUB_ENV"

# Bazel recursively evaluates common/** and must not encounter self-referential
# links. Fail early with a useful message if one remains.
if [[ -L "KernelSU/kernel/kernel" ]]; then
  echo "ERROR: SukiSU left a recursive KernelSU/kernel/kernel symlink: $(readlink KernelSU/kernel/kernel)" >&2
  rm -f "KernelSU/kernel/kernel"
fi

if find . -type l -print0 | xargs -0 -r -n1 readlink | grep -qE '(^|/)KernelSU/kernel/?$'; then
  echo "[+] KernelSU symlink audit completed."
fi
