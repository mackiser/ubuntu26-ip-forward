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

The task uses `ansible.builtin.copy` to write the sysctl drop-in file, guarded
by a `when:` clause that checks the gathered Ansible facts:

```yaml
when:
  - ansible_facts['os_family'] == 'Debian'
  - ansible_facts['distribution'] == 'Ubuntu'
  - ansible_facts['distribution_major_version'] == '26'
```
- The file is written to `/etc/sysctl.d/99-forwarding.conf` -- the `99-` prefix ensures it's applied last, overriding earlier drop-ins.
- The task is idempotent - `copy` only rewrites thefile when content changes.
- On any non-Ubuntu-26 host the task is skipped

> Note: This writes the persistent config file only. It does not apply the
> setting to the running kernel (that requires sysctl -p or a reboot). This
> matches the original echo | tee approach it replaces.

##  Prerequisites

- Docker (running on macOS and set `DOCKER_HOST` to the socket - see below)
- Python 3.9+
- A virtualenv with `molecule`, `molecule-plugins[docker]`, `pytest`, `pytest-testinfra`

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install "molecule" "molecule-plugins[docker]" "pytest" "pytest-testinfra"
```

## Running the molecule test

```bash
# macOS only - point molecule at the Docker Desktop socket
export DOCKER_HOST=unix:///Users/$USER/.docker/run/docker.sock

molecule test
```

`molecule test` runs the full lifecycle:
```
create → prepare → converge → idempotence → side_effect → verify → destroy
```
It spins up two throwaway containers (Ubuntu 26.04 and 24.04), applies the task
to both, asserts the correct end state on each, then tears everything down.

| STEP          | UBUNTU 26.04                             | UBUNTU 24.04   |
|---------------|------------------------------------------|----------------|
| `converge`    | task `changed` (file written)            | task `skipped` |
| `idempotence` | re-run reports `changed: 0`              | --             |
| `verify`      | fil exists, mode `0644`, content correct | file absent    |

## Manual verification (optional)

```bash
molecule converge     # create + apply, leave containers running
molecule login        # shell into a container
# inside the container:
cat /etc/sysctl.d/99-forwarding.conf
```

## Scope & limitations

This is a proof of concept. Molecule verifies that the config file is
written correctly and idempotently. The following are not yet validated and
should be confirmed on a real host before production use:

- Live kernel application — Docker makes `/proc/sys/net/ipv4/ip_forward` read-only without `--privileged` / `--sysctl`, so the running-kernel value is not exercised here. Validate `sysctl -p` behavior on a real Ubuntu 26 VM.
- `become` path — Molecule's containers run as root, so the `become: true` in the production playbook isn't exercised. Confirm `become`/`sudo` works on real hosts.
- Real inventory — tests use Molecule's own inventory, not the production `hosts.yml`.

## Roadmap
[] Convert the playbook into a reusable Ansible role
[] Validate live kernal application on a real Ubuntu 26.04 host