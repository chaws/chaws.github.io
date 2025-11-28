---
title:  "Boosting Python Performance with sendfile for Large File Transfers"
date:   2025-11-28 10:00:00 -0300
categories:
  - Blog
tags:
  - performance
  - python
  - linux
  - networking
  - zero-copy
---

Send files 2x faster using Linux kernel's sendfile syscall!

<!--more-->

# Introduction

When building web applications or file servers in Python, sending large files over the network is a common requirement. Whether you're serving video files, database dumps, or large datasets, the traditional approach of reading a file into memory and then writing it to a socket can be surprisingly inefficient.

The typical pattern looks like this: read a chunk from disk into userspace memory, then write that chunk to the network socket. This involves multiple context switches between user space and kernel space, and unnecessary data copying. For large files, this overhead adds up quickly.

## The Problem with Traditional File Transfer

The traditional approach to sending files involves:

1. Reading data from disk into kernel buffer
2. Copying data from kernel space to user space (your Python process)
3. Copying data from user space back to kernel space (socket buffer)
4. Sending data from socket buffer to network

Each copy operation and context switch consumes CPU cycles and memory bandwidth. For a 1GB file, this means 1GB is read from disk, 1GB is copied to user space, and 1GB is copied back to kernel space - that's 3GB of data movement for sending 1GB!

## Enter sendfile: Zero-Copy Transfer

Linux provides a syscall called `sendfile()` that eliminates the unnecessary copies. Instead of bouncing data through user space, `sendfile()` transfers data directly from the file descriptor to the socket within kernel space.

This is called "zero-copy" because the data never enters user space - it goes directly from disk to network within the kernel.

![Zero-copy illustration](/assets/images/zero-copy-sendfile.svg)

The diagram above shows how traditional file transfer (left) involves multiple copies between kernel and user space, while sendfile (right) keeps everything in kernel space for maximum efficiency.

## Experimenting

Let's measure the performance difference between traditional file transfer and sendfile. We'll create two Python servers and compare their performance when serving a 1GB file.

### Pre-setup: Generate Test File

First, let's create a 1GB test file:

```bash
# Create a 1GB test file filled with random data
dd if=/dev/urandom of=testfile.bin bs=1M count=1024

# Verify the file size
ls -lh testfile.bin
```

### Traditional Approach: Read and Send

Create a file called `traditional_server.py`:

```python
#!/usr/bin/env python3
import socket
import time
import os

HOST = '127.0.0.1'
PORT = 8000
BUFFER_SIZE = 65536  # 64KB chunks

def serve_file_traditional(client_socket, filename):
    """Send file using traditional read/write approach"""
    file_size = os.path.getsize(filename)

    with open(filename, 'rb') as f:
        sent = 0
        while sent < file_size:
            chunk = f.read(BUFFER_SIZE)
            if not chunk:
                break
            client_socket.sendall(chunk)
            sent += len(chunk)

    return sent

def main():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server_socket:
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.bind((HOST, PORT))
        server_socket.listen(1)

        print(f"Traditional server listening on {HOST}:{PORT}")

        while True:
            client_socket, addr = server_socket.accept()
            print(f"Connection from {addr}")

            start_time = time.time()

            # Send HTTP headers
            response = b"HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\n\r\n"
            client_socket.sendall(response)

            # Send file
            bytes_sent = serve_file_traditional(client_socket, 'testfile.bin')

            elapsed = time.time() - start_time
            throughput = (bytes_sent / 1024 / 1024) / elapsed

            print(f"Sent {bytes_sent / 1024 / 1024:.2f} MB in {elapsed:.2f}s ({throughput:.2f} MB/s)")

            client_socket.close()

if __name__ == '__main__':
    main()
```

### Sendfile Approach: Zero-Copy Transfer

Create a file called `sendfile_server.py`:

```python
#!/usr/bin/env python3
import socket
import os
import time

HOST = '127.0.0.1'
PORT = 8001

def serve_file_sendfile(client_socket, filename):
    """Send file using sendfile (zero-copy)"""
    file_size = os.path.getsize(filename)

    with open(filename, 'rb') as f:
        offset = 0
        while offset < file_size:
            # sendfile(out_fd, in_fd, offset, count)
            sent = os.sendfile(client_socket.fileno(), f.fileno(), offset, file_size - offset)
            if sent == 0:
                break
            offset += sent

    return offset

def main():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server_socket:
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.bind((HOST, PORT))
        server_socket.listen(1)

        print(f"Sendfile server listening on {HOST}:{PORT}")

        while True:
            client_socket, addr = server_socket.accept()
            print(f"Connection from {addr}")

            start_time = time.time()

            # Send HTTP headers
            response = b"HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\n\r\n"
            client_socket.sendall(response)

            # Send file using sendfile
            bytes_sent = serve_file_sendfile(client_socket, 'testfile.bin')

            elapsed = time.time() - start_time
            throughput = (bytes_sent / 1024 / 1024) / elapsed

            print(f"Sent {bytes_sent / 1024 / 1024:.2f} MB in {elapsed:.2f}s ({throughput:.2f} MB/s)")

            client_socket.close()

if __name__ == '__main__':
    main()
```

### Running the Comparison

Open three terminal windows:

**Terminal 1** - Run traditional server:
```bash
python3 traditional_server.py
```

**Terminal 2** - Test traditional server:
```bash
time curl http://127.0.0.1:8000 > /dev/null
```

**Terminal 3** - Run sendfile server (after testing traditional):
```bash
python3 sendfile_server.py
```

Then test sendfile server:
```bash
time curl http://127.0.0.1:8001 > /dev/null
```

### Results

On a typical modern Linux system with SSD storage, you might see results like:

**Traditional approach:**
```
Sent 1024.00 MB in 0.60s (1701.21 MB/s)
```

**Sendfile approach:**
```
Sent 1024.00 MB in 0.39s (2612.01 MB/s)
```

That's approximately **2-3x faster** using sendfile! The exact speedup depends on your hardware, but sendfile consistently outperforms the traditional approach, especially for large files.

## Why the Performance Difference?

The dramatic performance improvement comes from several factors:

1. **Eliminated copies**: Data moves directly from disk cache to network buffer
2. **Reduced context switches**: Fewer transitions between user space and kernel space
3. **Better CPU cache utilization**: Less data movement means better cache hit rates
4. **Lower memory pressure**: No need to allocate user space buffers

The kernel can also optimize the transfer path, potentially using DMA (Direct Memory Access) to move data without CPU involvement.

# Conclusion

For applications that serve large files, `os.sendfile()` provides dramatic performance improvements with minimal code changes. The zero-copy approach reduces CPU usage, improves throughput, and lowers memory consumption.

However, keep in mind:

- `sendfile()` is available on Linux (and some Unix systems)
- It works only for file-to-socket transfers
- For small files, the overhead difference is negligible
- Traditional approaches give you more control (encryption, compression, etc.)

For high-performance file servers, CDNs, or any application serving large static files, sendfile is a no-brainer optimization that can significantly reduce server load and improve response times.

Next time you're building a file server in Python, remember: sometimes the best code is the code that never runs in user space!
