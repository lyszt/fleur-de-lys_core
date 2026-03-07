#!/bin/bash
# build_os.sh
# Run this with sudo
set -e

IMAGE_NAME="../fleur.img"
IMAGE_SIZE="23G"

# 1. Create the empty disk image
echo "--- Creating empty disk image ($IMAGE_SIZE)..."
truncate -s $IMAGE_SIZE $IMAGE_NAME

# 2. Partition with GPT layout matching Fleur de Lys spec
#   p1: 10G  - Root       (F2FS)
#   p2: 20G  - Sources    (bcachefs)
#   p3: 10G  - Home       (bcachefs)
echo "--- Partitioning..."
sfdisk $IMAGE_NAME <<SFDISK
label: gpt
,5G, L
,15G, L
,3G, L
SFDISK

# 3. Recreate loop device nodes in case they're lost (common in containers)
echo "--- Ensuring loop devices exist..."
for i in $(seq 0 7); do
  [ -e /dev/loop$i ] || mknod -m 0660 /dev/loop$i b 7 $i
done
[ -e /dev/loop-control ] || mknod -m 0660 /dev/loop-control c 10 237

# 4. Attach image as loop device (without -P, we'll use kpartx instead)
LOOP_DEV=$(losetup --show -f $IMAGE_NAME)
echo "--- Mounted as $LOOP_DEV"

# 5. Use kpartx to create properly-sized partition mappings
echo "--- Mapping partitions via kpartx..."
kpartx -av $LOOP_DEV

# kpartx creates /dev/mapper/loop0p1, loop0p2, loop0p3
LOOP_NAME=$(basename $LOOP_DEV)
PART1="/dev/mapper/${LOOP_NAME}p1"
PART2="/dev/mapper/${LOOP_NAME}p2"
PART3="/dev/mapper/${LOOP_NAME}p3"

sleep 1

# 6. Format partitions
echo "--- Formatting Root (F2FS)..."
mkfs.f2fs -l Fleur_de_Lys_Root \
  -O extra_attr,inode_checksum,sb_checksum,compression \
  "$PART1"

echo "--- Formatting Sources (bcachefs)..."
bcachefs format --label=Fleur_de_Lys_Sources --no-initialize --replicas=1 "$PART2"

echo "--- Formatting Home (bcachefs)..."
bcachefs format --label=Fleur_de_Lys_Home --no-initialize --replicas=1 "$PART3"

# 7. Remove kpartx mappings and detach loop device
kpartx -dv $LOOP_DEV
losetup -d $LOOP_DEV

echo "--- Success! $IMAGE_NAME is ready."
