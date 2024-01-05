#!/bin/sh

# update-efi-partition.sh downloads an additional set of packages to a temporary directory and adds them to the FCOS_DISK's EFI partition
#
# These commands are copy/pasted from https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-raspberry-pi4/#_installing_fcos_and_booting_via_u_boot
# with the following updates:
# - renamed $FCOSDISK $FCOS_DISK to align with naming conventions in other files.
# - $FCOS_DISK is expected to be provided in the form of an environment variable

set -e
set -x

RELEASE=39 # The target Fedora Release. Use the same one that current FCOS is based on.
mkdir -p /tmp/RPi4boot/boot/efi/
dnf install -y --downloadonly --release=$RELEASE --forcearch=aarch64 --destdir=/tmp/RPi4boot/ uboot-images-armv8 bcm283x-firmware bcm283x-overlays

for rpm in /tmp/RPi4boot/*rpm; do rpm2cpio $rpm | cpio -idv -D /tmp/RPi4boot/; done
mv /tmp/RPi4boot/usr/share/uboot/rpi_arm64/u-boot.bin /tmp/RPi4boot/boot/efi/rpi-u-boot.bin

echo "FCOS_DISK: ${FCOS_DISK}"

FCOSEFIPARTITION=$(lsblk $FCOS_DISK -J -oLABEL,PATH  | jq -r '.blockdevices[] | select(.label == "EFI-SYSTEM")'.path)
mkdir /tmp/FCOSEFIpart
mount $FCOSEFIPARTITION /tmp/FCOSEFIpart
rsync -avh --ignore-existing /tmp/RPi4boot/boot/efi/ /tmp/FCOSEFIpart/
umount $FCOSEFIPARTITION
