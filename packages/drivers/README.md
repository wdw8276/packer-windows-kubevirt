# Driver Sources

The drivers in this directory were extracted from the official virtio-win ISO:

- **ISO**: `virtio-win-0.1.266.iso`
- **Source**: https://github.com/virtio-win/virtio-win-pkg-scripts

## Extracted Drivers

| Driver | Path in ISO | Description |
|--------|-------------|-------------|
| NetKVM | `NetKVM/w11/amd64/` | VirtIO network driver |
| vioscsi | `vioscsi/w11/amd64/` | VirtIO SCSI controller driver |
| vioserial | `vioserial/w11/amd64/` | VirtIO serial port driver |
| viostor | `viostor/w11/amd64/` | VirtIO block storage driver |
| viorng | `viorng/w11/amd64/` | VirtIO random number generator driver |
| Balloon | `Balloon/w11/amd64/` | VirtIO memory balloon driver |
| viofs | `viofs/w11/amd64/` | VirtIO filesystem driver |

## Updating Drivers

To update to a newer virtio-win release:

1. Download the new ISO from https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md
2. Mount the ISO and copy the updated files from each driver's `w11/amd64/` subdirectory
3. Update the ISO version in this file
