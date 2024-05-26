#!/bin/sh

#
#  Copyright (C) 2019 Luke Williams <luke.williams@canonical.com>
#  Modified by: Saief Shams Murad, May 2024
#  B.IT @ Networking and IT Security, Ontario Tech University, Oshawa, Canada
#
#  SPDX-License-Identifier:     GPL-2.0
#

# goal: Make an ONIE installer from Ubuntu's Server 20.04 iso
#
# inputs: ubuntu-20.04-server.iso
# output: ONIE compatible installer

set -e

IN_IMAGE="ubuntu-20.04.6-live-server-amd64"
ISO="${IN_IMAGE}.iso"

# Check if the ISO exists
if [ ! -f "$ISO" ]; then
    echo "ERROR: Unable to find ISO: $ISO"
    exit 1
fi
echo "Found ISO: $ISO"

WORKDIR=./work
EXTRACTDIR="$WORKDIR/extract"
INSTALLDIR="$WORKDIR/installer"

output_file="${IN_IMAGE}-ONIE.bin"

echo -n "Creating $output_file: ."

# prepare workspace
[ -d $EXTRACTDIR ] && chmod +w -R $EXTRACTDIR
rm -rf $WORKDIR
mkdir -p $EXTRACTDIR
mkdir -p $INSTALLDIR

# extract ISO
xorriso \
    -indev $ISO \
    -osirrox on \
    -extract / $EXTRACTDIR
echo -n "."

echo "Contents of casper directory:"
ls $EXTRACTDIR/casper

KERNEL=casper/vmlinuz
IN_KERNEL=$EXTRACTDIR/$KERNEL
[ -r $IN_KERNEL ] || {
    echo "ERROR: Unable to find kernel in ISO: $IN_KERNEL"
    exit 1
}
INITRD=casper/initrd
IN_INITRD=$EXTRACTDIR/$INITRD
[ -r $IN_INITRD ] || {
    echo "ERROR: Unable to find initrd in ISO: $IN_INITRD"
    exit 1
}

KERNEL_ARGS="--- console=tty0 console=ttyS0,115200n8"

cp $IN_KERNEL $IN_INITRD $INSTALLDIR

# Create custom install.sh script
touch $INSTALLDIR/install.sh
chmod +x $INSTALLDIR/install.sh

(cat <<EOF
#!/bin/sh

cd \$(dirname \$0)

# remove old partitions
for p in \$(seq 3 9) ; do
  sgdisk -d \$p /dev/vda > /dev/null 2>&1
done

# bonk out on errors
set -e

echo "Loading new kernel ..."
kexec --load --initrd=$INITRD --append="$KERNEL_ARGS" $KERNEL
kexec --exec

EOF
) >> $INSTALLDIR/install.sh
echo -n "."

# Repackage $INSTALLDIR into a self-extracting installer image
sharch="$WORKDIR/sharch.tar"
tar -C $WORKDIR -cf $sharch installer || {
    echo "Error: Problems creating $sharch archive"
    exit 1
}

[ -f "$sharch" ] || {
    echo "Error: $sharch not found"
    exit 1
}
echo -n "."

sha1=$(cat $sharch | sha1sum | awk '{print $1}')
echo -n "."

cp sharch_body.sh $output_file || {
    echo "Error: Problems copying sharch_body.sh"
    exit 1
}

# Replace variables in the sharch template
sed -i -e "s/%%IMAGE_SHA1%%/$sha1/" $output_file
echo -n "."
cat $sharch >> $output_file
rm -rf $tmp_dir
echo " Done."