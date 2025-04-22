FROM ubuntu:24.04

ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-linux-gnu-

COPY generate_boot_bins.sh /usr/bin

RUN apt-get update && \
    apt-get install -y build-essential git clang-15 lld-15 flex bison bc libssl-dev curl kmod systemd-ukify rsync mtools dosfstools && \
    apt-get install -y gcc-aarch64-linux-gnu && \
    apt-get install -y python3-pip swig yamllint && \
    apt install -y python3-setuptools python3-wheel && \
    apt install -y pipx && \
    pipx install dtschema && \
    curl "https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/android12-release/mkbootimg.py?format=TEXT" | base64 --decode > /usr/bin/mkbootimg && \
    chmod +x /usr/bin/mkbootimg && \
    chmod +x /usr/bin/generate_boot_bins.sh && \
    rm -rf /var/lib/apt/lists/*
