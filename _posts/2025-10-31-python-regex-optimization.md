---
title:  "Performance gain using targeted RegEx's in Python"
date:   2025-10-31 07:41:10 -0300
categories:
  - Blog
tags:
  - performance
  - python
  - regex
  - dynamic-programming
---

Match strings 3x faster!

<!--more-->

# Introduction

Often times we use Python's RegEx module `re` to handle more complex string matching. That is great
and a no-brainer. It takes a bit of time to come up with a not-so-unreadable regex that works
perfectly for your use-case.

Specific use-cases that might abuse the use of regex can become part of a series of performance tuning.
That is what we are going to discuss in the blog post.


## Motivation

Leetcode is probably the number 1 programming challenge platform for those who enjoy challenging themselves.
Most problems there seem to be targeted only for pure testing. One particular caught my attention: https://leetcode.com/problems/regular-expression-matching/.

The challenge describes a subset of RegEx, where "." matches any character and "*" can match zero or many of the
preceding character. The solution can be found anywhere, e.g. https://github.com/TheAlgorithms/Python/blob/master/dynamic_programming/regex_match.py.

The solution is such an elegant Dynamic Programming craft that tears one's eyes. It is beautiful and use only a few lines of code
to resolve the problem.

This got me thinking if it would run faster than the default RegEx module in Python.

## Experimenting

In order to check whether or not dynamic programming runs faster or not than Python's RegEx module, we need to run 2 experiments: one using `re` and another using custom-crafted regex parser.

### Using `re` module:

Let's create a file `with-regex.py` with the following content:
```python
import sys
import re
import time

string = sys.argv[1]
pattern = sys.argv[2]

def match_with_regex(s, p):
    return re.match(p, s)

start = time.time()
print(match_with_regex(string, pattern))
print(f"took {(time.time() - start)* 1000}ms")
```

And run it:

```
$ python with-regex.py aab 'c*a*b'
<re.Match object; span=(0, 3), match='aab'>
took 0.1068115234375ms
```

It is a pretty simple program and it took 0.1ms to run that simple pattern.

### Using custom implementation

Now let's create another file, `without-regex.py` with the following content:
```python
import sys
import time


def match_without_regex(s, p):
    m = len(s)
    n = len(p)
    table = [[False for _ in range(n + 1) ] for _ in range(m + 1)]

    table[0][0] = True

    for j in range(1, n + 1):
        if pattern[j - 1] == "*" and table[0][j - 2]:
            table[0][j] = True

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            string_char = s[i - 1]
            regex_char = p[j - 1]
            previous_regex_char = p[j - 2]
            matches = regex_char in [".", string_char]
            if matches:
                table[i][j] = table[i - 1][j - 1]
            else:
                if regex_char == "*":
                    table[i][j] = table[i - 1][j - 2]

                    if previous_regex_char in [".", string_char]:
                        table[i][j] = table[i][j] | table[i - 1][j]
                else:
                    table[i][j] = False

    return table[m][n]

string = sys.argv[1]
pattern = sys.argv[2]

start = time.time()
print(match_without_regex(string, pattern))
print(f"took {(time.time() - start)* 1000}ms")
```

It is a slight modified version of the original solution I found. Of course, it's a master piece that I reorganized
so it makes sense to me.

Running the exact similar string/pattern we have
```
$ python without-regex.py aab 'c*a*b'
True
took 0.032901763916015625ms
```

That took 0.03ms.

# Conclusion

Running `re` module is 3x slower than running a specific regex. Before you go an start replacing all regular expressions on your code, think about what you
just experienced. It is a very specific subset if compared the the swiss army knife RegEx module in Python.

It is nice to know that there are options out there that can make your specific use-case many many times faster just by thinking outside the box.
