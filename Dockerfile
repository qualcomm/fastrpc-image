FROM ubuntu:24.04

ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-linux-gnu-
ENV CXX=aarch64-linux-gnu-g++
ENV AS=aarch64-linux-gnu-as
ENV LD=aarch64-linux-gnu-ld
ENV RANLIB=aarch64-linux-gnu-ranlib
ENV STRIP=aarch64-linux-gnu-strip

COPY generate_boot_bins.sh /usr/bin

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential git clang-15 lld-15 flex bison bc libssl-dev curl kmod systemd-ukify rsync mtools dosfstools lavacli \
        gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
        python3-dev python3-pip swig yamllint python3-setuptools python3-wheel \
        yq automake \
        gh gcc g++ make autoconf automake libtool libelf-dev tar xz-utils llvm llvm-dev util-linux initramfs-tools pkg-config \
        abigail-tools sparse wget && \
    python3 -m pip install --break-system-packages dtschema==2024.11 jinja2 ply GitPython && \
    wget -c https://releases.linaro.org/components/toolchain/binaries/latest-7/aarch64-linux-gnu/gcc-linaro-7.5.0-2019.12-i686_aarch64-linux-gnu.tar.xz -O /tmp/gcc-linaro.tar.xz && \
    tar xf /tmp/gcc-linaro.tar.xz -C /usr/local/ && \
    rm /tmp/gcc-linaro.tar.xz && \
    curl -fsSL "https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/android12-release/mkbootimg.py?format=TEXT" | base64 --decode > /usr/bin/mkbootimg && \
    chmod +x /usr/bin/mkbootimg && \
    chmod +x /usr/bin/generate_boot_bins.sh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb
