# Fedora CoreOS on Raspberry Pi 4

The official [Fedora CoreOS documentation](https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-raspberry-pi4/#_installing_fcos_and_booting_via_u_boot) provides a way to provision a Raspberry Pi 4b, but their instructions are only written for users that already have a RHEL derivative. The logic contained here containerizes the process, allowing any system with a functional (podman or docker) container engine and a working `make` installation to provision FCOS for Pis.

The process is encapsulated in Make targets so that it can easily be `include`-ed into other Makefiles or embedded into pipelines.

## Usage

### Building a FCOS image for Raspberry Pi 4
The default `build-fcos-image` target handles basic variable substitution, converting your butane file into an ignition file, running the coreos-installer application, and updating the EFI partition. In order to run this target, you must set the following environment variables:

* `FCOS_DISK` defines the device the image should be written to. For Raspberry Pis, this will almost always be an SD card.
* `BUTANE_FILE` defines the butane config the FCOS image should ignite from. For Fedora CoreOS, the latest spec (at the time of writing) is defined [here](https://coreos.github.io/butane/config-fcos-v1_5/), and helpful examples are available [here](https://coreos.github.io/butane/examples/#luks-encrypted-storage). The `build-fcos-image` target also performs basic variable substitution on the `BUTANE_FILE`. If the `BUTANE_FILE` contains environment variables, its expected that those are defined as non-empty strings. Refer to the [example](#-building-the-example-bu-image) for more information.

> [!CAUTION]
> The device specified by `FCOS_DISK` **will be overwritten** upon invoking `make`. This process is irreversible, and the value of `FCOS_DISK` should be double-checked before running!

> [!WARNING]
> In order to mount the `FCOS_DISK` to the coreos-installer container, the container must be run in `--privileged` mode. On most systems, this will require running `make` as root (you can also invoke a subshell via sudo with `sudo sh -c "FCOS_DISK=... make"`, if you prefer). On systems that utilize SELinux, see the [troubleshooting section](#-enable-device-mounts-on-selinux) for more info.

#### Building the example.bu image
As mentioned above, the `BUTANE_FILE` specified defines the other environment variables that need to be set. The [example file](./example.bu), for instance, includes a `${FCOS_USER}` and `${PUBLIC_SSH_KEY}` reference, so when we invoke `make` with `BUTANE_FILE=./example.bu`, we also need to include values for `FCOS_USER` and `PUBLIC_SSH_KEY`.

Run the following, substituting them for real values:
```bash
BUTANE_FILE=./example.bu FCOS_USER=myuser PUBLIC_SSH_KEY=mysshkey FCOS_DISK=mysdcard make
```

Once the the process is complete, eject the micro SD, insert it into the Pi 4, attach it to a display, and power it on. You should be able to watch the ignition process configure the OS on first boot. After it's complete, validate your user was created successfully by ssh-ing into the machine using the private half of the key provided earlier.

If needed, the ignition file created from your `BUTANE_FILE` used to configure the machine will saved as `./config.ign`, and can be used to double-check any substitution or (mis)configuration issues that appear.

### Caching images
Each time its invoked, the `build-fcos-image` runs the `coreos-installer` container, which, re-downloads the FCOS image file. Doing this repeatedly wastes time and adds burden to network resources.

You can cache the image file by running

```bash
DOWNLOAD_DIR=/tmp make download-fcos-image
```

The full path to the downloaded image is printed as the last line of output. `export` or include it when invoking `make build-fcos-image` like the following

```bash
... FCOS_IMAGE_FILE=<path to file> ... make build-fcos-image
```

### Help

The [Makefile](./Makefile) defined here ships with a `help` target (shamelessly stolen from the one operator-sdk gives you). This is useful for discovering additional targets defined by this [Makefile](./Makefile) or other Makefiles that `include` this one.

```bash
make help
```

## Troubleshooting

### Enable device mounts on SELinux
The `build-fcos-image` target makes use of containers running in `--privileged` mode to flash the disk, which A) requires *root* permissions, and B) may conflict with selinux's default policies on certain machines.

If you get any selinux looking errors, you may need to run

```bash
setsebool -P container_use_devices=true
```
prior to running `make`.
