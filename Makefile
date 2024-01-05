CONTAINER_ENGINE ?= $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)
CONTAINER_NAME ?= fcos-image-builder
CONTAINER_TAG ?= $(shell date '+%Y-%m-%d_%H%M%S')

# FCOS_IMAGE_FILE defines the image file to use when flashing the FCOS_DISK. If undefined, the latest
# image will be pulled automatically by the coreos-installer
FCOS_IMAGE_FILE ?= ""

# Stolen from https://stackoverflow.com/a/5982798
THIS_MAKEFILE:=$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
THIS_DIR ?= $(shell dirname ${THIS_MAKEFILE})

.PHONY: build-fcos-image
build-fcos-image: generate-ignition run-coreos-installer update-efi-partition ## build-fcos-image flashes Fedora CoreOS for Raspberry Pi 4 onto a device specified by $FCOS_DISK. $BUTANE_FILE must be set to the path of a valid butane file

.PHONY: update-efi-partition
update-efi-partition: guard-CONTAINER_ENGINE guard-CONTAINER_NAME guard-FCOS_DISK ## update-efi-partition updates the EFI partition, per steps specified by upstream documentation
	@echo
	@echo "$$(tput bold)Updating the EFI partition$$(tput sgr0)"
	${CONTAINER_ENGINE} run --privileged --rm --env FCOS_DISK -v /dev:/dev -v /run/udev:/run/udev ${CONTAINER_NAME}:latest ./update-efi-partition.sh

.PHONY: run-coreos-installer
run-coreos-installer: guard-CONTAINER_ENGINE guard-FCOS_DISK ## run-coreos-installer runs the latest release coreos-installer container to flash the specified $FCOS_DISK. The current directory is expected to contain a 'config.ign' file.
	@echo
	@echo "$$(tput bold)Running coreos-installer$$(tput sgr0)"
	set -x; if [ -z ${FCOS_IMAGE_FILE} ]; then \
		${CONTAINER_ENGINE} run --privileged --rm -v /dev:/dev -v /run/udev:/run/udev -v .:/data -w /data quay.io/coreos/coreos-installer:release install ${FCOS_DISK} -i config.ign; \
	else \
		FCOS_IMAGE_DIR="$$(dirname ${FCOS_IMAGE_FILE})"; \
		${CONTAINER_ENGINE} run --privileged --rm -v $${FCOS_IMAGE_DIR}:$${FCOS_IMAGE_DIR} -v /dev:/dev -v /run/udev:/run/udev -v .:/data -w /data quay.io/coreos/coreos-installer:release install ${FCOS_DISK} -i config.ign -f ${FCOS_IMAGE_FILE}; \
	fi

.PHONY: download-fcos-image
download-fcos-image: guard-CONTAINER_ENGINE guard-DOWNLOAD_DIR  ## download-fcos-image downloads the latest stable FCOS image to the provided $DOWNLOAD_DIR
	${CONTAINER_ENGINE} run --rm -v ${DOWNLOAD_DIR}:${DOWNLOAD_DIR} quay.io/coreos/coreos-installer:release download -s stable -a aarch64 -p metal --directory=${DOWNLOAD_DIR}

.PHONY: generate-ignition
generate-ignition: guard-CONTAINER_ENGINE guard-BUTANE_FILE guard-CONTAINER_NAME create-builder-image ## generate-ignition creates the ignition file from the provided $BUTANE_FILE
	@echo
	@echo "$$(tput bold)Creating ignition file$$(tput sgr0)"
	${CONTAINER_ENGINE} run --mount type=bind,source=${BUTANE_FILE},target=/build/config.bu,readonly --env-host ${CONTAINER_NAME}:latest ./generate-ignition.sh > config.ign
	@echo "config.ign:"
	@cat config.ign

.PHONY: create-builder-image
create-builder-image: guard-CONTAINER_ENGINE guard-CONTAINER_NAME guard-CONTAINER_TAG guard-THIS_DIR ## create-builder-image creates the fcos builder container. This container is responsible for converting butane files to ignition files and updating the EFI partition after running the coreos-installer
	${CONTAINER_ENGINE} build -t ${CONTAINER_NAME}:latest -t ${CONTAINER_NAME}:${CONTAINER_TAG} ${THIS_DIR}

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

guard-%: ## guard-% validates that the environment variable specified for '%' is set. ie - 'guard-FCOS_DISK' validates that '$FCOS_DISK' is set to a non-empty value
	@if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* not set"; \
		exit 1; \
	fi
