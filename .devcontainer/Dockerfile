# Base image pinned strictly to Ubuntu 22.04 Jammy (glibc 2.35)
FROM ubuntu:22.04

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV CCACHE_DIR=/root/.ccache

# 1. Base tools, repositories, and Node.js (v20 LTS for Claude Code)
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    dirmngr \
    gnupg2 \
    ca-certificates \
    curl \
    wget \
    git \
    git-lfs \
    ripgrep \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# 2. Add 32-bit foreign architecture and install wine-tkg/Wine compilation toolchain
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc-multilib \
    g++-multilib \
    clangd \
    gdb \
    mingw-w64 \
    meson \
    ninja-build \
    flex \
    bison \
    ccache \
    pkg-config \
    autoconf \
    automake \
    libtool \
    nasm \
    cmake \
    zstd \
    tar \
    bc \
    fontconfig \
    # Display & Graphics build headers (64-bit and 32-bit for multilib/New-WoW64)
    libvulkan-dev libvulkan-dev:i386 \
    libgl1-mesa-dev libgl1-mesa-dev:i386 \
    libx11-dev libx11-dev:i386 \
    libxext-dev libxext-dev:i386 \
    libxrandr-dev libxrandr-dev:i386 \
    libxinerama-dev libxinerama-dev:i386 \
    libxcursor-dev libxcursor-dev:i386 \
    libxi-dev libxi-dev:i386 \
    libxxf86vm-dev libxxf86vm-dev:i386 \
    # Audio, input, and system headers
    libasound2-dev libasound2-dev:i386 \
    libpulse-dev libpulse-dev:i386 \
    libudev-dev libudev-dev:i386 \
    libdbus-1-dev libdbus-1-dev:i386 \
    libfreetype-dev libfreetype-dev:i386 \
    libfontconfig1-dev libfontconfig1-dev:i386 \
    libgnutls28-dev libgnutls28-dev:i386 \
    libpcap-dev libpcap-dev:i386 \
    libusb-1.0-0-dev libusb-1.0-0-dev:i386 \
    libsdl2-dev libsdl2-dev:i386 \
    libunwind-dev \
    libwayland-dev \
    libxkbcommon-dev \
    libopenxr-dev \
    glslang-tools \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    && rm -rf /var/lib/apt/lists/*

# 2.1 Fetch Linux Ntsync UAPI header and build Clangd MCP Server
RUN mkdir -p /usr/local/include/linux && \
    curl -fsSL --retry 5 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/include/uapi/linux/ntsync.h -o /usr/local/include/linux/ntsync.h && \
    git clone --depth 1 https://github.com/felipeerias/clangd-mcp-server /opt/clangd-mcp-server && \
    cd /opt/clangd-mcp-server && npm install && npm run build

# 3. Install GitHub CLI & initialize git-lfs
RUN wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/* && \
    git lfs install

# 4. Install Astral UV and Python agent packages (Codex / OpenAI SDK tools)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -sf /root/.local/bin/uv /usr/local/bin/uv && \
    ln -sf /root/.local/bin/uvx /usr/local/bin/uvx && \
    pip install --no-cache-dir openai "huggingface_hub[cli]"

# 5. Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# 6. Install Antigravity CLI (agy)
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash || true && \
    if [ -f /root/.local/bin/agy ]; then ln -sf /root/.local/bin/agy /usr/local/bin/agy; fi

# 7. Install Hermes Agent
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --skip-browser || true

WORKDIR /workspace