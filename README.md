# ubuntu26-ip-forward

Enable IPv4 forwarding (`net.ipv4.ip_forward = 1`) on **Ubuntu 26.04** hosts via
Ansible, with a [Molecule](https://ansible.readthedocs.io/projects/molecule/)
test suite that proves the behavior.

## Background

On Ubuntu 26.04 the standard method used to apply certain `sysctl` directives
stopped working for a subset of values. This project provides a small,
self-contained Ansible task that writes `/etc/sysctl.d/99-forwarding.conf` to
enable IP forwarding — but **only on Ubuntu 26.04**, so it's a no-op everywhere
else.

This is primarily intended for "project networks" that run nested tunnels and
require `ip_forward` to function.

## How it works

The role's task uses `ansible.builtin.copy` to write the sysctl drop-in file,
guarded by a `when:` clause that checks the gathered Ansible facts:

```yaml
when:
  - ansible_facts['os_family'] == 'Debian'
  - ansible_facts['distribution'] == 'Ubuntu'
  - ansible_facts['distribution_major_version'] == '26'
```
- The file is written to `/etc/sysctl.d/99-forwarding.conf` -- the `99-` prefix ensures it's applied last, overriding earlier drop-ins.
- The task is idempotent - `copy` only rewrites the file when content changes.
- On any non-Ubuntu-26 host the task is skipped.

> Note: This writes the persistent config file only. It does not apply the
> setting to the running kernel (that requires sysctl -p or a reboot). This
> matches the original echo | tee approach it replaces.

## Repository Layout

```
ubuntu26-ip-forward/
├── ip-forward.yml                # playbook: applies the ip-forward role to project_network
├── roles/
│   └── ip-forward/
│       ├── tasks/
│       │   └── main.yml          # the gated task (Ubuntu 26 only)
│       ├── defaults/
│       │   └── main.yml          # sysctl name/value/path
│       └── meta/
│           └── main.yml          # role metadata
├── molecule/
│   └── default/                  # converge applied the role; two platforms (26 + 24)
├── Justfile
├── README.md
└── .gitignore
```

## Quickstart

```bash
# 1. Clone the repository (SSH URL)
git clone git@gitlab.sysx.io:mckinleyk/ubuntu26-ip-forward.git
cd ubuntu26-ip-forward

# 2. Install `just` (one-time, system-wide)
brew install just          # macOS
# Linux: sudo apt install just

# 3. Set up the virtualenv and dependencies (once per clone)
just setup

# 4. Run the test suite
just test
```

`just test` runs the full lifecycle:
```
create → prepare → converge → idempotence → side_effect → verify → destroy
```
It spins up two throwaway containers (Ubuntu 26.04 and 24.04), applies the task
to both, asserts the correct end state on each, then tears everything down.

| STEP          | UBUNTU 26.04                             | UBUNTU 24.04   |
|---------------|------------------------------------------|----------------|
| `converge`    | task `changed` (file written)            | task `skipped` |
| `idempotence` | re-run reports `changed: 0`              | --             |
| `verify`      | file exists, mode `0644`, content correct | file absent    |

## Manual verification (optional)

```bash
just converge         # create + apply, leave containers running
just login [host]     # shell into ubuntu-24 or ubuntu-26 container

# inside the container:
cat /etc/sysctl.d/99-forwarding.conf
```

## Available just commands

This project uses [`just`](https://github.com/casey/just) to wrap the Molecule
workflow. Run `just --list` to see everything, or use one of these:

| Command | What it does |
|---|---|
| `just` / `just --list` | List the available commands. |
| `just setup` | One-time setup: creates the virtualenv and installs Molecule and its dependencies. Run this once after cloning. |
| `just test` | Runs the full test suite end to end — creates two throwaway containers (Ubuntu 26.04 and 24.04), applies the task, verifies the result, and tears everything down. No manual `source` or `DOCKER_HOST` needed. |
| `just converge` | Creates the containers **and** applies the task, then leaves them running so you can inspect them. Use this before logging in. |
| `just login ubuntu-26` | Shells into the Ubuntu 26.04 container (the default). |
| `just login ubuntu-24` | Shells into the Ubuntu 24.04 container. |
| `just destroy` | Tears down all test containers — Molecule's containers plus any leftover manual ones. |

> **Tip:** To poke at a live container, run `just converge` first, then
> `just login ubuntu-26`. Running `just login` on its own gives you a fresh,
> empty container where the task hasn't been applied yet.

## Scope & limitations

This is a proof of concept. Molecule verifies that the config file is written
correctly and idempotently. The following are not yet validated and should be
confirmed on a real host before production use:

- `become` path — Molecule's containers run as root, so the `become: true` in
  the production playbook isn't exercised. Confirm `become`/`sudo` works on real
  hosts.
- Real inventory — tests use Molecule's own inventory, not the production
  `hosts.yml`.

> **Verified on a real Ubuntu 26.04 host:** writing `/etc/sysctl.d/99-forwarding.conf`
> via the playbook, then `sudo sysctl -p`, applies `net.ipv4.ip_forward = 1` to
> the running kernel. The file-based approach also persists across reboot. This
> run also confirmed the `become: true` privilege-escalation path works on a real
> host — something the root-run Molecule containers couldn't exercise.

## Roadmap
- [x] Convert the playbook into a reusable Ansible role
- [x] Validate live kernal application on a real Ubuntu 26.04 host

> **Verified on a Ubuntu 26.04 host:** writing `/etc/sysctl.d/99-forwarding.conf`
> via the playbook, then `sudo sysctl -p`, applies `net.ipv4.ip_forward = 1` to the
> running kernel. The file-based approach also persists on reboot.