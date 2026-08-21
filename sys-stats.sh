#!/usr/bin/env python3
import glob
import json
import os
import time

REAL_FS = {
    "ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs", "zfs",
    "exfat", "ntfs3", "vfat", "fat32", "f2fs",
}


VIRTUAL_IFACE_PREFIXES = (
    "tailscale", "warp", "virbr", "docker", "veth",
    "br-", "zt", "tun", "utun", "wg", "lo",
)


def primary_interface():
    """The interface owning the default route, so VPN traffic isn't
    double-counted alongside the physical link it tunnels through."""
    best = None
    try:
        with open("/proc/net/route") as f:
            for line in f.readlines()[1:]:
                parts = line.split()
                if len(parts) < 8 or parts[1] != "00000000":
                    continue
                metric = int(parts[6])
                if best is None or metric < best[1]:
                    best = (parts[0], metric)
    except Exception:
        pass
    return best[0] if best else ""


def net_interfaces():
    primary = primary_interface()
    if primary:
        return [primary]
    out = []
    try:
        with open("/proc/net/dev") as f:
            for line in f.readlines()[2:]:
                name = line.split(":", 1)[0].strip().lower()
                if not name.startswith(VIRTUAL_IFACE_PREFIXES):
                    out.append(name)
    except Exception:
        pass
    return out


def net_counters(ifaces):
    wanted = set(ifaces)
    rx = tx = 0
    try:
        with open("/proc/net/dev") as f:
            for line in f.readlines()[2:]:
                iface, data = line.split(":", 1)
                if iface.strip().lower() not in wanted:
                    continue
                parts = data.split()
                rx += int(parts[0])
                tx += int(parts[8])
    except Exception:
        pass
    return rx, tx


def uptime():
    try:
        with open("/proc/uptime") as f:
            return round(float(f.read().split()[0]))
    except Exception:
        return 0


def disks():
    seen = set()
    out = []
    try:
        with open("/proc/self/mounts") as f:
            mounts = [line.split()[:3] for line in f]
    except Exception:
        return out
    for src, mnt, fstype in mounts:
        if fstype not in REAL_FS or src in seen or src.startswith("/dev/loop"):
            continue
        if mnt.startswith("/boot") or mnt == "/efi":
            continue
        seen.add(src)
        try:
            st = os.statvfs(mnt)
        except Exception:
            continue
        total = st.f_blocks * st.f_frsize
        free = st.f_bavail * st.f_frsize
        used = total - st.f_bfree * st.f_frsize
        if not total:
            continue
        out.append({
            "mount": mnt,
            "total": round(total / 1024 ** 3, 1),
            "used": round(used / 1024 ** 3, 1),
            "percent": round(100 * used / total),
        })
        if len(out) >= 5:
            break
    out.sort(key=lambda d: d["mount"] != "/")
    return out


def cpu_usage():
    def read():
        with open("/proc/stat") as f:
            parts = f.readline().split()
        vals = [int(x) for x in parts[1:]]
        return sum(vals), vals[3] + vals[4]

    t1, i1 = read()
    time.sleep(0.4)
    t2, i2 = read()
    dt = t2 - t1 or 1
    return round(100 * (dt - (i2 - i1)) / dt)


def meminfo():
    d = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, value = line.split(":", 1)
            d[key] = int(value.split()[0])
    total, avail = d["MemTotal"], d["MemAvailable"]
    used = total - avail
    st, sf = d.get("SwapTotal", 0), d.get("SwapFree", 0)

    def gb(x):
        return x / 1024 / 1024

    return {
        "used": round(gb(used), 1),
        "total": round(gb(total), 0),
        "percent": round(100 * used / total) if total else 0,
        "swapUsed": round(gb(st - sf), 1),
        "swapTotal": round(gb(st), 0),
        "swapPercent": round(100 * (st - sf) / st) if st else 0,
    }


def temp():
    for f in glob.glob("/sys/class/hwmon/hwmon*/temp1_input"):
        base = os.path.dirname(f)
        try:
            chip = open(base + "/name").read().strip()
        except Exception:
            chip = ""
        if chip in ("coretemp", "k10temp", "zenpower", "cpu_thermal"):
            return round(int(open(f).read().strip()) / 1000)
    for f in glob.glob("/sys/class/hwmon/hwmon*/temp1_input"):
        return round(int(open(f).read().strip()) / 1000)
    return 0


t0 = time.monotonic()
ifaces = net_interfaces()
r0, s0 = net_counters(ifaces)
cpu_pct = cpu_usage()
r1, s1 = net_counters(ifaces)

print(json.dumps({
    "cpu": cpu_pct,
    "mem": meminfo(),
    "temp": temp(),
    "disks": disks(),
    "net": {
        "down": round(max(0, r1 - r0) / max(time.monotonic() - t0, 0.001)),
        "up": round(max(0, s1 - s0) / max(time.monotonic() - t0, 0.001)),
    },
    "uptime": uptime(),
}))
