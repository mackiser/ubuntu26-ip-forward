# ubuntu26-ip-forward

An Ansible role that enables IPv4 forwarding (`net.ipv4.ip_forward = 1`) on
**Ubuntu 26.04** hosts, and only there. It comes with a
[Molecule](https://ansible.readthedocs.io/projects/molecule/) test suite that
checks the behavior on both Ubuntu 26.04 and 24.04.

## Description

### Background

On Ubuntu 26.04, the usual way of applying some `sysctl` directives stopped
working for certain values. This role replaces the old `echo | tee` approach
with a small Ansible task that writes `/etc/sysctl.d/99-forwarding.conf`. It
only does this on Ubuntu 26.04 and does nothing on any other host.

### Features

- **Ubuntu 26.04 only:** the tasks are gated on gathered facts, so every other
  host is skipped:
  ```yaml
  when:
    - ansible_facts['os_family'] == 'Debian'
    - ansible_facts['distribution'] == 'Ubuntu'
    - ansible_facts['distribution_major_version'] == '26'
  ```
- **Applied last:** the drop-in uses a `99-` prefix, so it overrides any
  earlier files in `/etc/sysctl.d/`.
- **Idempotent:** the file is only rewritten when its content changes.
- **Optional live apply:** by default only the persistent config file is
  written, so the setting takes effect on the next reboot (or `sysctl -p`). Set
  `sysctl_forward_apply_live: true` to also apply it to the running kernel
  right away with `ansible.posix.sysctl`.

## Installation

### Requirements

| Requirement | Used for |
|---|---|
| Ansible with the `ansible.posix` collection | Running the role (`ansible-galaxy collection install ansible.posix`) |
| Python 3 | The Molecule virtualenv |
| Docker (for example Docker Desktop) | The throwaway test containers |
| [`just`](https://github.com/casey/just) | The command shortcuts below |

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/mackiser/ubuntu26-ip-forward.git
cd ubuntu26-ip-forward

# 2. Install `just` (one-time, system-wide)
brew install just          # macOS
# Linux: sudo apt install just

# 3. Set up the virtualenv and test dependencies (once per clone)
just setup
```

## Usage

### Running the playbook

`ip-forward.yml` applies the role, with `become: true`, to every host in the
`project_network` inventory group:

```bash
ansible-playbook -i <your-inventory> ip-forward.yml
```

On Ubuntu 26.04 hosts the task reports `changed` the first time and `ok` after
that. All other hosts report `skipped`.

### Configuration

Override any of these variables (from `roles/ip-forward/defaults/main.yml`) in
your inventory, `group_vars`, or with `-e`:

| Variable | Default | Description |
|---|---|---|
| `sysctl_forward_name` | `net.ipv4.ip_forward` | The sysctl directive to set |
| `sysctl_forward_value` | `1` | The value to assign |
| `sysctl_forward_path` | `/etc/sysctl.d/99-forwarding.conf` | Target drop-in file |
| `sysctl_forward_apply_live` | `false` | If `true`, also apply the setting to the running kernel immediately instead of waiting for a reboot |

For example, to apply the setting live, add this to `group_vars`:

```yaml
---
sysctl_forward_apply_live: true
```

### Available just commands

This project uses `just` to wrap the Molecule workflow. Run `just --list` to see
all of them.

| Command | What it does |
|---|---|
| `just` / `just --list` | Lists the available commands. |
| `just setup` | One-time setup: creates the virtualenv and installs Molecule and its dependencies. |
| `just test` | Runs the full test suite end to end. No manual `source` or `DOCKER_HOST` needed. |
| `just converge` | Creates the containers **and** applies the role, then leaves them running so you can inspect them. |
| `just login ubuntu-26` | Opens a shell in the Ubuntu 26.04 container. |
| `just login ubuntu-24` | Opens a shell in the Ubuntu 24.04 container. |
| `just destroy` | Removes all test containers, including Molecule's and any leftover manual ones. |

## Testing

```bash
just test
```

This runs the full Molecule lifecycle:

```
create → prepare → converge → idempotence → side_effect → verify → destroy
```

It starts two throwaway containers (Ubuntu 26.04 and 24.04), applies the role
to both, checks the end state on each, and then removes them. Expected results:

| Step | Ubuntu 26.04 | Ubuntu 24.04 |
|---|---|---|
| `converge` | task `changed` (file written) | task `skipped` |
| `idempotence` | re-run reports `changed: 0` | -- |
| `verify` | file exists, owned by root, mode `0644`, content correct | file absent |

### Manual verification

```bash
just converge           # create the containers and apply the role, leave them running
just login ubuntu-26    # open a shell in the container

# inside the container:
cat /etc/sysctl.d/99-forwarding.conf
```

> **Tip:** run `just converge` before `just login`. Running `just login` on its
> own gives you a fresh, empty container where the role hasn't been applied yet.

## Repository layout

```
ubuntu26-ip-forward/
├── ip-forward.yml                # playbook: applies the ip-forward role to project_network
├── roles/
│   └── ip-forward/
│       ├── tasks/main.yml        # the gated tasks (Ubuntu 26 only)
│       ├── defaults/main.yml     # sysctl name/value/path and the live-apply flag
│       └── meta/main.yml         # role metadata (requires ansible.posix)
├── molecule/
│   └── default/                  # Molecule scenario: two platforms (26.04 + 24.04), testinfra verifier
├── Justfile
├── README.md
└── .gitignore
```

## Support

Open an issue on the
[GitHub issue tracker](https://github.com/mackiser/ubuntu26-ip-forward/issues).

## Roadmap

- [x] Convert the playbook into a reusable Ansible role
- [x] Validate live kernel application on a real Ubuntu 26.04 host
- [x] Add an opt-in live-application flag (`sysctl_forward_apply_live`)

## Contributing

Contributions are welcome. Before opening a pull request:

1. Run `just setup` once after cloning.
2. Make your change.
3. Run `just test` and make sure every step passes on both platforms.

## Authors and acknowledgment

Maintained by [mackiser](https://github.com/mackiser).

## License

No license has been chosen yet.

## Project status

Feature-complete for its original purpose. Development is in maintenance mode.
