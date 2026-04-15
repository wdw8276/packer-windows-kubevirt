# Packer Images for Windows on KubeVirt

Builds Windows 11 images specially adapted for [KubeVirt](https://kubevirt.io/).

Supported editions:
- Windows 11 23H2 Enterprise Evaluation
- Windows 11 LTSC 2024
- Windows 11 25H2 Pro

## Features

- VirtIO drivers (see table below)
- QEMU Guest Agent
- CloudBase-Init for cloud-init integration
- WinFsp + VirtIO-FS service
- SPICE Guest Agent
- RDP enabled
- OpenSSH Server enabled
- Sysprep on first boot (post-sysprep lock file mechanism)
- Output in compressed qcow2 format

## Installed Drivers and Components

| Name | Type | Description |
|---|---|---|
| NetKVM | VirtIO driver | Paravirtualized network adapter |
| vioscsi | VirtIO driver | Paravirtualized SCSI controller |
| vioserial | VirtIO driver | Paravirtualized serial port |
| viostor | VirtIO driver | Paravirtualized block storage |
| viorng | VirtIO driver | Paravirtualized random number generator |
| Balloon | VirtIO driver | Memory balloon (dynamic memory management) |
| viofs | VirtIO driver | VirtIO filesystem (shared folder support) |
| QEMU Guest Agent | Service | Guest-host communication (shutdown, snapshot, etc.) |
| CloudBase-Init | Service | Cloud-init integration for first-boot configuration |
| WinFsp | Runtime | Windows filesystem proxy, required by VirtIO-FS |
| VirtIO-FS Service | Service | Mounts VirtIO-FS shared directories |
| SPICE Guest Agent | Agent | Clipboard sharing, display resolution with SPICE display |

## Prerequisites

- QEMU with KVM support
- Packer 1.9.4 or above
- `virt-sparsify` (for image compression)
- `ovmf` (UEFI firmware, required for LTSC 2024 build)

## Preparing ISO Files

Place the following ISO files in the `iso/` directory before building.
The `iso/` directory is listed in `.gitignore` and is not committed to the repository.

### Windows 11 23H2 Enterprise Evaluation

| Field | Value |
|---|---|
| Filename | `Windows_11_23H2_EnterpriseEval_x64.iso` |
| Edition | Windows 11 Enterprise Evaluation (23H2) |
| Size | 5.8 GB |
| SHA256 | `c8dbc96b61d04c8b01faf6ce0794fdf33965c7b350eaa3eb1e6697019902945c` |

Download from [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise).

### Windows 11 LTSC 2024

| Field | Value |
|---|---|
| Filename | `en-us_windows_11_enterprise_ltsc_2024_x64_dvd_965cfb00.iso` |
| Edition | Windows 11 Enterprise LTSC 2024 |
| Size | 4.8 GB |
| SHA256 | `157d8365a517c40afeb3106fdd74d0836e1025debbc343f2080e1a8687607f51` |

Available through Microsoft Volume Licensing or MSDN/Visual Studio subscriptions.

### Windows 11 25H2 Pro

| Field | Value |
|---|---|
| Filename | `Win11_25H2_English_x64_v2.iso` |
| Edition | Windows 11 Pro (25H2) |

Download from [Microsoft](https://www.microsoft.com/en-us/software-download/windows11).

## Building

Initialize plugins before the first build:

```bash
packer init win11_23h2_eval_kubevirt.pkr.hcl
```

Build all images:

```bash
make
```

Build a specific image:

```bash
make win11_23h2_eval_kubevirt WINRM_PASSWORD=<password>
make win11_ltsc_2024_kubevirt WINRM_PASSWORD=<password>
make win11_25h2_pro_kubevirt  WINRM_PASSWORD=<password>
```

### Build Variables

| Variable | Default | Description |
|---|---|---|
| `WINRM_PASSWORD` | *(required)* | WinRM / local account password |
| `TIMEZONE` | `China Standard Time` | Windows timezone |
| `HEADLESS` | `true` | Run QEMU without display (`false` for debugging) |
| `PACKER_LOG` | `0` | Set to `1` to enable verbose Packer logging |

Example:

To change the default WinRM password and timezone:

```bash
make WINRM_PASSWORD=mysecret TIMEZONE="UTC" win11_23h2_eval_kubevirt
```

To enable debug logging and show the QEMU window during build:

```bash
make PACKER_LOG=1 HEADLESS=false win11_23h2_eval_kubevirt
```

### How It Works

Before each build, Makefile generates the Autounattend XML files from templates
(`answer_files/**/*.xml.tmpl`) by substituting `WINRM_PASSWORD` and `TIMEZONE`.
The generated XML files are not committed to the repository.

## Sysprep Lock File

A file `C:\not-yet-finished` is created during provisioning and deleted after
sysprep completes. Check for its absence to confirm the image is fully prepared.

## Cleaning Up

```bash
make clean
```

Removes build output directories and generated XML files.
