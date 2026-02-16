# Fleur de Lys

*"If you wish to make an apple pie from scratch, first invent the universe." -- Carl Sagan*

Fleur de Lys is a Linux distribution built from scratch, following the Linux From Scratch methodology. The system is assembled inside a disk image and developed through a chroot environment on the host machine.

## Disk Layout

The image uses a GPT partition table:

| Partition | Size | Filesystem | Label            |
|-----------|------|------------|------------------|
| p1        | 10G  | F2FS       | ElleOS_Root      |
| p2        | 20G  | bcachefs   | ElleOS_Sources   |
| p3        | 10G  | bcachefs   | ElleOS_Home      |

## Prerequisites

A Linux host with the following available:

- `losetup`, `mount`, `chroot` (util-linux)
- F2FS and bcachefs filesystem support (`f2fs-tools`, `bcachefs-tools`)
- Standard development toolchain (gcc, g++, make, binutils, etc.)

Run `bash tests/version-check.sh` to verify your host has the required tools.

## Usage

All commands require root privileges.

```
sudo make mount       # Attach the image and mount partitions into mnt_image/
sudo make run         # Mount + bind virtual filesystems + enter chroot shell
sudo make umount      # Unmount everything and detach the loop device
```

## Building the Image from Scratch

To create a new blank disk image (20 GB) with the partition table and formatted filesystems:

```
sudo bash scripts/build_os.sh
```

## Project Structure

```
Fleur_de_Lys.img      # The disk image
mnt_image/            # Mount point (created by make mount)
Makefile              # Mount, run, and unmount targets
etc/
  os-release          # Distribution identity
scripts/
  build_os.sh         # Create and partition a new disk image
  build_img.sh        # Image creation helper
  mount.sh            # Legacy mount script
tests/
  version-check.sh    # Verify host toolchain requirements
```
