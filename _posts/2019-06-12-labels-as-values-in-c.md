---
layout: post
title:  "Labels as values in C"
date:   2019-06-12 07:41:10 -0300
categories: en cprogramming
---

# Introduction

This post doesn't show anything useful. It's just something cool I've found a while ago while doing something else and felt like making a post out of it.

If you ever programmed in C, or any language C-like, you probably know that the double ampersand operator (`&&`) works **only** for boolean expressions. Well, that's true untill you see [this](https://gcc.gnu.org/onlinedocs/gcc/Labels-as-Values.html). It's super weird.

# Snippet of code you shouldn't be seeing any time soon

Check out this piece of code I wrote/stole from GCC page:

    1. void * labels[] = {&&label1, &&label2, &&label3, &&back1, &&back2};
    2.
    3. goto *labels[0];
    4. back1: { goto *labels[1]; }
    5. back2: { goto *labels[2]; }
    6. 
    7. label1:{printf("this is label1\n"); goto *labels[3];}
    8. label2:{printf("this is label2\n"); goto *labels[4];}
    9. label3:{printf("this is label3\n");}

Confusing? Yet it's a perfectly compilable program, at least for GCC. Here we have 5 goto labels `back1`, `back2`, `label1`, `label2`, and `label3`. In line 1, all these labels are referenced not by a regular pointer-like single ampersand operator, but by two! They're stored in `labels`, and array of pointers to void. Since they're now referenced, we can simply use them as a goto parameter like in lines 3, 4, 5, 7, and 8.

Thanks for stopping by

Chaws
