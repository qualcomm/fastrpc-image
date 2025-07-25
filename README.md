
# fastrpc-image

Docker image for building the FastRPC, Linux kernel and related components.

This project provides a Docker-based environment tailored for building the FastRPC, Linux kernel and associated binaries. It ensures consistency across development environments, especially when engineers use different versions of Ubuntu, Python, and other tools.

## 🚀 Features

- Build the Linux kernel and FastRPC binaries
- Package `boot.img`, `efi.bin`, and `dtb.bin`
- Validate DeviceTree bindings and sources
- Includes `ukify` and `mkbootimg` tools
- Handy shell aliases for streamlined Docker usage

---

## 🐳 Docker Installation

Follow the official Docker installation guide for Ubuntu:

👉 https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository

### Add User to Docker Group

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Restart your terminal or log out and back in. Verify with:

```bash
id
```

---

## 🔧 Build the Docker Image

Clone this repository and build the Docker image:

```bash
git clone git@github.com:qualcomm-linux/fastrpc-image.git
cd fastrpc-image
docker build -t fastrpc-image .
```

---

## 🛠️ Setup Aliases

Add the following to your `.bashrc` or shell config:

```bash
alias fastrpc-image-run='docker run -it --rm --user $(id -u):$(id -g) --workdir="$PWD" -v "$(dirname $PWD)":"$(dirname $PWD)" fastrpc-image'
alias fmake='fastrpc-image-run make'
```

---

## 🧪 Usage Examples

### Build Kernel

```bash
fmake defconfig
fmake -j$(nproc)
```

### Validate DeviceTree Bindings

```bash
fmake DT_CHECKER_FLAGS=-m dt_binding_check
fmake DT_CHECKER_FLAGS=-m DT_SCHEMA_FILES=soc/qcom/qcom,smem.yaml dt_binding_check
```

### Build and Validate DTB

```bash
fmake defconfig
fmake qcom/qcs6490-rb3gen2.dtb CHECK_DTBS=1
```

---

## 🧰 Generate Boot Binaries with `ukify`

```bash
fmake-image-run generate_boot_bins.sh efi --ramdisk artifacts/ramdisk.gz \
  --systemd-boot artifacts/systemd/usr/lib/systemd/boot/efi/systemd-bootaa64.efi \
  --stub artifacts/systemd/usr/lib/systemd/boot/efi/linuxaa64.efi.stub \
  --linux arch/arm64/boot/Image \
  --cmdline "${CMDLINE}" \
  --output images

fmake-image-run generate_boot_bins.sh dtb --input kobj/arch/arm64/boot/dts/qcom/qcs6490-rb3gen2.dtb \
  --output images
```

---

## 📦 Generate `boot.img` with `mkbootimg`

```bash
fmake-image-run mkbootimg \
  --header_version 2 \
  --kernel kobj/arch/arm64/boot/Image.gz \
  --dtb kobj/arch/arm64/boot/dts/qcom/sm8550-mtp.dtb \
  --cmdline "${CMDLINE}" \
  --ramdisk artifacts/ramdisk.gz \
  --base 0x80000000 \
  --pagesize 2048 \
  --output images/boot.img
```

---

## 🧩 Build FastRPC and Package into Ramdisk

```bash
git clone https://github.com/qualcomm/fastrpc/
cd fastrpc
export PATH="$PWD/gcc-linaro-7.5.0-2019.12-i686_aarch64-linux-gnu/bin/:$PATH"
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++
chmod 777 gitcompile
./gitcompile --host=aarch64-linux-gnu

mkdir -p fastrpc_dir/usr/{lib,bin}
cp -rf src/.libs/lib{adsp,cdsp,sdsp}_default_listener.so* fastrpc_dir/usr/lib/
cp -rf src/.libs/lib{adsprpc,cdsprpc,sdsprpc}.so* fastrpc_dir/usr/lib/
cp -rf src/{adsprpcd,cdsprpcd,sdsprpcd} fastrpc_dir/usr/bin/
cp -rf test/fastrpc_test test/linux/* test/v75/* fastrpc_dir/usr/bin/

cd fastrpc_dir
find . | cpio -o -H newc | gzip -9 > ../../fastrpc.cpio.gz
```

---

## 🧬 Add DSP Firmware and Create Final Ramdisk

```bash
git clone https://github.com/linux-msm/hexagon-dsp-binaries.git
git clone https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git

mkdir -p firmware_dir/usr/lib/dsp/{adsp,cdsp,cdsp1,gdsp0,gdsp1}
mkdir -p firmware_dir/lib/firmware/qcom/sa8775p

cp hexagon-dsp-binaries/... firmware_dir/usr/lib/dsp/...
cp linux-firmware/qcom/sa8775p/* firmware_dir/lib/firmware/qcom/sa8775p/

cd firmware_dir
find . | cpio -o -H newc | gzip -9 > ../../firmware.cpio.gz
cd ..
cat firmware.cpio.gz fastrpc.cpio.gz > artifacts/ramdisk.gz
```

---

## 📦 Package DLKMs into Ramdisk

```bash
(cd ../kobj/tar-install ; find lib/modules | cpio -o -H newc -R +0:+0 | gzip -9 >> ../../artifacts/ramdisk.gz)
```

---

## ⚡ Flash Binaries to Device

```bash
fastboot flash efi images/efi.bin
fastboot flash dtb_a images/dtb.bin
fastboot reboot
```

---

## 📜 License

This project is licensed under the https://spdx.org/licenses/BSD-3-Clause-Clear.html. See the https://github.com/qualcomm-linux/kmake-image/blob/main/LICENSE file for details.
```

---
