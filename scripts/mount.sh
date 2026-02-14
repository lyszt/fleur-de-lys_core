sudo losetup -P -f providentia.img

export DISK=$(losetup -j providentia.img | cut -d: -f1)
echo "Working on disk: $DISK"
