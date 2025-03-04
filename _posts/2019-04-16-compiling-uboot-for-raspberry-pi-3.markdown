---
layout: post
title:  "Compiling U-Boot for Raspberry Pi 3"
date:   2019-04-16 07:41:10 -0300
categories: en
---

This post is an improvement of [this one][original-post]. I changed some bits and pieces I found a bit confusing on the original post.

# Introduction

U-Boot is a multi-platform, open-source, universal boot-loader with comprehensive support for loading and managing boot images, such as the Linux kernel. This article is a quick start up guide on porting U-Boot for Raspberry Pi 3 (RPi3) board using an SD card.

This tutorial is intended for getting u-boot up and running on a raspberry pi 3 model b. Hopefully I'll be posting another tutorial showing how to boot a kernel image using u-boot.

# Requirements

For this tutorial, you'll need a raspberry pi 3 model B (and its power supply), an SD card, and a serial-to-usb cable adapter. Keep in mind to leave your RPi3 off until you're told to apply power to it.

## RPi3 Boot process

### Stage 1

To reduce cost, the Raspberry Pi (Model A & B) omits any on-board non-volatile memory used to store the boot loaders, Linux Kernels and file systems as seen in more traditional embedded systems. Rather, a SD/MMC card slot is provided for this purpose. The Raspberry PI Compute Module has 4GB eMMC Flash on-board.

stage 1 boot is in the on-chip ROM. Loads Stage 2 in the L2 cache. The Raspberry Pi's Broadcom BCM2835 system on a chip (SoC) powers up with its ARM1176JZF-S 700 MHz processor held in reset. The VideoCore IV GPU core is responsible for booting the system. It loads the first stage boot loader from a ROM embedded within the SoC. The first stage bootloader is designed to load the second stage bootloader (bootcode.bin) from a FAT32 or FAT16 file system on the SD Card.

### Stage 2

The second stage bootloader - **bootcode.bin** - is executed on the VideoCore GPU and loads the third stage bootloader - **start.elf**. Historically, yet another bootloader called loader.bin was loaded at this stage, but has since been phased out.

### Stage 3

The third stage bootloader - **start.elf** - is where all the action happens. It starts by reading **config.txt**, a text file containing configuration parameters for both the VideoCore (Video/HDMI modes, memory, console frame buffers etc) and loading of the Linux Kernel (load addresses, device tree, uart/console baud rates etc).

### Stage 4

By default, **config.txt** does not point to any kernel image, as **start.elf** is already prepared to load any file named *kernel.img*. So in order to trick **start.elf** into loading the U-Boot image instead, we'll use our compiled **u-boot.bin** to pass as kernel image. This is the first thing that runs on the ARM processor. Our config.txt will look as:

    kernel = u-boot.bin

After completing above steps Booting is completed and RPI board is ready to take a commands from user by using U-Boot.

# <a id="formatting-the-sd-card"></a>Formatting the SD card

I chose to change this part of the tutorial because the original one didn't get u-boot to recognized all the memory in my RPi3. U-boot was only showing 128M, instead of 1G. I looked other tutorials trying to figure out what I did wrong, but nothing worked. Luckily, I tried something super dumb that got it working alright! It turns out that if you just get the basic files needed for RPi3 to boot, it won't fully map all the hardware, so it needs all necessary *.elf* files that comes in the original raspbian image from the official raspberry pi website. 

To accomplish that, go to the official raspbian download page at [https://www.raspberrypi.org/downloads/raspbian/](https://www.raspberrypi.org/downloads/raspbian/) and download the "Lite" version. This is what I'd tried. Although I didn't try on other versions, I imagine that all packages will contain the necessary boot files.

	$ wget https://downloads.raspberrypi.org/raspbian_lite_latest -O raspbian-strech-lite.zip
	$ unzip raspbian-strech-lite.zip # this will extract a *.img file
	$ sudo dd if=raspbian-strech-lite.img of=/dev/mmcblk0 bs=4M conv=fsync

**NOTE: in this tutorial, I'm using Debian 9, which recognized the SD card as */dev/mmcblk0*, it may be different on your set up.**

The last command, `dd` can take a while to execute, depending on your SD card speed. At current date, raspbian image is around 350M, so be patient. Once it's done, just unplug and plug it back. This will mount two partitions: a boot and a file system. We want to focus on the boot partition of your SD card, so keep that in mind for the next steps.

# Compiling

We need a 64 bit compiler and a cross compiler for, well, get u-boot compiled!

    $ sudo apt install gcc-aarch64-linux-gnu # last one is for 64bits compilation

Get the source code by cloning [Stephen Warren's work-in-progress](https://elinux.org/RPi_U-Boot#Stephen_Warren's_work-in-progress_branch) raspberry pi U-Boot git repository:

    $ git clone --depth 1 --branch rpi_dev https://github.com/swarren/u-boot u-boot

Compile it:

	$ cd u-boot && export CROSS_COMPILE=aarch64-linux-gnu- # u-boot will understand that we want cross-compilation
    $ make rpi_3_defconfig && make -j 8

After compilation ran smoothly, look for **u-boot.bin**. That is the **only** file you need to copy to the boot partition of the SD card you set up in [Formatting the SD card](#formatting-the-sd-card).

# Creating the configuration file

Now you need to create a configuration file that will tell the RPi3 how which kernel image do load and set up the serial connection:

    cat > config.txt <<EOM
    enable_uart=1
    arm_control=0x200
    kernel=u-boot.bin
    dtparam=i2c_arm=on
    dtparam=spi=on
    EOM

This will create **config.txt**, copy that to the boot partition of the SD card you set up in [Formatting the SD card](#formatting-the-sd-card). Note that you'll be replacing the original *config.txt* that came with raspbian, but that's OK since we don't care for it now.

You are done retrieving files to get u-boot started. Safely unmount the SD card and plug it into your RPi3.

# Connecting the RPi3 to the serial port

Now you need to get hacky on the hardware part of the tutorial. The two images below illustrates the schematics for a regular usb-to-serial cable adapter and the pins of a normal RPi3 model B.

![USB to Serial cable adapter](/assets/usb_serial_scheme.png)

![Raspberry Pi 3 pinout](/assets/raspberry-pi-pinout.jpg)

- Connect the **black** wire to **pin #6** (ground).
- Connect the **white** wire to **pin #8** (RXD to TXD)
- Connect the **green** wire to **pin #10** (TXD to RXD)

**NOTE: Be careful when wiring because any bad connection will prevent serial communication from happening**

# Communicating with RPi3 through serial port

You're done connecting the wires, now we need to make sure the serial connection was successfully made. Check it by running the following command then **connect the USB cable to the computer**.

    $ sudo dmesg -w

The command above simply opens a dynamic system log viewer. Anything happening in the kernel will show up there in real time! Use the USB cable part of the serial adapter and connect to your computer, a message like this one below should appear:

    [142054.216068] usb 4-1.2: new full-speed USB device number 8 using ehci-pci
    [142054.324715] usb 4-1.2: New USB device found, idVendor=067b, idProduct=2303
    [142054.324719] usb 4-1.2: New USB device strings: Mfr=1, Product=2, SerialNumber=0
    [142054.324721] usb 4-1.2: Product: USB-Serial Controller
    [142054.324724] usb 4-1.2: Manufacturer: Prolific Technology Inc.
    [142054.325177] pl2303 4-1.2:1.0: pl2303 converter detected
    [142054.326876] usb 4-1.2: pl2303 converter now attached to ttyUSB0

If you didn't see a message like that after you plugged it in, something's wrong. Re-wire everything and make sure all connections and wires are good. It's also a good thing to make sure the usb part of the cable is not shorting or anything like that. These cables are cheap, prone to failure. But they're cheap :).

Next, we need a way to communicate with RPi3 via serial protocol. There are plenty ways of doing so, but we'll use **minicom** in this tutorial, just because. Get it installed by running:

    $ sudo apt install minicom
    $ sudo minicom -s

The second part of the command will start minicom's setup. It should show something like this

    +-----[configuration]------+
    | Filenames and paths      |
    | File transfer protocols  |
    | Serial port setup        |
    | Modem and dialing        |
    | Screen and keyboard      |
    | Save setup as dfl        |
    | Save setup as..          |
    | Exit                     |
    | Exit from Minicom        |
    +--------------------------+

Scroll to *Serial port setup* then make sure settings are as follows:

    +-----------------------------------------------------------------------+
    | A -    Serial Device      : /dev/ttyUSB0                              |
    | B - Lockfile Location     : /var/lock                                 |
    | C -   Callin Program      :                                           |
    | D -  Callout Program      :                                           |
    | E -    Bps/Par/Bits       : 115200 8N1                                |
    | F - Hardware Flow Control : No                                        |
    | G - Software Flow Control : No                                        |
    |                                                                       |
    |    Change which setting?                                              |
    +-----------------------------------------------------------------------+

The **Serial Device** name should be the same as the one you found output by dmesg command. Press escape or enter to leave the setup menu then select *Exit*

After exiting the setup menu, you should see something like:

    Welcome to minicom 2.7

    OPTIONS: I18n                                                                
    Compiled on Apr 22 2017, 09:14:19.                                           
    Port /dev/ttyUSB0, 07:47:40                                                  
                                                                                 
    Press CTRL-A Z for help on special keys                                      

Finally, apply power to RPi3 and u-boot should start off with a message like this one below:

    U-Boot 2016.09-rc1-g8097d58931b4 (May 24 2019 - 14:46:52 -0300)              
                                                                                 
    DRAM:  948 MiB                                                               
    RPI 3 Model B (0xa02082)                
    boot regs: 0x00000000 0x00000000 0x00000000 0x00000000
    MMC:   bcm2835_sdhci: 0                 
    reading uboot.env                       
                                            
    ** Unable to read "uboot.env" from mmc0:1 **
    Using default environment
    
    In:    serial
    Out:   lcd
    Err:   lcd
    Net:   Net Initialization Skipped

Note the line **DRAM: 948MiB** proving that U-Boot now recognized all available memory in the raspbery pi 3.

Please email me if you had any questions regarding this tutorial. Thanks for your time and attention.

Chaws

[original-post]: https://pranavlavhate761157457.wordpress.com/2018/05/14/porting-of-u-boot-on-raspberrypi-3/
[rpi-firmware-github]: https://github.com/raspberrypi/firmware/tree/master/boot
