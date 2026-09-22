#!/usr/bin/env bash
set -euo pipefail

rm -rf kernel_workspace
mkdir -p kernel_workspace

# GitHub-hosted runners may provide a non-writable /usr/bin/repo.
export PATH="$HOME/bin:$PATH"
mkdir -p "$HOME/bin"
if [[ ! -x "$HOME/bin/repo" ]]; then
  curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
  chmod +x "$HOME/bin/repo"
fi

cd kernel_workspace

repo init \
  -u https://github.com/OnePlusOSS/kernel_manifest.git \
  -b "refs/heads/${MANIFEST_BRANCH}" \
  -m "${MANIFEST}" \
  --depth=1 \
  --no-repo-verify

repo sync -c -j"$(nproc)" --no-tags --force-sync

test -d kernel_platform || {
  echo "ERROR: kernel_platform was not produced by the manifest." >&2
  exit 1
}

cd kernel_platform

# Remove the exact recursive link that can be left by a previous/incomplete
# SukiSU setup. Never remove a real KernelSU/kernel directory.
if [[ -L "KernelSU/kernel/kernel" ]]; then
  target="$(readlink "KernelSU/kernel/kernel" || true)"
  case "$target" in
    ""|kernel|../kernel|*"/KernelSU/kernel")
      echo "[+] Removing stale recursive KernelSU/kernel/kernel -> $target"
      rm -f "KernelSU/kernel/kernel"
      ;;
  esac
fi

# GKI protected exports can block SUSFS/KSU modules on Android 14+.
find common msm-kernel -type f \
  -name 'abi_gki_protected_exports_*' \
  -delete 2>/dev/null || true
