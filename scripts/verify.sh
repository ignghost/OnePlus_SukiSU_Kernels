#!/usr/bin/env bash
set -euo pipefail
cd kernel_workspace/kernel_platform

IMAGE=""
for p in \
  "$PWD/out/dist/Image" \
  "$PWD/out/dist/Image.lz4" \
  "$PWD/out/Image" \
  "$PWD/out/dist/Image.gz" \
  "$PWD/out/dist/Image.gz-dtb"; do
  if [[ -f "$p" ]]; then IMAGE="$p"; break; fi
done

[[ -n "$IMAGE" ]] || {
  echo "ERROR: no kernel image produced." >&2
  find out -type f | head -200 || true
  exit 1
}

echo "Kernel image: $IMAGE"

CONFIG=""
for p in "$PWD/out/common/.config" "$PWD/out/dist/.config" "$PWD/common/out/.config" "$PWD/out/.config"; do
  [[ -f "$p" ]] && CONFIG="$p" && break
done

if [[ -n "$CONFIG" ]]; then
  echo "Final feature configuration:"
  grep -E 'CONFIG_(KSU|KPM|KSU_SUSFS|TCP_CONG_BBR|TCP_CONG_BBR3|DEFAULT_BBR|NTSYNC)' "$CONFIG" || true

  [[ "${SUKISU}" == "Disable" || "$(grep -c '^CONFIG_KSU=y' "$CONFIG" || true)" -gt 0 ]] || {
    echo "SukiSU was requested but CONFIG_KSU=y was not found." >&2
    exit 1
  }

  [[ "${KPM}" == "Disable" || "${KPM}" == "Auto Detect" || "$(grep -c '^CONFIG_KPM=y' "$CONFIG" || true)" -gt 0 ]] || {
    echo "KPM was requested but CONFIG_KPM=y was not found." >&2
    exit 1
  }

  if [[ "${BBR}" == "Enable" ]]; then
    grep -q '^CONFIG_TCP_CONG_BBR=y' "$CONFIG" || {
      echo "BBR requested but CONFIG_TCP_CONG_BBR=y is missing." >&2
      exit 1
    }
  fi

  if [[ "${BBRV3}" == "Enable" ]]; then
    grep -q '^CONFIG_TCP_CONG_BBR3=y' "$CONFIG" || {
      echo "BBRv3 requested but CONFIG_TCP_CONG_BBR3=y is missing." >&2
      exit 1
    }
  fi

  if [[ "${NETSYNC}" == "Enable" ]]; then
    grep -q '^CONFIG_NTSYNC=y' "$CONFIG" || {
      echo "NetSync/NTSYNC requested but CONFIG_NTSYNC=y is missing." >&2
      exit 1
    }
  fi
fi
