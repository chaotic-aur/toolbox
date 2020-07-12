# Chaotic AUR

Let's reinvent the wheel again

## CLI

* `chaotic makepkg-gen-{bash,dockerfile,simg} ${PACKAGETAG} $@`

    Generates a building script to be run in a containerized environment. 

    * `bash` for `arch-chroot` or SystemD-NSpawn.
    * `simg` for Singularity.
    * `dockerfile` for Docker or Podman. 

* `chaotic lower-prepare`

    Generates a lowerdir for later chrooting.

* `chaotic upper-prepare ${PACKAGETAG}`

    Generates a upperdir for later chrooting.
    (If needed, runs `base-prepare`)

* `chaotic makepkg-run-{nspawn,chroot} ${PACKAGETAG} $@`

    Runs a container.
    (if needed, runs `upper-prepare` and `makepkg-gen-bash`)

* `chaotic queue ${PACKAGE1TAG} ${PACKAGE2TAG}...`

    Add some packages to the building queue.
    

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