# Chaotic AUR

Let us reinvent the wheel once more.

## CLI

* `chaotic makepkg-gen-{bash,dockerfile,simg} ${PACKAGETAG} ${OUTPUTDIR} $@`

    It generates a building script to be later run in a containerized environment. 

    * `bash` for `arch-chroot` or SystemD-NSpawn.
    * `simg` for Singularity.
    * `dockerfile` for Docker or Podman. 

* `chaotic lower-prepare`

    It generates a lowerdir for later chrooting.

* `chaotic makepkg-run-{nspawn,chroot,docker,singularity} ${INPUTDIR} $@`

    Runs a container.
    `$INPUTDIR` is the result of a `makepkg-gen`

* `chaotic sync`

    It syncs package list and their sources.

* `chaotic deploy ${INPUTDIR}`

    Sign the package and append

* `chaotic queue-run-{nspawn,chroot,docker,singularity} ${QUEUENAME_OR_PATH}`

    It generates, builds, and deploys an entire queue of packages.

* `chaotic db-bump`

    Add recently deployed packages to the database.
    Move older packages to archive.
    Uses `repoctl`

* `chaotic cleanup ${INPUTDIR}`

    Safely deletes old package sources.

## Involved directories

* `/var/cache/chaotic/sources/${PACKAGETAG}`

    Per-package `SRCDEST`.

* `/var/cache/chaotic/lower/{latest,$DATESTAMP}`

    Lowerdirs.

* `/var/cache/chaotic/cc/{PACKAGETAG}`

    Per-package `~/.ccache`.

* `/var/cache/chaotic/packages`

    Container-shared pacman's cache.

* `/var/lib/chaotic`

    Cloned version of [packages' repository](https://github.com/chaotic-aur/packages)

* `/tmp/chaotic/queues`

    Current running queues.


# Dependencies

`pacman -S --needed base-devel git arch-install-scripts repoctl-devel`

One must have an active mirror of chaotic-aur running locally and some signing key. Configure them in `/etc/chaotic.conf`, like this:

```sh
export CAUR_DEST_PKG="/var/www/chaotic-aur/x86_64"
export CAUR_URL="http://localhost:8080/chaotic-aur/x86_64"
export CAUR_SIGN_KEY='8A9E14A07010F7E3'
```

## Installation

`sudo make install`