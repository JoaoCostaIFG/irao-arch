# AGENTS.md

## What this repo is
A personal Arch Linux package repository (named `irao-arch`) hosted on S3-compatible storage. Packages are built from the AUR via `aurutils` and synced using `rclone`.

## Commands

```bash
# Sync AUR packages (builds locally, pushes to S3)
./sync-repo.sh              # build all tracked packages
./sync-repo.sh <pkgname>    # build/update a single package
./sync-repo.sh -u           # update all packages

# List all packages in the repo
./list-repo.sh

# Remove packages from the repo
./del-from-repo.sh <pkgname> [pkgname ...]

# Recreate the rclone remote (after credential changes)
./setup-remote.sh --recreate
```

## Setup

- Copy `.env.example` to `.env` and fill in S3 credentials (`S3_ENDPOINT`, `BUCKET_NAME`, `ACCESS_KEY_ID`, `ACCESS_KEY_SECRET`).
- Run `./setup-remote.sh` to create the `irao-arch` rclone remote.
- Requires: `rclone`, `aurutils`, `pacman-contrib`, `pacman`.

## Architecture

- `local-repo/` — local mirror of the S3 pacman repo (gitignored). Contains `.db`, `.files`, and built `.pkg.tar.{xz,zst}` files.
- `.env` — credentials; **never committed**, listed in `.gitignore`.
- `packages/` — local meta-packages (one subdirectory per package, each with a PKGBUILD). Built with `makepkg` and added to the repo by `sync-repo.sh`.
- CI (`.github/workflows/update-repo.yml`) runs daily at 04:00 UTC inside an `archlinux:latest` container, calls `./sync-repo.sh -u`.

## Gotchas

- `.env` **must** exist and contain `S3_ENDPOINT`, `BUCKET_NAME`, `ACCESS_KEY_ID`, `ACCESS_KEY_SECRET` for any script to run.
- The `local-repo/` directory is fully gitignored — no package binaries or DB files should ever be committed.
- `sync-repo.sh` and `del-from-repo.sh` both call `sudo pacsync` at the end. This requires passwordless sudo or a sudo token.
- All scripts use `set -uo pipefail` and an ERR trap; failures print the failing line number.
