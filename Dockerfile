FROM quay.io/fedora/fedora:39 AS builder

# Callers are expected to mount their butane file to this running container as '/build/config.bu'

WORKDIR /build

## Installation dependencies
# The installation scripts copied below also run dnf - I've explicitly decided *not* to extract those commands
# here, though, to reduce code-churn and keep the steps as close to the documentation as possible
RUN dnf install -y butane coreos-installer cpio gettext-envsubst jq rsync

## Installation scripts
COPY ./generate-ignition.sh /build/generate-ignition.sh
COPY ./update-efi-partition.sh /build/update-efi-partition.sh
