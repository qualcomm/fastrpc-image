# Copyright (c) 2025, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

#!/bin/bash

# If not provided, defaults to "ubuntu" with UID and GID of 1000
USER=${USER:-"ubuntu"}
USER_ID=${USER_ID:-1000}
GROUP_ID=${GROUP_ID:-1000}

# Create group if it doesn't exist
if ! getent group "$USER" > /dev/null; then
    groupadd -g "$GROUP_ID" "$USER"
fi

# Create user if it doesn't exist
if ! id -u "$USER" > /dev/null 2>&1; then
    useradd -m -u "$USER_ID" -g "$GROUP_ID" -s /bin/bash "$USER"
fi

# Add the user to sudo group
apt-get update
apt-get -qq install sudo
usermod -aG sudo "$USER"

# Add user to sudoers without password
echo "${USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/"$USER"
chmod 0440 /etc/sudoers.d/"$USER"
