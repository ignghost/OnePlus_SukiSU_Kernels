#!/usr/bin/env bash
set -euo pipefail
cd "$GITHUB_WORKSPACE"

mkdir -p "out/${ARTIFACT_NAME}"

IMAGE="$(find kernel_workspace/kernel_platform/out -type f \
  \( -name Image -o -name Image.lz4 -o -name Image.gz -o -name Image.gz-dtb \) \
  | head -n1 || true)"

[[ -n "$IMAGE" ]] || { echo "No kernel image found." >&2; exit 1; }

cp "$IMAGE" "out/${ARTIFACT_NAME}/"

cat > "out/${ARTIFACT_NAME}/build-info.txt" <<EOF
Device: ${DEVICE_NAME}
Device ID: ${DEVICE_ID}
CPU: ${CPU}
Manifest branch: ${MANIFEST_BRANCH}
Manifest: ${MANIFEST}
Kernel: ${KERNEL_VERSION}
SukiSU: ${SUKISU}
SUSFS: ${SUSFS}
KPM: ${KPM}
BBR: ${BBR}
BBRv3: ${BBRV3}
NetSync/NTSYNC: ${NETSYNC}
Optimization: ${OPTIMIZATION}
CCache: ${CCACHE_MODE}
Commit: ${GITHUB_SHA}
EOF

# Include AnyKernel3 source as a reproducible packaging payload. Device-specific
# boot/container logic remains in the verified profile rather than being guessed.
git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "out/${ARTIFACT_NAME}/AnyKernel3"
cp "$IMAGE" "out/${ARTIFACT_NAME}/AnyKernel3/Image"
cat > "out/${ARTIFACT_NAME}/AnyKernel3/build-info.txt" <<EOF
${DEVICE_NAME}
Kernel: ${KERNEL_VERSION}
SukiSU: ${SUKISU}
SUSFS: ${SUSFS}
KPM: ${KPM}
BBR: ${BBR}
BBRv3: ${BBRV3}
NetSync: ${NETSYNC}
EOF
rm -rf "out/${ARTIFACT_NAME}/AnyKernel3/.git"
