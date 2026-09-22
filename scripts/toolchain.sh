#!/usr/bin/env bash
set -euo pipefail

# The initial scaffold uses the runner's LLVM/Clang toolchain.
# Replace this with the exact vendor toolchain required by each verified
# device profile when the source matrix is populated.

command -v clang
clang --version
