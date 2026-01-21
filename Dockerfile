FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CXX=aarch64-linux-gnu-g++ \
    AS=aarch64-linux-gnu-as \
    LD=aarch64-linux-gnu-ld \
    RANLIB=aarch64-linux-gnu-ranlib \
    STRIP=aarch64-linux-gnu-strip \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
ARG USER
ARG USER_ID
ARG GROUP_ID

# Create working directory and user
WORKDIR /tmp
COPY ./create_user.sh .

# The user creation script should be run before clearing /tmp or apt lists
# Ensure that create_user.sh correctly handles the passed ARG variables.
RUN bash -xe -- create_user.sh && rm -rf -- * && rm -rf -- /var/lib/apt/lists/*

# Set timezone to UTC and configure apt for smaller images in a single layer
# Consolidate APT configuration into a single command for efficiency
RUN ln -snf /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    echo "Etc/UTC" > /etc/timezone && \
    { \
        echo 'APT::Install-Recommends "0";'; \
        echo 'APT::Install-Suggests "0";'; \
        echo 'APT::Get::Assume-Yes "1";'; \
    } > /etc/apt/apt.conf.d/99local

# Configure sources: amd64 from archive/security; arm64 from ports
RUN dpkg --add-architecture arm64 && \
    CODENAME="$(. /etc/os-release; echo "${VERSION_CODENAME}")" && \
    : "${CODENAME:?Failed to read VERSION_CODENAME}" && \
    { \
      echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu ${CODENAME} main restricted universe multiverse"; \
      echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu ${CODENAME}-updates main restricted universe multiverse"; \
      echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu ${CODENAME}-backports main restricted universe multiverse"; \
      echo "deb [arch=amd64] http://security.ubuntu.com/ubuntu ${CODENAME}-security main restricted universe multiverse"; \
    } > /etc/apt/sources.list && \
    { \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${CODENAME} main restricted universe multiverse"; \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${CODENAME}-updates main restricted universe multiverse"; \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${CODENAME}-backports main restricted universe multiverse"; \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${CODENAME}-security main restricted universe multiverse"; \
    } > /etc/apt/sources.list.d/arm64-ports.list && \
    rm -f /etc/apt/sources.list.d/ubuntu.sources || true && \
    apt-get clean && \
    apt-get update


# Install required packages and perform other setup in a single, optimized layer
# Combine apt-get update and install for better caching and smaller layers.
# Ensure all commands that modify the filesystem are done before cleanup.
RUN apt-get install -y --no-install-recommends \
        build-essential git flex bison bc libssl-dev curl kmod rsync mtools dosfstools \
        gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libc6-dev-arm64-cross \
        python3-dev python3-pip swig yamllint python3-setuptools python3-wheel \
        yq automake \
        lavacli clang-15 lld-15 systemd-ukify \
        gh gcc g++ make autoconf libtool libelf-dev tar xz-utils llvm llvm-dev util-linux initramfs-tools pkg-config \
        abigail-tools sparse wget \
        apt-transport-https apt-utils fuseext2 \
        chrpath cpio debianutils diffstat file gawk gpg-agent iputils-ping locales liblz4-tool libsdl1.2-dev \
        openssh-client python3-git python3-pexpect python3-software-properties socat software-properties-common texinfo \
        tmux zip unzip vim xterm zstd \
        libyaml-dev libyaml-0-2:arm64 libyaml-dev:arm64 \
        libbsd-dev:arm64 && \
    # Using --break-system-packages for pip is fine for Dockerfiles if intended.
    python3 -m pip install --break-system-packages dtschema==2024.11 jinja2 ply GitPython requests kas==4.7 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    # Wget and tar are fine.
    wget -qO /tmp/gcc-linaro.tar.xz https://releases.linaro.org/components/toolchain/binaries/latest-7/aarch64-linux-gnu/gcc-linaro-7.5.0-2019.12-i686_aarch64-linux-gnu.tar.xz && \
    tar xf /tmp/gcc-linaro.tar.xz -C /usr/local/ && \
    rm /tmp/gcc-linaro.tar.xz && \
    # MKBOOTIMG: ensure the URL is stable and content is valid. Base64 decode is correct.
    curl -fsSL "https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/android12-release/mkbootimg.py?format=TEXT" | base64 --decode > /usr/bin/mkbootimg && \
    chmod +x /usr/bin/mkbootimg && \
    # Locale configuration. Use dpkg-reconfigure for system-wide locale generation.
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    # Setting default locale through /etc/default/locale and update-locale is good.
    echo 'LANG="en_US.UTF-8"' > /etc/default/locale && \
    update-locale LANG=en_US.UTF-8 && \
    # Cleanup apt caches and lists. This should be the last step in this RUN layer.
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb

# Ensure /bin/sh points to bash
# This should be done carefully as some scripts might expect /bin/sh to be dash.
# For this specific context, if bash is expected, this is correct.
RUN rm -f /bin/sh && ln -s /bin/bash /bin/sh

# Copy and set permissions for scripts
# Place this after main package installation to leverage Docker caching for base layers.
COPY generate_boot_bins.sh /usr/bin/
RUN chmod +x /usr/bin/generate_boot_bins.sh

# Switch to the non-root user for subsequent commands and the default for the container.
USER "$USER"

# Set the working directory for the non-root user.
WORKDIR "/home/$USER"
