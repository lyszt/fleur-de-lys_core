#!/bin/bash
# build_image.sh
# Run this with sudo

set -e

IMAGE_NAME="../providentia.img"
IMAGE_SIZE="20G"

# 1. Create the empty file (The Fake Hard Drive)
echo "--- Creating empty disk image ($IMAGE_SIZE)..."
fallocate -l $IMAGE_SIZE $IMAGE_NAME

# 2. Partition the file using sfdisk
# We use type aliases: U=EFI, L=Linux Filesystem
echo "--- Partitioning..."
sfdisk $IMAGE_NAME <<EOF
label: gpt
,512M, U
,4G, L
,10G, L
,, L
EOF

# 3. Mount the image as a Loop Device so we can format it
# -P tells kernel to scan for partitions (creates /dev/loop0p1, p2, etc.)
LOOP_DEV=$(losetup -P --show -f $IMAGE_NAME)
echo "--- Mounted as $LOOP_DEV"

# 4. Format the Writable Partitions

# Partition 1: Boot (FAT32 for EFI)
echo "--- Formatting Boot (EFI)..."
mkfs.fat -F32 -n PROV_EFI "${LOOP_DEV}p1"

# Partition 3: AI Models (XFS)
# Optimization: largeio and larger inodes for massive files
echo "--- Formatting Model Store (XFS)..."
mkfs.xfs -f -L PROV_MODELS "${LOOP_DEV}p3"

# Partition 4: Home/Data (F2FS)
echo "--- Formatting User Data (F2FS)..."
mkfs.f2fs -l PROV_DATA -O extra_attr,inode_checksum,sb_checksum,compression "${LOOP_DEV}p4"

losetup -d $LOOP_DEV
echo "--- Success! $IMAGE_NAME is ready."
