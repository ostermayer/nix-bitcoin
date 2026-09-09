#!/usr/bin/env python3
"""PEM private-key check for audit output files (fail closed).

Usage: pem-check.py <allowlist> <file>...
Every "-----BEGIN ... PRIVATE KEY-----" block in each file is compared against
the blocks in <allowlist> (deliberately public keys, e.g. the fork's
examples/qemu-vm/id-vm demo identity). Allowlisted blocks are replaced in
place by a placeholder; any other private-key block is reported and the exit
status is 1 so the caller refuses to publish.
"""
import re, sys
PEM = re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?-----END [A-Z0-9 ]*PRIVATE KEY-----", re.S)
norm = lambda b: re.sub(r"\s+", "", b)
allow = {norm(b) for b in PEM.findall(open(sys.argv[1]).read())} if len(sys.argv) > 2 else set()
rc = 0
for path in sys.argv[2:]:
    try: s = open(path, errors="replace").read()
    except FileNotFoundError: continue
    def sub(m):
        global rc
        if norm(m.group(0)) in allow:
            return "[PRIVATE KEY BLOCK omitted — matches an allowlisted PUBLIC demo key]"
        rc = 1; print(f"PRIVATE-KEY BLOCK in {path} (not allowlisted)"); return m.group(0)
    t = PEM.sub(sub, s)
    if t != s: open(path, "w").write(t)
sys.exit(rc)
