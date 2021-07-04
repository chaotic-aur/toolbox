# Chaotic AUR

## Disclaimer

I receive questions like "Why didn't you write it in language X? Why didn't you use sudoers instead of `setuid`? Why don't you guarantee reproducible builds? Why don't you use submodules and review every PKGBUILD change?"

Because I can't, I am only one person, taking care of all the steps required for updating 3800 packages non-stop, treating all the differences between those PKGBUILDs and their sources, in an infra that runs in donated VMs which are not any similar.

If at some point you see something that could be better, then please open a PR. And keep it simple, the more complex the codebase becomes, the more complicated will be in the future for one man alone to maintain it.

## CLI

- `chaotic pr{,epare} ${INPUTDIR} $@`

  It generates a building script to be later run in a containerized environment.
  `$INPUTDIR` is the name of directory in "$PWD" which contains a PKGBUILD.

- `chaotic {lw,lowerstrap}`

  It generates a lowerdir for later chrooting.

- `chaotic {mk,makepkg} ${INPUTDIR} $@`

  Builds the package in a container using systed-nspawn.
  `$INPUTDIR` is the result of a `prepare`

- `chaotic {mkd,makepwd} [${PACKAGES[@]}]`

  Prepare and build all packages in the current directory.
  If `PACKAGES` are not provided then it will try to build all sub-directories.

- `chaotic {si,iterfere-sync}`

  Sync packages' interference repo.

- `chaotic {sp,package-lists-sync}`

  Sync package list repo.

- `chaotic {dp,deploy} ${INPUTDIR}`

  Sign the package and send to primary node.

- `chaotic {dbb,db-bump}`

  Add recently deployed packages to the database, while moving replaced packages to archive.
  Uses `repoctl`.

- `chaotic {rm,remove} ${PACKAGES[@]}`

  Remove and archive all listed packages.
  Uses `repoctl`.

- `chaotic {get,aur-download} [-r] ${PACKAGES[@]}`

  Download listed packages' sources from AUR.
  Uses `repoctl`.

- `chaotic cl{,eanup} ${INPUTDIR}`

  Safely deletes old package sources.

- `chaotic help {syncthing,rsync}`

  Instructions to the mirroring services.
  RSync is one-way (primary->cluster) only, and Syncthing both ways.

- `chaotic routine {hourly,morning,afternoon,nightly,midnight}`

  Run the specified routine.

- `chaotic routine clean-archive`

  When on a primary node, clean up the archive folder.

- `chaotic {clg,clean-logs}`

  After a `chaotic makepwd`, remove successfull and "already built" logs.

- `chaotic {cls,clean-srccache} ${PACKAGE}`

  Removes cached sources from a specific package.

## Involved directories

- `/var/cache/chaotic/sources/${PACKAGETAG}`

  Per-package `SRCDEST`.

- `/var/cache/chaotic/lower/{latest,$DATESTAMP}`

  Lowerdirs.

- `/var/cache/chaotic/cc/{PACKAGETAG}`

  Per-package `~/.ccache`.

- `/var/cache/chaotic/packages`

  Container-shared pacman's cache.

- `/var/lib/chaotic/interfere`

  Cloned version of [interfere repository](https://github.com/chaotic-aur/interfere)

# Dependencies

`pacman -S --needed base-devel git arch-install-scripts repoctl fuse-overlayfs rsync python-telegram-send`

One needs an active mirror or a setting (in /etc/chaotic.conf) like this:

```sh
export CAUR_URL='https://builds.garudalinux.org/repos/chaotic-aur/x86_64'
export REPOCTL_CONFIG='/etc/chaotic/repoctl.conf'
export CAUR_REPOCTL_DB_URL="${CAUR_URL}/chaotic-aur.db.tar.zst"
export CAUR_REPOCTL_DB_FILE="/tmp/chaotic/db.tar.zst"
```

To create a gpg key for the root user refer to this [ArchWiki article](https://wiki.archlinux.org/index.php/GnuPG#Create_a_key_pair) for more information. If you find problems when using "sudo", read the "[su](https://wiki.archlinux.org/index.php/GnuPG#su)" subsection.
Then generate a ssh keypair for the root user.

```sh
sudo ssh-keygen
```

The ssh public key (cat /root/.ssh/id_rsa.pub) then needs to be added to the primary servers root authorized keys (/root/.ssh/authorized_keys). After that follow these [instructions](https://wiki.archlinux.org/index.php/GnuPG#Export_your_public_key) to export the gpg public key. This key will have to be [uploaded](https://wiki.archlinux.org/index.php/GnuPG#Sending_keys) to [keyserver.ubuntu.com](keyserver.ubuntu.com) in order for the key to be verified.
Then, configure it as follows in `/etc/chaotic.conf`, like this:

```sh
export CAUR_DEPLOY_PKGS="/var/www/chaotic-aur/x86_64"
export CAUR_URL="http://localhost:8080/chaotic-aur/x86_64"
export CAUR_SIGN_KEY='8A9E14A07010F7E3'
export CAUR_TYPE='cluster'
export REPOCTL_CONFIG='/etc/chaotic/repoctl.toml'
```

You'll find more options in `src/chaotic` first lines.

Supported `type` values are: `primary`, `cluster`, and `dev`.

To have clean logs & less bandwidth usage `/etc/pacman.conf` settings need to be adjusted:

- Enable `NoProgressBar`

- Use `Server = file:///path-to-local-repo` as repo link if a local mirror is available

- Don't use `ILoveCandy`

To deploy faster replace `openssh` with `openssh-hpn` on all nodes (adds peformance related [patches](https://www.psc.edu/research/networking/hpn-ssh/)).

## Installation

Install dependencies, then:

```
sudo groupadd chaotic_op
sudo usermod -aG chaotic_op $(whoami)

make build && sudo make install
```

## Lint

```sh
pacman -S --needed yarn shellcheck
yarn install
yarn run lint
```
