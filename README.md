# Description

Script to build images for pl-161 and pl-900 devices

# Prerequisites

## Ubuntu Xenial
Additional Packages for Ubuntu: ```gawk wget git-core diffstat unzip
texinfo gcc-multilib build-essential chrpath socat cpio python3
python3-pip python3-pexpect xz-utils debianutils iputils-ping
python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev pylint3 xterm```

## USB Mass Storage device
- USB Pen Drive, USB Hard Disk… "USB stick"

- 1 Partition, FAT32 formatted, empty, 4GiB or more, USB-A

(There are devices around without any partitions. This may not work)

# Usage

## Connection

The required sources are reachable via github. Please make sure you can pull from there.

## Build

Run the shellscript to download the yocto tree, the sources and generate
the binaries to flash onto the target.

- for pl-161
    ```
    ./autobuild.sh -M pl-161
    ```
- for pl-900
    ```
    ./autobuild.sh -M pl-900
    ```

The script will generate a zipfile under `output/main-<timestamp>-developmental.zip`

## Installation

1. Unzip `output/main-<timestamp>-developmental.zip` onto the USB stick
2. Plug USB stick into update port
3. Wait until display says "Update procedure ended".

## Modification

The software is built with yocto.
Start learning about yocto here: https://www.yoctoproject.org/software-overview/
