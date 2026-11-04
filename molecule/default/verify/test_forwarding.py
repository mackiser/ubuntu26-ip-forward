import re


def _ubuntu_major(host):
    osr = host.file("/etc/os-release")
    if not osr.exists:
        return None
    for line in osr.content.splitlines():
        m = re.match(r'^VERSION_ID="?(\d+)"?$', line.strip())
        if m:
            return m.group(1)
    return None


def test_ip_forward_conf(host):
    major = _ubuntu_major(host)
    f = host.file("/etc/sysctl.d/99-forwarding.conf")
    if major == "26":
        assert f.exists, "99-forwarding.conf should exist on Ubuntu 26"
        assert f.user == "root"
        assert f.group == "root"
        assert f.mode == "0644"
        assert f.contains("net.ipv4.ip_forward = 1")
    else:
        assert not f.exists, "99-forwarding.conf must NOT exist on non-Ubuntu-26"


def test_runtime_forwarding(host):
    major = _ubuntu_major(host)
    if major == "26":
        s = host.sysctl("net.ipv4.ip_forward")
        assert s == 1, "kernel should have ip_forward enabled on Ubuntu 26"