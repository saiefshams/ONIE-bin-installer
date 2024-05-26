#!/bin/sh

#
#  Copyright (C) 2019 Luke Williams <luke.williams@canonical.com>
#
#  SPDX-License-Identifier:     GPL-2.0
#

#
#  Shell archive template
#
#  Strings of the form %%VAR%% are replaced during construction.
#

# Add a check for the size of the installer directory
installer_dir_size=$(du -s $tmp_dir/installer | cut -f1)
if [ $installer_dir_size -eq 0 ]; then
    echo "Error: Installer directory is empty"
    clean_up 1
fi

tmp_dir=
clean_up() {
    if [ "$(id -u)" = "0" ] ; then
        umount $tmp_dir > /dev/null 2>&1 || {
            echo "Error: Unable to unmount $tmp_dir"
            exit 1
        }
    fi
    rm -rf $tmp_dir || {
        echo "Error: Unable to remove $tmp_dir"
        exit 1
    }
    exit $1
}

# Add missing realpath command
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

# Add missing exit_marker function
exit_marker() {
    :
}

# Untar and launch install script in a tmpfs
cur_wd=$(pwd)
archive_path=$(realpath "$0")
tmp_dir=$(mktemp -d)
if [ "$(id -u)" = "0" ] ; then
    mount -t tmpfs tmpfs-installer $tmp_dir || clean_up 1
fi
cd $tmp_dir
echo -n "Preparing image archive ..."
sed -e '1,/^exit_marker$/d' $archive_path | tar xf - || clean_up 1
echo " OK."
cd $cur_wd

extract=no
args=":x"
while getopts "$args" a ; do
    case $a in
        x)
            extract=yes
            ;;
        *)
        ;;
    esac
done

if [ "$extract" = "yes" ] ; then
    # stop here
    echo "Image extracted to: $tmp_dir"
    if [ "$(id -u)" = "0" ] ; then
        echo "To un-mount the tmpfs when finished type:  umount $tmp_dir"
    fi
    exit 0
fi

$tmp_dir/installer/install.sh "$@"
rc="$?"

if [ $rc -ne 0 ]; then
    echo "Error: install.sh exited with code $rc"
    clean_up 1
fi

clean_up $rc

exit_marker