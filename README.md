# irao-arch

A personal Arch Linux package repository hosted on S3 storage. Packages are built from the AUR via `aurutils`, and custom meta-packages are built from local PKGBUILDs. Everything is synced to S3 using `rclone`. AUR packages are tracked in `aur-packages.conf`.

Inspiration/guide by [disconnected.systems](https://disconnected.systems/blog/archlinux-repo-in-aws-bucket/).

## Setup

1. Copy `.env.example` to `.env` and fill in your S3 credentials (`S3_ENDPOINT`, `BUCKET_NAME`, `ACCESS_KEY_ID`, `ACCESS_KEY_SECRET`).
2. Run `./setup-remote.sh` to create the `irao-arch` rclone remote.
3. Add the repo to `/etc/pacman.conf`:

```
[irao-arch]
SigLevel = Optional TrustAll
Server = <S3_ENDPOINT>/<BUCKET_NAME>/x86_64/
```

**Requirements:** `rclone`, `aurutils`, `pacman-contrib`, `pacman`, `base-devel`.

## Usage

### Sync packages to the repo

```bash
./sync-repo.sh              # build all local meta-packages + sync tracked AUR packages
./sync-repo.sh irao-base    # build a single local meta-package
./sync-repo.sh some-pkg     # add/track an AUR package
./sync-repo.sh -u           # update all packages (local + AUR)
```

Local meta-packages live in `packages/<name>/PKGBUILD` and are built with `makepkg`. AUR packages are built and tracked via `aur sync`. Both end up in the same repo and are pushed to S3.

### List packages in the repo

```bash
./list-repo.sh
```

### Remove packages from the repo

```bash
./del-from-repo.sh <pkgname> [pkgname ...]
```

### Update AUR dependency list

```bash
./update-aur-deps.sh
```

Scans all `packages/*/PKGBUILD` dependency lists, identifies which ones are AUR packages (not in official repos and not a local meta-package), and adds any missing ones to `aur-packages.conf`.

**Note:** this is not called automatically by `sync-repo.sh`. I prefer to only add AUR packages that are needed to bootstrap my systems. In this case this is aurutils and paru (or yay). I do this to prevent problems related to building -git packages in other systems.

### Mark meta-package dependencies

After installing meta-packages on a system, dependencies may still be marked as explicitly installed. To fix this:

```bash
./mark-asdeps.sh
```

This marks all dependencies of any installed meta-package as dependency-installed, so they show up as orphans if the meta-package is later removed.

### Recreate rclone remote

```bash
./setup-remote.sh --recreate
```

## Adding a new meta-package

Create `packages/<name>/PKGBUILD` with `depends=(...)` listing the packages you want.

**Note:** bump `pkgver` or `pkgrel` whenever you change the dependency list for pacman to see the update.

## How it works

1. Remote repo DB is synced from S3 to `local-repo/`.
2. Local meta-packages are built with `makepkg` and added to the DB with `repo-add`.
3. AUR packages are built and added via `aur sync`.
4. All built packages and the updated DB are pushed to S3 via `rclone`.
5. The local pacman DB is refreshed with `pacsync`.

CI (`.github/workflows/update-repo.yml`) runs daily at 04:00 UTC inside an `archlinux:latest` container and calls `./sync-repo.sh -u` to keep packages up to date.
