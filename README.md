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

* `chaotic makepkg-run-{nspawn,chroot} ${INPUTDIR} $@`

    Runs a container.
    `$INPUTDIR` is the result of a `makepkg-gen`
    (Automatically runs `lower-prepare`)

* `chaotic packages-sync`

    Sync package list and their sources.

* `chaotic makepkg-deploy`

    Sign the package and append 

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