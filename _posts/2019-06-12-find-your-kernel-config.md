---
layout: post
title:  "Figuring out your Kernel configuration"
date:   2019-06-12 07:41:10 -0300
categories: en kernel
---

# Introduction

This post came out of an issue I had with an old Acer Aspire V5 Series. It was a 50-dollar laptop I got off [Craigslist](https://washingtondc.craigslist.org/d/computers/search/sya) right before going to [DEFCON 23](https://www.defcon.org/). It ran Window 10 Home edition and I wanted to burn in any Debian-like ditro.

First I tried to get Debian working. Got it burned into the hard drive and booted alright. The only issue I came across with was the wifi card: it simply didn't work! I then switched to a Ubuntu version and things just worked out-of-the box. 

It turns out that Ubuntu, as opposite of Debian, also accepts non-open source drivers in its package servers. Someone must have packaged my wifi card driver to Ubuntu's package server, but since it wasn't open source, that never made it to Debian's.

I decided to go deeper trying to figure out how to compile my own [wifi card driver](https://github.com/chaws/broadcom-wl) in Debian. Just out of curiosity. After reading a couple of tutorials I can't remember now, I came across a sequence of [Kernel panics](https://en.wikipedia.org/wiki/Kernel_panic). That was just making me crazy because I couldn't simply figure out why it was crashing after bricking the computer.

After researching the heck out of google, I managed to find a new concept that was getting stable in the Linux Kernel called [kexec](https://en.wikipedia.org/wiki/Kexec). It's a system call that allows panic'ing kernels to dump its core in a memory area and booting a sort of "rescue" Kernel afterwards in another part of memory, kind of adding an offset from where the new Kernel image starts. This would allow me to go check the previous Kernel dump.

# Back to the subject

A requirement for `kexec` to work is knowing if it's compiled in the Kernel. You figure that out by checking if the option `CONFIG_KEXEC` had an `y` on it at compilation time. But how would one check that after compilation?

Well, thanks to smart people who create Linux distributions, that comes in most all versions of Linux. In my case, using Debian, you'd run a command like this one:

    grep CONFIG_KEXEC= /boot/config-`uname -r`

And that'll show you whether or not `CONFIG_KEXEC` is enabled (=y), or even if it's present or not.



Thanks for your time and attention.

Chaws
