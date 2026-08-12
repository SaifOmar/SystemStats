#!/usr/bin/env python3
import glob
import json
import os
import time


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


print(json.dumps({
    "cpu": cpu_usage(),
    "mem": meminfo(),
    "temp": temp(),
}))
