#!/usr/bin/env bash
# Создаёт (или пересоздаёт) VM labvm в KVM из облачного образа Ubuntu 24.04
set -euo pipefail

NAME=labvm
IMG_URL=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
WORK=$HOME/vm
KEY=$HOME/.ssh/lab_key
REPO="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$WORK" "$REPO/ansible"
[ -f "$KEY" ] || ssh-keygen -t ed25519 -f "$KEY" -N ""
[ -f "$WORK/base.img" ] || wget -O "$WORK/base.img" "$IMG_URL"

cat > "$WORK/user-data" <<USERDATA
#cloud-config
hostname: $NAME
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "$KEY.pub")
USERDATA
printf 'instance-id: %s\nlocal-hostname: %s\n' "$NAME" "$NAME" > "$WORK/meta-data"

if sudo virsh dominfo "$NAME" >/dev/null 2>&1; then
  sudo virsh destroy "$NAME" || true
  sudo virsh undefine "$NAME" --remove-all-storage
fi

sudo cp "$WORK/base.img" "/var/lib/libvirt/images/$NAME.qcow2"
sudo qemu-img resize "/var/lib/libvirt/images/$NAME.qcow2" 20G

sudo virt-install \
  --name "$NAME" --memory 2048 --vcpus 2 \
  --disk path=/var/lib/libvirt/images/$NAME.qcow2,format=qcow2 \
  --import --os-variant ubuntu24.04 \
  --network network=default \
  --cloud-init user-data="$WORK/user-data",meta-data="$WORK/meta-data" \
  --graphics none --noautoconsole

echo "Жду IP-адрес..."
IP=""
for i in $(seq 1 60); do
  IP=$(sudo virsh domifaddr "$NAME" | awk '/ipv4/ {print $4}' | cut -d/ -f1)
  [ -n "$IP" ] && break
  sleep 3
done
[ -n "$IP" ] || { echo "IP не получен"; exit 1; }

ssh-keygen -R "$IP" >/dev/null 2>&1 || true
echo "Жду SSH на $IP..."
for i in $(seq 1 40); do
  ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=3 \
      -o BatchMode=yes ubuntu@"$IP" true 2>/dev/null && break
  sleep 3
done

cat > "$REPO/ansible/inventory.ini" <<INV
[lab]
labvm ansible_host=$IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/lab_key
INV

echo "Готово. VM $NAME, IP: $IP"