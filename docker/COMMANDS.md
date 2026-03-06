chmod +x fleur.sh

# One-time setup
./fleur.sh build          # Build the image
./fleur.sh start          # Start the container

# Daily workflow — mirrors your Makefile targets exactly
./fleur.sh versions       # Runs tests/version-check.sh inside container
./fleur.sh new-img        # Run scripts/build_os.sh to create Fleur_de_Lys.img
./fleur.sh mount          # make mount  → attach image + mount partitions
./fleur.sh run            # make run    → mount + enter chroot
./fleur.sh umount         # make umount → clean detach
