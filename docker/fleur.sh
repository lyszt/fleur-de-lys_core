#!/bin/bash
# fleur.sh — Helper script for the Fleur de Lys build container
set -e

CONTAINER="fleur-build"
IMAGE="fleur-de-lys-builder:latest"

usage() {
  echo "Usage: $0 [command]"
  echo ""
  echo "  build       Build (or rebuild) the Docker image"
  echo "  start       Start the container (detached)"
  echo "  shell       Open a root shell in the running container"
  echo "  versions    Run the host tool version check (tests/version-check.sh)"
  echo "  mount       Run 'make mount' inside the container"
  echo "  run         Run 'make run' inside the container (mount + chroot)"
  echo "  umount      Run 'make umount' inside the container"
  echo "  new-img     Run scripts/build_os.sh to create a fresh disk image"
  echo "  stop        Stop the container"
  echo "  clean       Stop and remove container"
  echo "  status      Show container status"
}

need_running() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[!] Container '$CONTAINER' is not running. Run: $0 start"
    exit 1
  fi
}

case "$1" in
build)
  echo "[*] Building Fleur de Lys Docker image..."
  docker-compose build
  ;;
start)
  echo "[*] Starting container..."
  docker-compose up -d
  echo "[+] '$CONTAINER' is running."
  ;;
shell)
  need_running
  echo "[*] Opening root shell in '$CONTAINER'..."
  docker exec -it $CONTAINER /bin/bash
  ;;
versions)
  need_running
  docker exec -it $CONTAINER /usr/local/bin/version-check.sh
  ;;
mount)
  need_running
  echo "[*] Running: make mount"
  docker exec -it $CONTAINER bash -c "cd /build && make mount"
  ;;
run)
  need_running
  echo "[*] Running: make run (mount + chroot)"
  docker exec -it $CONTAINER bash -c "cd /build && make run"
  ;;
umount)
  need_running
  echo "[*] Running: make umount"
  docker exec -it $CONTAINER bash -c "cd /build && make umount"
  ;;
new-img)
  need_running
  echo "[*] Creating new disk image via scripts/build_os.sh..."
  docker exec -it $CONTAINER bash -c "cd /build && bash scripts/build_os.sh"
  ;;
stop)
  echo "[*] Stopping container..."
  docker-compose stop
  ;;
clean)
  echo "[*] Removing container (image and .img file are preserved)..."
  docker-compose down
  ;;
status)
  docker ps -a --filter "name=$CONTAINER"
  ;;
*)
  usage
  ;;
esac
