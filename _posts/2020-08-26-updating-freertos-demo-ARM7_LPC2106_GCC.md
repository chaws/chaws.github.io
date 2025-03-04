---
layout: post
title:  "Compiling FreeRTOS Demo for LPC2106 using GCC on Linux"
date:   2021-03-19 07:41:10 -0300
categories: en linux make freertos rtos
---
# Introduction

FreeRTOS is an excellent Open Sourced Real Time Operating System, aka RTOS, supporting many different boards. The best way to learn it and start a new project is through their [Demos](https://github.com/FreeRTOS/FreeRTOS/tree/master/FreeRTOS/Demo) directory, where you pick one that's more appropriate to your use case. Needless to say, this will be an introductory post/hands-on to FreeRTOS.

One little downside is that a lot of these Demos are for proprietary compilers, or IDEs that no longer exist! Well, I've tried to pick a few GCC examples where they had a `Makefile` so I could work my way out to get a demo building.

In the following sections I'll be showing you how I did to get the [ARM7_LPC2106_GCC](https://github.com/FreeRTOS/FreeRTOS/tree/master/FreeRTOS/Demo/ARM7_LPC2106_GCC) demo working on my Linux/Ubuntu machine.

**NOTE**
FreeRTOS has been around for quite some time now, and although it has currently been maintained by Amazon, a lot of its code and demos was written on Windows machines for Windows deployments.

# Steps

## 1. Out-of-the-box attempt

First thing to try was obviously running `make` out-of-the-box:

```bash
$ git clone https://github.com/FreeRTOS/FreeRTOS.git
$ cd FreeRTOS/FreeRTOS/Demo/ARM7_LPC2106_GCC
$ make
arm-elf-gcc -c -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D  -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -T  -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm ../../Source/portable/GCC/ARM7_LPC2000/portISR.c -o ../../Source/portable/GCC/ARM7_LPC2000/portISR.o
make: arm-elf-gcc: Command not found
Makefile:96: recipe for target '../../Source/portable/GCC/ARM7_LPC2000/portISR.o' failed
make: *** [../../Source/portable/GCC/ARM7_LPC2000/portISR.o] Error 127
```

As you would certainly expect, that didn't work at all. Unless you're into RTOS/Embedded Systems development, you probably won't have `arm-elf-gcc`. At first glance, one would run `apt sarch arm-elf-gcc` and once realized that this returns nothing, one would use his/her Googlefu to try to get it installed.

Let me save some of your sitting hours by letting you know that `arm-elf-gcc` got incorporated into `arm-none-eabi-gcc`. This is probably my main motivation to write up this blog post: to let you know that `arm-none-eabi-gcc` is the thing you should use to compile embedded software, well for ARM boards at least.

Moving on, getting `arm-none-eabi-gcc` installed is trivial:
```bash
$ sudo apt install gcc-arm-none-eabi
# or you can download a newer from ARM's website, then unzip it with `tar xf`
$ wget https://developer.arm.com/-/media/Files/downloads/gnu-rm/10-2020q4/gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux.tar.bz2
```

## 2. Tweaking the `Makefile`

Now that we know which compiler to use, let's change it in the Demo's [makefile](https://github.com/FreeRTOS/FreeRTOS/blob/master/FreeRTOS/Demo/ARM7_LPC2106_GCC/Makefile). Locate these lines:

```makefile
CC=arm-elf-gcc
OBJCOPY=arm-elf-objcopy
ARCH=arm-elf-ar
```
and replace by these lines:

```makefile
CC=arm-none-eabi-gcc
OBJCOPY=arm-none-eabi-objcopy
ARCH=arm-none-eabi-ar
```

It was basically replacing `arm-elf-` by `arm-none-eabi-`. Now let's run it one more time:

```bash
$ make
arm-none-eabi-gcc -c -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D  -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -T  -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm ../../Source/portable/GCC/ARM7_LPC2000/portISR.c -o ../../Source/portable/GCC/ARM7_LPC2000/portISR.o
arm-none-eabi-gcc: error: GCC_ARM7: No such file or directory
Makefile:96: recipe for target '../../Source/portable/GCC/ARM7_LPC2000/portISR.o' failed
make: *** [../../Source/portable/GCC/ARM7_LPC2000/portISR.o] Error 1
```

Now that we past the compiler not being found error, we're facing this `error: GCC_ARM7: No such file or directory`. I don't know about you, but the first thing I do when I see `No such file or directory` is start grep'ing so:

```bash
$ grep -rn GCC_ARM7
Makefile:38:CFLAGS=$(WARNINGS) -D $(RUN_MODE) -D GCC_ARM7 -I. -I../../Source/include \
```

Let's pay attention to this snippet of the `Makefile`:

```makefile
 28 CC=arm-none-eabi-gcc
 29 OBJCOPY=arm-none-eabi-objcopy
 30 ARCH=arm-none-eabi-ar
 31 CRT0=boot.s
 32 WARNINGS=-Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare \
 33         -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused
 34
 35 #
 36 # CFLAGS common to both the THUMB and ARM mode builds
 37 #
>38 CFLAGS=$(WARNINGS) -D $(RUN_MODE) -D GCC_ARM7 -I. -I../../Source/include \
```

We can see that, when defining `CFLAGS`, there are a couple of variables to be expanded: `$(WARNINGS)` and `$(RUN_MODE)`. The first one is defined in line `32`, but there are no definitions for `RUN_MODE`, thus `CFLAGS` will be evaluated to `... -D -D GCC_ARM7...` that tells the compiler that a macro with name `-D` should be defined and that `GCC_ARM7` is a file to be compiled/linked. As there's no file like that, gcc will raise the `No such file or directory error`. We should be finding what `$(RUN_MODE)` is:

```bash
$ grep -rn RUN_MODE
rom_thumb.bat:4:set RUN_MODE=RUN_FROM_ROM
ram_thumb.bat:4:set RUN_MODE=RUN_FROM_RAM
rom_arm.bat:4:set RUN_MODE=RUN_FROM_ROM
ram_arm.bat:4:set RUN_MODE=RUN_FROM_RAM
Makefile:38:CFLAGS=$(WARNINGS) -D $(RUN_MODE) -D GCC_ARM7 -I. -I../../Source/include \
```

Remember the note in the introduction? Yeah, it's biting us right here. The file `rom_thumb.bat` is:

```batch
set USE_THUMB_MODE=YES
set DEBUG=
set OPTIM=-O3
set RUN_MODE=RUN_FROM_ROM
set LDSCRIPT=lpc2106-rom.ld
make
```

This file prepares the environment variables prior to running make. Let's convert that into a bash script:

```bash
export USE_THUMB_MODE=YES
export DEBUG=
export OPTIM=-O3
export RUN_MODE=RUN_FROM_ROM
export LDSCRIPT=lpc2106-rom.ld
make
```
Now let's save it to `rom_thumb.sh` and run it:

```bash
$ . rom_thumb.sh
arm-none-eabi-gcc -c -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../../Source/portable/GCC/ARM7_LPC2000/portISR.c -o ../../Source/portable/GCC/ARM7_LPC2000/portISR.o
arm-none-eabi-gcc -c -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK serial/serialISR.c -o serial/serialISR.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK main.c -o main.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK serial/serial.c -o serial/serial.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ParTest/ParTest.c -o ParTest/ParTest.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../Common/Minimal/integer.c -o ../Common/Minimal/integer.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../Common/Minimal/flash.c -o ../Common/Minimal/flash.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../Common/Minimal/PollQ.c -o ../Common/Minimal/PollQ.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../Common/Minimal/comtest.c -o ../Common/Minimal/comtest.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../Common/Minimal/flop.c -o ../Common/Minimal/flop.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../Common/Minimal/semtest.c -o ../Common/Minimal/semtest.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../Common/Minimal/dynamic.c -o ../Common/Minimal/dynamic.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../Common/Minimal/BlockQ.c -o ../Common/Minimal/BlockQ.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../../Source/tasks.c -o ../../Source/tasks.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../../Source/queue.c -o ../../Source/queue.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../../Source/list.c -o ../../Source/list.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../../Source/portable/MemMang/heap_2.c -o ../../Source/portable/MemMang/heap_2.o
arm-none-eabi-gcc -c -mthumb -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../../Source/portable/GCC/ARM7_LPC2000/port.c -o ../../Source/portable/GCC/ARM7_LPC2000/port.o
arm-none-eabi-gcc -Wall -Wextra -Wshadow -Wpointer-arith -Wbad-function-cast -Wcast-align -Wsign-compare -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wunused -D RUN_FROM_ROM -D GCC_ARM7 -I. -I../../Source/include -I../Common/include  -mcpu=arm7tdmi -Tlpc2106-rom.ld -O3 -fomit-frame-pointer -fno-strict-aliasing -fno-dwarf2-cfi-asm -mthumb-interwork -D THUMB_INTERWORK ../../Source/portable/GCC/ARM7_LPC2000/portISR.o serial/serialISR.o main.o serial/serial.o ParTest/ParTest.o ../Common/Minimal/integer.o ../Common/Minimal/flash.o ../Common/Minimal/PollQ.o ../Common/Minimal/comtest.o ../Common/Minimal/flop.o ../Common/Minimal/semtest.o ../Common/Minimal/dynamic.o ../Common/Minimal/BlockQ.o ../../Source/tasks.o ../../Source/queue.o ../../Source/list.o ../../Source/portable/MemMang/heap_2.o ../../Source/portable/GCC/ARM7_LPC2000/port.o -nostartfiles boot.s -Xlinker -ortosdemo.elf -Xlinker -M -Xlinker -Map=rtosdemo.map
arm-none-eabi-objcopy rtosdemo.elf -O ihex rtosdemo.hex
```

And we got it working!

## 3. Is this correct?

Honestly, I don't know. The post goal is just to get you up and running with basic changes that might need to be done to get some of FreeRTOS Demos working. I have an ESP32 Devkit laying around my desk, but I couldn't find any Demos for it yet. The plan is to write another blog post about that in the future. Stay tuned and sorry if I disappointed you by not testing the binary :)


Thanks for your time and attention.

Chaws
