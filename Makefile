IMAGE      := Fleur_de_Lys.img
MNT        := mnt_image
LOOP_DEV    = $(shell losetup -j $(IMAGE) | cut -d: -f1)

.PHONY: mount umount run

mount:
	@if [ "$$(id -u)" -ne 0 ]; then echo "Run with sudo"; exit 1; fi
	@if [ -z "$(LOOP_DEV)" ]; then \
		echo "--- Attaching $(IMAGE)..."; \
		losetup -Pf --show $(IMAGE); \
	else \
		echo "--- $(IMAGE) already attached at $(LOOP_DEV)"; \
	fi
	@mkdir -p $(MNT)
	@if ! mountpoint -q $(MNT); then \
		echo "--- Mounting root (p1) to $(MNT)..."; \
		mount -t f2fs "$$(losetup -j $(IMAGE) | cut -d: -f1)p1" $(MNT); \
	else \
		echo "--- $(MNT) already mounted."; \
	fi
	@mkdir -p $(MNT)/sources
	@if ! mountpoint -q $(MNT)/sources; then \
		echo "--- Mounting sources (p2) to $(MNT)/sources..."; \
		mount -t bcachefs "$$(losetup -j $(IMAGE) | cut -d: -f1)p2" $(MNT)/sources; \
	fi
	@mkdir -p $(MNT)/home
	@if ! mountpoint -q $(MNT)/home; then \
		echo "--- Mounting home (p3) to $(MNT)/home..."; \
		mount -t bcachefs "$$(losetup -j $(IMAGE) | cut -d: -f1)p3" $(MNT)/home; \
	fi
	@echo "--- Mounted."

umount:
	@if [ "$$(id -u)" -ne 0 ]; then echo "Run with sudo"; exit 1; fi
	-@mountpoint -q $(MNT)/home && umount $(MNT)/home
	-@mountpoint -q $(MNT)/sources && umount $(MNT)/sources
	-@mountpoint -q $(MNT) && umount $(MNT)
	@if [ -n "$(LOOP_DEV)" ]; then \
		losetup -d $(LOOP_DEV); \
		echo "--- Detached $(LOOP_DEV)."; \
	fi
	@echo "--- Unmounted."

run: mount
	@if [ "$$(id -u)" -ne 0 ]; then echo "Run with sudo"; exit 1; fi
	@echo "--- Binding virtual filesystems..."
	@mkdir -p $(MNT)/{dev,proc,sys,run}
	@mountpoint -q $(MNT)/dev  || mount --bind /dev  $(MNT)/dev
	@mountpoint -q $(MNT)/proc || mount -t proc proc $(MNT)/proc
	@mountpoint -q $(MNT)/sys  || mount -t sysfs sys  $(MNT)/sys
	@mountpoint -q $(MNT)/run  || mount -t tmpfs tmpfs $(MNT)/run
	@echo "--- Entering chroot..."
	chroot $(MNT) /usr/bin/env -i \
		HOME=/root \
		TERM=linux \
		PS1='(fleur chroot) \u:\w\$$ ' \
		PATH=/bin:/usr/bin:/sbin:/usr/sbin \
		/bin/bash --login +h
