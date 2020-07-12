# Chaotic AUR

Let's reinvent the wheel again

## CLI

* `chaotic makepkg-{bash,dockerfile,simg} ${PACKAGETAG} $@`

    Generates a building script to be run in a containerized environment. 

## Involved directories

* `/var/cache/chaotic/sources/${PACKAGETAG}`

    Holds source cache

* `/var/cache/chaotic/base/{latest,$DATA}`

* `/var/cache/chaotic/cc/{PACKAGETAG}`

* `/var/lib/chaotic/entries/${PACKAGETAG}`

* `/tmp/chaotic-queue`