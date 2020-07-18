# Chaotic AUR

Let's reinvent the wheel again

## CLI

* `chaotic makepkg-gen-{bash,dockerfile,simg} ${PACKAGETAG} ${OUTPUTDIR} $@`

    Generates a building script to be run in a containerized environment. 

    * `bash` for `arch-chroot` or SystemD-NSpawn.
    * `simg` for Singularity.
    * `dockerfile` for Docker or Podman. 

* `chaotic lower-prepare`

    Generates a lowerdir for later chrooting.

* `chaotic makepkg-run-{nspawn,chroot,docker,singularity} ${INPUTDIR} $@`

    Runs a container.
    `$INPUTDIR` is the result of a `makepkg-gen`

* `chaotic sync`

    Sync package list and their sources.

* `chaotic deploy ${INPUTDIR}`

    Sign the package and append

* `chaotic queue-run-{nspawn,chroot,docker,singularity} ${QUEUENAME_OR_PATH}`

    Generates, builds, and deploy an entire queue of packages.

* `chaotic db-bump`

    Add recent deployed packages to the database.
    Move older packages to archive.
    Uses `repoctl`

* `chaotic cleanup ${INPUTDIR}`

    Safely deletes old package sources.

## Involved directories

* `/var/cache/chaotic/sources/${PACKAGETAG}`

    Per-package `SRCDEST`.

* `/var/cache/chaotic/base/{latest,$DATESTAMP}`

    Lowerdirs.

* `/var/cache/chaotic/cc/{PACKAGETAG}`

    Per-package `~/.ccache`.

* `/var/lib/chaotic`

    Cloned version of [packages' repository](https://github.com/chaotic-aur/packages)

* `/tmp/chaotic-queue`

    Current queue of packages.


# Dependencies

`pacman -S --needed base-devel git arch-install-scripts`

You must have an active mirror of chaotic-aur running locally and some signing key!

## Installation

`sudo make install`