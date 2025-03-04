---
layout: post
title:  "Look shared library dependencies"
date:   2019-06-12 07:41:10 -0300
categories: en linux
---

# Introduction

This post came out after I spent quite a few days spinning aroung an error that didn't make sense at that time. It was this one below:

    $ ./java
      bash: file not found

But the `java` file was there, and I didn't know what bash meant printing "file not found". It just didn't make any sense at all. One good thing I learned during this problem is that sometimes we don't look for the right questions, thus spending much more time in finding a solution. I spent about 3 days googling for Java-related questions and got nothing.

# Back to the subject

After understanding a bit more of how a program is landed in memory and executed, I figured it out by listing all the dependencies that the Java binary needed. I ran:

    $ ldd java
        linux-vdso.so.1 (0x00007ffe64f4b000)
        libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007fa90c376000)
        libz.so.1 => /lib/x86_64-linux-gnu/libz.so.1 (0x00007fa90c15c000)
        libjli.so => not found
        libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007fa90bf58000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007fa90bbb9000)
        /lib64/ld-linux-x86-64.so.2 (0x00007fa90c795000)

This showed me a lib file that I didn't have installed at that time, then after installing it, Java worked like usual.

When you program loads into memory, it certainly requires that some shared libraries are present and accessible in memory in some way. The most common dependency is the libc, almost all programs that exist today depend on it. 

The [ldd command](http://man7.org/linux/man-pages/man1/ldd.1.html) looks into the binary, looking for the shared libraries dependencies and print those out to the screen. It's simple but super useful in that type of situation.

Thanks for your time and attention.

Chaws
