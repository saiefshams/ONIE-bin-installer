#!/bin/bash

# Define the paths
iso_path="./ubuntu-20.04.6-live-server-amd64.iso"  # '.' represents the current directory
output_path="./output.bin"  # '.' represents the current directory

# Mount the ISO
mount_point=$(mktemp -d)
sudo mount -o loop "$iso_path" "$mount_point"

# Create the ONIE installer
sudo xorriso -as mkisofs -o "$output_path" -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot "$mount_point"

# Cleanup
sudo umount "$mount_point"
rm -rf "$mount_point"

echo "ONIE installer created at $output_path"