---
title:  "Python 3.14's True Parallelism Finally Arrives!"
date:   2025-12-08 15:38:00 -0300
categories:
  - Blog
tags:
  - performance
  - python
  - threading
  - parallelism
  - gil
---

Achieve true multi-core parallelism in Python by disabling the GIL!

<!--more-->

# Introduction

When I was learning Python, I started using threads in some programs to speed up execution because I already knew threading in other languages such as Java and C. So I just assumed that things worked the same. For years I believed that up until recently learning about Python's multi-thread limitation.

I don't really know the exact reason why Python was implemented like that, but there's this thing called the GIL (Global Intepreter Lock) that prevents Python code from running in more than one physical CPU thread at the same time. That is NOT REALLY PARALLEL!!! How weird huh!?

This means that Python's threading, while useful for I/O-bound tasks, offers no performance benefit for CPU-bound operations.

Python 3.14 changes everything though. You can build it with `--disable-gil` build option (promoted from experimental in Python 3.13 to officially supported in Python 3.14), and get a version of Python that removes the GIL entirely, enabling true multi-threaded parallelism for CPU-bound tasks.

## The Problem with the GIL

Let's understand why the GIL matters. When you run a CPU-intensive task using multiple threads in standard Python, the GIL ensures only one thread executes at a time. The threads take turns, switching rapidly, but never truly running in parallel. For CPU-bound work, this can make threading slower than sequential execution due to context-switching overhead.

For I/O-bound tasks (network requests, file operations), threading works great because threads can release the GIL while waiting for I/O. But for pure computation? The GIL is a bottleneck.

## Experimenting

Let's prove this with concrete examples. We'll create a CPU-intensive task (calculating prime numbers) and run it with multiple threads. We'll compare:

1. Standard Python 3.14 (with GIL) - threading should provide no speedup
2. Free-threaded Python 3.14 (GIL disabled) - threading should scale with CPU cores

### Pre-setup: Docker Containers

We'll use Docker to test both versions. First, let's create our test script that we'll use in both containers.

Create a file called `test_gil.py`:

```python
#!/usr/bin/env python3
import sys
import time
import threading

def is_prime(n):
    """Check if a number is prime (CPU-intensive operation)"""

    if n < 2:
        return False
    for i in range(2, int(n ** 0.5) + 1):
        if n % i == 0:
            return False
    return True

def count_primes_in_range(start, end):
    """Count prime numbers in a range"""
    
    count = 0
    for num in range(start, end):
        if is_prime(num):
            count += 1
    return count

def test_sequential(total_range):
    print(f"\nTesting SEQUENTIAL execution...")
    start_time = time.time()

    count = count_primes_in_range(1, total_range)

    elapsed = time.time() - start_time
    print(f"Found {count} primes")
    print(f"Time taken: {elapsed:.2f}s")
    return elapsed

def test_threaded(total_range, num_threads):
    print(f"\nTesting THREADED execution ({num_threads} threads)...")
    start_time = time.time()

    # Divide work among threads
    chunk_size = total_range // num_threads
    threads = []
    results = [0] * num_threads

    def worker(thread_id, start, end):
        results[thread_id] = count_primes_in_range(start, end)

    # Create and start threads
    for i in range(num_threads):
        start = i * chunk_size + 1
        end = (i + 1) * chunk_size if i < num_threads - 1 else total_range
        thread = threading.Thread(target=worker, args=(i, start, end))
        threads.append(thread)
        thread.start()

    # Wait for all threads to complete
    for thread in threads:
        thread.join()

    total_count = sum(results)
    elapsed = time.time() - start_time
    print(f"Found {total_count} primes")
    print(f"Time taken: {elapsed:.2f}s")
    return elapsed

if __name__ == "__main__":
    # Calculate primes up to this number
    RANGE = 1000000
    NUM_THREADS = 4

    print("*" * 60)
    print("CPU-bound Threading Test: Counting Primes")
    print("*" * 60)

    # Test sequential
    seq_time = test_sequential(RANGE)

    # Test threaded
    thread_time = test_threaded(RANGE, NUM_THREADS)

    # Calculate speedup
    speedup = seq_time / thread_time
    print("\n" + "*" * 60)
    print(f"Speedup: {speedup:.2f}x")
    if speedup < 1.2:
        print("Oh no! Threading provided NO speedup (GIL is active)")
    else:
        print("Yay! Threading provided significant speedup (GIL is disabled)")
    print("*" * 60)
```

Now let's create a Dockerfile for the **GIL-disabled** version. Create a file called `Dockerfile.nogil`:

```dockerfile
FROM debian:bookworm-slim

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    zlib1g-dev \
    libssl-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and build Python 3.14 with --disable-gil
WORKDIR /tmp
RUN wget https://www.python.org/ftp/python/3.14.1/Python-3.14.1.tgz && \
    tar xzf Python-3.14.1.tgz && \
    cd Python-3.14.1 && \
    ./configure --disable-gil --enable-optimizations && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf Python-3.14.1*

WORKDIR /app
CMD ["/bin/bash"]
```

### Testing with GIL Enabled (Standard Python)

First, let's test with the standard Python 3.14 image that has the GIL enabled:

```bash
# Run the test with standard Python 3.14
docker run --rm -v $(pwd):/app python:3.14 python3 /app/test_gil.py
```

You should see output similar to:

```
************************************************************
CPU-bound Threading Test: Counting Primes
************************************************************

Testing SEQUENTIAL execution...
Found 78498 primes
Time taken: 5.45s

Testing THREADED execution (4 threads)...
Found 78498 primes
Time taken: 5.42s

************************************************************
Speedup: 1.00x
Oh no! Threading provided NO speedup (GIL is active)
************************************************************
```

Notice that the threaded version **did not** run faster than sequential! This is the GIL in action. The threads are taking turns executing, adding context-switching overhead without any parallel benefit. In some runs I was able to see slower times with threads. Crazy!

### Testing with GIL Disabled (Free-threaded Python)

Now let's build and test the GIL-disabled version:

```bash
# Build the GIL-disabled Python image (this takes 10-15 minutes)
docker build -f Dockerfile.nogil -t python-nogil:3.14 .

# Run the test with GIL-disabled Python
docker run --rm -v $(pwd):/app python-nogil:3.14 python3 /app/test_gil.py
```

You should see dramatically different results:

```
************************************************************
CPU-bound Threading Test: Counting Primes
************************************************************

Testing SEQUENTIAL execution...
Found 78498 primes
Time taken: 4.77s

Testing THREADED execution (4 threads)...
Found 78498 primes
Time taken: 1.34s

************************************************************
Speedup: 3.56x
Yay! Threading provided significant speedup (GIL is disabled)
************************************************************
```

**WOW!** The threaded version is now **3~4x faster** on a 4-core system. This is true parallelism - all four threads are genuinely executing simultaneously across different CPU cores. And the weird thing is that the code ran almost one second faster on a single thread if compared to the single thread example on a GIL-enabled Python build. Wonder why...

### Understanding the Results

The performance difference is striking:

**With GIL (Standard Python):**
- Sequential: 5.45s
- Threaded (4 threads): 5.42s
- Speedup: **not really noticeable**

**Without GIL (Free-threaded Python):**
- Sequential: 4.77s
- Threaded (4 threads): 1.34s
- Speedup: **3.55x faster**

The GIL-disabled version achieves nearly linear scaling with the number of CPU cores. With 4 threads on a 4-core system, we see close to a 4x speedup, which is exactly what we'd expect from true parallel execution.

## Why the Performance Difference?

The dramatic improvement comes from fundamental differences in execution:

**With GIL:**
1. Only one thread executes Python code at a time
2. Threads context-switch frequently, creating overhead
3. CPU cores remain mostly idle while threads wait for the GIL
4. No true parallelism for CPU-bound operations

**Without GIL:**
1. All threads execute simultaneously on different cores
2. Each thread gets its own CPU core
3. Work is genuinely distributed across all available cores
4. True parallelism for CPU-bound operations

However, there are trade-offs. The GIL-disabled build:
- Has slightly higher memory overhead per thread
- Requires thread-safe code (just like any multi-threaded programming)
- May be slower for single-threaded code due to additional synchronization
- Not all third-party packages are compatible yet

## Practical Applications

Free-threaded Python opens up new possibilities:

1. **Data Processing**: Parallel processing of large datasets without multiprocessing overhead
2. **Scientific Computing**: CPU-intensive calculations across multiple cores
3. **Image/Video Processing**: Concurrent processing of frames or image batches
4. **Simulations**: Running multiple simulation threads in parallel
5. **Machine Learning**: Parallel feature engineering and data preprocessing

For I/O-bound tasks, standard Python with the GIL works fine. But for CPU-bound workloads, free-threading can provide game-changing performance improvements.

# Conclusion

**STOP** don't just go and disable the GIL on your projects! It is still maturing and will likely have unwanted behavior if not tested correctly.

Python 3.14's free-threading support (via `--disable-gil`) represents a historic shift for the language. After 30+ years of the GIL, Python can now achieve true multi-core parallelism for CPU-bound tasks.

The results speak for themselves: a nearly 4x speedup on a 4-core system for CPU-intensive work. This is genuine parallel execution that scales with your hardware.

However, keep in mind:

- Single-threaded performance may be slightly slower due to additional synchronization
- You need to write thread-safe code (proper use of locks, avoiding race conditions)
- For I/O-bound tasks, the standard GIL version works perfectly fine

For applications with CPU-bound workloads, free-threaded Python is a no-brainer. You can finally utilize all your CPU cores without resorting to multiprocessing, which has its own overhead and complexity.

The future of Python performance looks bright. The GIL served us well, but it's time to move forward. Welcome to the era of truly parallel Python!
