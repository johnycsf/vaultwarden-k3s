# Credits

This repository packages and automates deployment. Credit for the applications belongs to their upstream developers.

## Vaultwarden

- **Vaultwarden** — [Dani García](https://github.com/dani-garcia) and contributors ([dani-garcia/vaultwarden](https://github.com/dani-garcia/vaultwarden))
- Official image: [`vaultwarden/server`](https://hub.docker.com/r/vaultwarden/server)
- **Kubernetes** — [kubernetes/kubernetes](https://github.com/kubernetes/kubernetes)

Vaultwarden is an unofficial Bitwarden®-compatible server implementation. **Bitwarden** is a trademark of Bitwarden Inc. This repo is not affiliated with or endorsed by Bitwarden Inc., the Vaultwarden maintainers, or the Kubernetes project.

## Shared johnycsf tooling

These install/manage/backup helpers are used across johnycsf stacks. Credit the upstream projects:

| Tool | Role in this repo | Upstream |
|------|-------------------|----------|
| **gum** | Arrow-key interactive menus in `./manage.sh` | [charmbracelet/gum](https://github.com/charmbracelet/gum) |
| **age** | Optional encrypted offsite backup exports (`./backup.sh --encrypt`) | [FiloSottile/age](https://github.com/FiloSottile/age) |
| **rsync** | Incremental hardlink snapshot backups | [rsync.samba.org](https://rsync.samba.org/) / your OS package |
| **Docker** / **Docker Compose** | Container runtime for app stacks | [docker.com](https://www.docker.com/) |
| **whiptail** / **newt** | Fallback interactive menus if gum is unavailable | newt / Debian `whiptail` |
| **Catppuccin** | Color inspiration for the pastel terminal UI | [catppuccin/catppuccin](https://github.com/catppuccin/catppuccin) |

When you add a new helper tool or feature dependency, **add it here** (and in `repo-framework`’s template) in the same PR.
