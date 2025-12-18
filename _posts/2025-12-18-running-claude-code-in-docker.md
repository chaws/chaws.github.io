---
title:  "Running Claude Code in a Sandbox Environment"
date:   2025-12-18 07:41:10 -0300
categories:
  - Blog
tags:
  - docker
  - security
  - ai
  - claude
---

Keep your data safe when running AI-powered tools!

<!--more-->

# Introduction

AI-powered development tools like Claude Code are incredibly powerful. They can read files, execute commands, modify code, and interact with your system in ways that boost productivity tremendously. However, this power comes with a responsibility: protecting your sensitive data.

When you run Claude Code directly on your machine, it has access to everything in your current directory and potentially beyond. This means:

* **Environment variables** containing API keys, database credentials, and secrets
* **SSH keys** and other authentication tokens in your home directory
* **Configuration files** with sensitive information
* **Other projects** and directories you might not intend to share
* **System-level access** that could inadvertently expose sensitive data

Even with the best intentions, it's easy to forget about that `.env` file with production credentials or that `secrets.json` file sitting in a parent directory. One accidental command or file read, and your sensitive information could be exposed.

## Security and Privacy First

This is where the principle of **least privilege** comes into play. When running third-party applications, especially AI-powered tools that can autonomously explore your filesystem, you should always:

1. **Isolate the environment** - Only expose what's necessary
2. **Limit access scope** - Restrict file system access to specific directories
3. **Protect credentials** - Keep sensitive data outside the accessible scope
4. **Maintain control** - Know exactly what the tool can and cannot access

Docker containers provide an excellent solution for this. By running Claude Code in a container, you create a security boundary that protects your host system while still allowing the tool to do its job effectively.

# The Solution: Docker Containerization

The approach described here creates a sandboxed environment for Claude Code using Docker. This setup ensures that:

* Only your current project directory is accessible
* Your home directory remains protected (except for Claude's authentication config)
* File permissions are correctly maintained
* The environment is completely isolated from your host system

## The Components

We'll use three files to set up our containerized Claude Code environment:

1. `Dockerfile.claude` - Defines the Docker image
2. `entrypoint.sh` - Handles user permissions and starts Claude
3. `claude.sh` - Convenience script to build and run the container

### Dockerfile.claude

This file defines our Docker image with all necessary dependencies:

```dockerfile
FROM debian:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    gnupg \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for Claude Code)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Create workspace directory
RUN mkdir -p /workspace

# Set working directory
WORKDIR /workspace

# Script to create user matching host UID/GID and run Claude
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
```

The Dockerfile installs Claude Code in a clean Debian environment. Notice how we install all dependencies globally and set up a workspace directory that will be mapped to your project.

### entrypoint.sh

This script is crucial for maintaining proper file permissions between the container and your host system:

```bash
#!/bin/bash

# Create a user with the same UID/GID as the host user
# This ensures files created in the container have the correct ownership

USER_NAME="${HOST_USER:-claude-user}"
USER_UID="${HOST_UID:-1000}"
USER_GID="${HOST_GID:-1000}"
USER_HOME="${HOST_HOME:-/home/$USER_NAME}"

# Create group if it doesn't exist
if ! getent group "$USER_GID" > /dev/null 2>&1; then
    groupadd -g "$USER_GID" "$USER_NAME"
fi

# Create home directory first to avoid useradd warnings
mkdir -p "$USER_HOME"

# Create user if it doesn't exist
if ! id "$USER_UID" > /dev/null 2>&1; then
    useradd -u "$USER_UID" -g "$USER_GID" -d "$USER_HOME" -M -s /bin/bash "$USER_NAME"
fi

# Ensure .claude directory and file exist
mkdir -p "$USER_HOME/.claude"
touch "$USER_HOME/.claude.json"

# Set ownership on home directory and all contents
# Do this explicitly for the directory itself and its contents
chown "$USER_UID:$USER_GID" "$USER_HOME"
chown -R "$USER_UID:$USER_GID" "$USER_HOME/.claude"
chown "$USER_UID:$USER_GID" "$USER_HOME/.claude.json"

# Ensure the user has access to workspace
chown -R "$USER_UID:$USER_GID" /workspace 2>/dev/null || true

# Make sure home directory and config files are writable
chmod 755 "$USER_HOME"
chmod -R u+w "$USER_HOME/.claude"
chmod u+w "$USER_HOME/.claude.json"

# Switch to the user and run Claude Code
exec sudo -u "#$USER_UID" -g "#$USER_GID" HOME="$USER_HOME" claude "$@"
```

This script creates a user inside the container that matches your host user's UID and GID. This is essential because files created by the container will have the correct ownership on your host system. Without this, you'd end up with files owned by root or some arbitrary user ID.

### claude.sh

Finally, this convenience script builds the image and runs the container with all the right parameters:

```bash
#!/bin/bash

set -xe

IMAGE_NAME="claude-code-docker"
DOCKERFILE_PATH="$(dirname "$0")/Dockerfile.claude"

# Build the image if it doesn't exist
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "Image $IMAGE_NAME not found. Building..."
    docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_NAME" "$(dirname "$0")"
fi

# Ensure Claude config directory and file exist
mkdir -p "$HOME/.claude"
touch "$HOME/.claude.json"

# Run Claude Code in Docker container
# - Mount current directory to /workspace
# - Mount Claude config directory and file for authentication persistence
# - Pass current user UID/GID to maintain file permissions
# - Interactive with TTY for proper CLI experience
docker run -it --rm \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    -e HOST_USER="$USER" \
    -e HOST_HOME="/home/$USER" \
    -v "$PWD:/workspace" \
    -v "$HOME/.claude:/home/$USER/.claude" \
    -v "$HOME/.claude.json:/home/$USER/.claude.json" \
    -w /workspace \
    "$IMAGE_NAME" "$@"
```

The script handles the Docker image building (only on first run) and sets up all the necessary volume mounts and environment variables.

## Using the Setup

Once you have all three files in place, make the scripts executable and run:

```bash
$ chmod +x claude.sh entrypoint.sh
$ ./claude.sh
```

On the first run, Docker will build the image, which might take a few minutes. Subsequent runs will be instant.

Now Claude Code runs in a completely isolated environment with access only to:
* Your current working directory (mounted as `/workspace`)
* Claude's authentication configuration (so you don't have to re-authenticate)

Everything else on your system remains protected and inaccessible.

## What About Updates?

When Claude Code releases a new version, simply rebuild the image:

```bash
$ docker rmi claude-code-docker
$ ./claude.sh
```

This will trigger a fresh build with the latest version.

# Conclusion

Running AI-powered development tools in containerized environments is not just a best practice; it's essential for maintaining security and privacy. The small overhead of setting up Docker containers is vastly outweighed by the peace of mind knowing that your sensitive data is protected.

By using the approach outlined in this post, you get:
* **Complete isolation** from your host system
* **Controlled access** to only your current project
* **Proper file permissions** through UID/GID mapping
* **Easy setup** with reusable scripts

Remember: when it comes to security and privacy, it's always better to be proactive than reactive. Don't wait for a leak to happen. Containerize your tools and sleep better at night.

The examples described in this post are only the beginning, you are likely to add more dependencies to it such NodeJS or Python's PIP cache, and others. Feel free to customize as much as you need!

Happy (and safe) coding!
