#!/bin/bash
# This script builds ProvidentiaOS inside a disk image

DISK="/dev/loop0"
if [[ "$DISK" != /dev/loop* ]]; then
  echo "Error: Target is not a loop device. Aborting to save your PC."
  exit 1
fi

echo "Formatting $DISK..."
sudo mkfs.ext4 ${DISK}p1
sudo mkfs.erofs ${DISK}p2

echo "Mounting..."
sudo mount ${DISK}p1 /mnt/providentia
