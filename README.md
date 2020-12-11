# Chaotic AUR

Let us reinvent the wheel once more.

## CLI

* `chaotic prepare ${INPUTDIR} $@`

    It generates a building script to be later run in a containerized environment. 
    `$INPUTDIR` is the name of directory in "$PWD" which contains a PKGBUILD.

* `chaotic lowerstrap`

    It generates a lowerdir for later chrooting.

* `chaotic makepkg ${INPUTDIR} $@`

    Builds the package in a container using systed-nspawn.
    `$INPUTDIR` is the result of a `prepare`

* `chaotic sync`

    It syncs package interference.

* `chaotic deploy ${INPUTDIR}`

    Sign the package and send to primary node.

* `chaotic db-bump`

    It adds recently deployed packages to the database, while moving replaced packages to archive.
    Uses `repoctl`.

* `chaotic cleanup ${INPUTDIR}`

    Safely deletes old package sources.

* `chaotic help-mirror {syncthing,rsync}`

    Instructions to the mirroring services.
    RSync is one-way (primary->cluster) only, and Syncthing both ways.

## Involved directories

* `/var/cache/chaotic/sources/${PACKAGETAG}`

    Per-package `SRCDEST`.

* `/var/cache/chaotic/lower/{latest,$DATESTAMP}`

    Lowerdirs.

* `/var/cache/chaotic/cc/{PACKAGETAG}`

    Per-package `~/.ccache`.

* `/var/cache/chaotic/issues/{PACKAGETAG}`

    Per-package auto-detected issues. (TODO)

* `/var/cache/chaotic/packages`

    Container-shared pacman's cache.

* `/var/lib/chaotic/interfere`

    Cloned version of [interfere repository](https://github.com/chaotic-aur/interfere)

# Dependencies

`pacman -S --needed base-devel git arch-install-scripts repoctl aurutils`

One must have an active mirror of chaotic-aur running locally and some signing key. Configure them in `/etc/chaotic.conf`, like this:

```sh
export CAUR_DEST_PKG="/var/www/chaotic-aur/x86_64"
export CAUR_URL="http://localhost:8080/chaotic-aur/x86_64"
export CAUR_SIGN_KEY='8A9E14A07010F7E3'
export CAUR_TYPE='cluster'
```

You'll find more options in `src/chaotic` first lines.

Supported `type` values are: `primary`, `cluster`, and `dev`.

## Installation

`sudo make install`