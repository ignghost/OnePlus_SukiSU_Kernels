# OnePlus Universal Kernel Builder

GitHub Actions-only multi-device kernel builder for OnePlus/Ace devices.

## Current source integration

The builder uses the official `OnePlusOSS/kernel_manifest` repository and
device-specific manifest branches/files rather than guessing a single kernel
repository. The current database covers the verified manifest mappings for:

- OnePlus 10 Pro
- OnePlus 10T
- OnePlus 11 / 11R
- OnePlus 12 / 12R
- OnePlus 13 / 13R
- OnePlus 15
- Ace 2 / Ace 2 Pro
- Ace 3 / Ace 3V / Ace 3 Pro
- Ace 5 / Ace 5 Pro

Ace 2V remains intentionally unverified until its exact current manifest/source
line is confirmed.

## Build selection

- Single Device
- Multiple Devices using comma-separated IDs
- All Supported Devices

Example:

```text
oneplus11,oneplus12,oneplus13,oneplus13r,ace5pro
```

## Features

- SukiSU: Enable / Disable
- SUSFS: Auto Detect / Enable / Disable
- KPM: Auto Detect / Enable / Disable
- BBR: Auto Detect / Enable / Disable
- BBRv3: Auto Detect / Enable / Disable
- NetSync/NTSYNC: Auto Detect / Enable / Disable
- Compiler optimization: Auto Detect / O2 / O3 / Oz
- CCache: Clean Build / Use CCache

OverlayFS is intentionally not included.

## Feature safety

The resolver never treats BBRv1 as BBRv3. BBRv3 is enabled only when the
selected source exposes a compatible `CONFIG_TCP_CONG_BBR3` implementation.
An explicit request fails instead of applying an unverified cross-kernel patch.

SukiSU is integrated using its documented source setup method. KPM is enabled
only when the source exposes its Kconfig. SUSFS is verified after SukiSU
integration.

## Important

A kernel compiling successfully does not mean its boot/vendor-DLKM contract
is safe for every firmware revision. OnePlus GKI builds are version-sensitive.
Keep source, modules, DTBO/vendor_boot and firmware contracts matched to the
device before flashing.

This repository currently produces and verifies the kernel artifact. AnyKernel3
boot packaging should be added only after each device's exact boot-container
layout has been verified.

## Sources

- OnePlusOSS/kernel_manifest
- SukiSU-Ultra
- susfs4ksu
- Google BBR

Respect each upstream project's license.
