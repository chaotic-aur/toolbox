# Chaotic AUR

Let us reinvent the wheel once more.

## CLI

* `chaotic makepkg-gen-{bash,dockerfile,simg} ${PACKAGETAG} ${OUTPUTDIR} $@`

    It generates a building script to be later run in a containerized environment. 

    * `bash` for `arch-chroot` or `systemd-nspawn`.
    * `simg` for Singularity.
    * `dockerfile` for Docker or Podman.

    TODO: `-dockerfile` and `-simg` are not done yet.

* `chaotic lower-prepare`

    It generates a lowerdir for later chrooting.

* `chaotic makepkg-run-{nspawn,chroot,docker,singularity} ${INPUTDIR} $@`

    Runs a container.
    `$INPUTDIR` is the result of a `makepkg-gen`

    TODO: `-chroot`, `-docker` and `-singularity` are not done yet.

* `chaotic sync`

    It syncs package list and their sources.

* `chaotic deploy ${INPUTDIR}`

    Sign the package and append

* `chaotic queue-run-{nspawn,chroot,docker,singularity} ${QUEUENAME_OR_PATH}`

    It generates, builds, and deploys an entire queue of packages.

    TODO: `-chroot`, `-docker` and `-singularity` are not done yet.

* `chaotic db-bump`

    It adds recently deployed packages to the database, while moving replaced packages to archive.
    Uses `repoctl`.

* `chaotic cleanup ${INPUTDIR}`

    Safely deletes old package sources.

* `chaotic queue-srvc-{add,rem} ${QUEUENAME}`

    (TODO)
    Add or remove some queue systemd's unit.

* `chaotic queue-srvc{,-timer} ${QUEUENAME} {enable,disable,start,stop,status}`

    (TODO)
    Forward command to systemd.

* `chaotic queue-srvc-journal{,-reverse,-follow} ${QUEUNAME}`

    (TODO)
    Access the queue unit logs in journal.

* `chaotic upgrade`

    (TODO)
    Upgrade the infra executable/libraries.

* `chaotic repo-{health,cure}`

    (TODO)
    Check/Fix missing signatures, duplicate packages, cache corruption, and conflicts with archlinux's official repositories.

* `chaotic mirror-install {syncthing,rsync}`

    Install/Upgrade one of the mirroring services.
    RSync is one-way (primary->cluster) only, and Syncthing both ways.

* `chaotic analytics-feed-httpd-logs`

    (TODO)
    Uploads httpd (Apache and Nginx) logs entries to the main analytics database.

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
export CAUR_TYPE='cluster'
```

You'll find more options in `src/chaotic` first lines.

Supported `type` values are: `primary`, `cluster`, and `dev`.

## Installation

`sudo make install`