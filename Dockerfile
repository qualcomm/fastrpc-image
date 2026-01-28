
FROM ubuntu:24.04

# Use bash for RUN steps without changing /bin/sh globally
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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

# Create user early; clean /tmp content afterwards
RUN bash -xe -- create_user.sh && rm -rf -- /tmp/*

# Set timezone to UTC and configure apt for smaller images
RUN ln -snf /usr/share/zoneinfo/Etc/UTC /etc/localtime \
 && echo "Etc/UTC" > /etc/timezone \
 && { \
      echo 'APT::Install-Recommends "0";'; \
      echo 'APT::Install-Suggests "0";'; \
      echo 'APT::Get::Assume-Yes "1";'; \
    } > /etc/apt/apt.conf.d/99local

# Configure sources: amd64 from archive/security; arm64 from ports
# NOTE: No apt-get update here (avoid caching stale indexes)
RUN set -eux; \
    dpkg --add-architecture arm64; \
    CODENAME="$(. /etc/os-release; echo "${VERSION_CODENAME}")"; \
    : "${CODENAME:?Failed to read VERSION_CODENAME}"; \
    { \
      echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu ${CODENAME} main restricted universe multiverse"; \
      echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu ${CODENAME}-updates main restricted universe multiverse"; \
      echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu ${CODENAME}-backports main restricted universe multiverse"; \
      echo "deb [arch=amd64] http://security.ubuntu.com/ubuntu ${CODENAME}-security main restricted universe multiverse"; \
    } > /etc/apt/sources.list; \
    { \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${CODENAME} main restricted universe multiverse"; \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${CODENAME}-updates main restricted universe multiverse"; \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${CODENAME}-backports main restricted universe multiverse"; \
      echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports ${CODENAME}-security main restricted universe multiverse"; \
    } > /etc/apt/sources.list.d/arm64-ports.list; \
    rm -f /etc/apt/sources.list.d/ubuntu.sources || true

# Install required packages + tools
RUN set -eux; \
    apt-get update -o Acquire::Retries=5; \
    \
    # Core packages (should exist on 24.04)
    apt-get install -y --no-install-recommends -o Acquire::Retries=5 \
        apt-transport-https apt-utils software-properties-common \
        build-essential git flex bison bc libssl-dev curl kmod rsync \
        mtools dosfstools chrpath cpio debianutils diffstat file gawk \
        gpg-agent iputils-ping locales openssh-client socat texinfo tmux \
        zip unzip vim xterm zstd \
        gcc g++ make autoconf libtool pkg-config tar xz-utils wget \
        util-linux initramfs-tools \
        python3-dev python3-pip python3-setuptools python3-wheel \
        python3-git python3-pexpect \
        swig yamllint \
        libelf-dev llvm llvm-dev sparse abigail-tools \
        gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libc6-dev-arm64-cross \
        liblz4-tool; \
    \
    # arm64 runtime/dev libs (now that arm64 arch is enabled)
    apt-get install -y --no-install-recommends -o Acquire::Retries=5 \
        libyaml-dev libyaml-0-2:arm64 libyaml-dev:arm64 \
        libbsd-dev:arm64; \
    \
    # Optional / may be unavailable (do not fail the whole image)
    apt-get install -y --no-install-recommends -o Acquire::Retries=5 \
        fuseext2 libsdl1.2-dev yq || true; \
    \
    # clang/lld: Ubuntu 24.04 may not have clang-15, prefer fallback
    (apt-get install -y --no-install-recommends -o Acquire::Retries=5 clang-15 lld-15 || \
     apt-get install -y --no-install-recommends -o Acquire::Retries=5 clang lld) || true; \
    \
    # systemd-ukify can be missing depending on repo config
    apt-get install -y --no-install-recommends -o Acquire::Retries=5 systemd-ukify || true; \
    \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb

# Python dependencies
RUN set -eux; \
    python3 -m pip install --break-system-packages \
      dtschema==2024.11 jinja2 ply GitPython requests kas==4.7; \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# lavacli is mandatory: install via apt (preferred) with pip fallback
RUN set -eux; \
    apt-get update -o Acquire::Retries=5; \
    if ! apt-get install -y --no-install-recommends -o Acquire::Retries=5 lavacli; then \
        echo "APT install lavacli failed; falling back to pip"; \
        python3 -m pip install --break-system-packages lavacli; \
    fi; \
    command -v lavacli; \
    lavacli --help >/dev/null; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Install Linaro GCC toolchain
RUN set -eux; \
    wget -qO /tmp/gcc-linaro.tar.xz \
      https://releases.linaro.org/components/toolchain/binaries/latest-7/aarch64-linux-gnu/gcc-linaro-7.5.0-2019.12-i686_aarch64-linux-gnu.tar.xz; \
    tar xf /tmp/gcc-linaro.tar.xz -C /usr/local/; \
    rm -f /tmp/gcc-linaro.tar.xz

# Install mkbootimg
RUN set -eux; \
    curl -fsSL "https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/android12-release/mkbootimg.py?format=TEXT" \
      | base64 --decode > /usr/bin/mkbootimg; \
    chmod +x /usr/bin/mkbootimg

# Locale generation
RUN set -eux; \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen; \
    locale-gen en_US.UTF-8; \
    echo 'LANG="en_US.UTF-8"' > /etc/default/locale; \
    update-locale LANG=en_US.UTF-8

# Copy and set permissions for scripts
COPY generate_boot_bins.sh /usr/bin/
RUN chmod +x /usr/bin/generate_boot_bins.sh

# Switch to the non-root user
USER "$USER"
WORKDIR "/home/$USER"
