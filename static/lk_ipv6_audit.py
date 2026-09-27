#!/usr/bin/env python3
"""IPv6 audit for Sri Lankan government / university websites.

Per unique host from websites_merged.json:
  1. DNS: A + AAAA records (dig, follows CNAMEs)
  2. No AAAA  -> verdict "no_aaaa" (stop)
  3. AAAA     -> TCP connect over IPv6 to port 443
  4.          -> TLS handshake on that same IPv6 socket, full cert verification
  5.          -> HTTP HEAD (GET fallback) over IPv6, capture status code

Verdicts:
  domain_dead   no A and no AAAA
  dns_fail      DNS lookup error/timeout
  no_aaaa       A exists, no AAAA record
  aaaa_only_no_a  AAAA exists, no A (recorded)
  aaaa_tcp_fail   AAAA present, TCP:443 unreachable over IPv6
  aaaa_ssl_fail   TCP ok, TLS/certificate verification failed
  aaaa_http_fail  TCP+TLS ok, no valid HTTP response
  aaaa_ok       everything works over IPv6

Usage:
  python3 ipv6_audit.py [--input websites_merged.json] [--out ipv6_results.json]
                        [--workers 20] [--only host1,host2]
"""

import argparse
import concurrent.futures as cf
import datetime
import json
import re
import socket
import ssl
import subprocess
import sys
import time
import urllib.parse

DNS_TIMEOUT = 5
TCP_TIMEOUT = 6
TLS_TIMEOUT = 8
HTTP_TIMEOUT = 8
USER_AGENT = "lk-ipv6-audit/1.0 (research; contact: blog)"

IPV4_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")
IPV6_RE = re.compile(r"^[0-9a-fA-F:]+$")


def dig(record_type, host):
    """Return (ips, error, cnames, other)."""
    try:
        p = subprocess.run(
            ["dig", f"+time={DNS_TIMEOUT}", "+tries=1", "+short", record_type, host],
            capture_output=True,
            text=True,
            timeout=DNS_TIMEOUT + 3,
        )
    except subprocess.TimeoutExpired:
        return [], "timeout", [], []
    if p.returncode == 9:  # NXDOMAIN -> no records, not an error
        return [], None, [], []
    if p.returncode != 0:
        return [], (p.stderr.strip() or f"dig exit {p.returncode}"), [], []
    ips, cnames, other = [], [], []
    for line in p.stdout.splitlines():
        line = line.strip()
        if not line or line == ".":
            continue
        if record_type == "A" and IPV4_RE.match(line):
            ips.append(line)
        elif record_type == "AAAA" and IPV6_RE.match(line) and ":" in line:
            ips.append(line)
        elif line.endswith("."):
            cnames.append(line.rstrip("."))
        else:
            other.append(line)
    return ips, None, cnames, other


def dns_lookup(host):
    a, a_err, a_cname, a_other = dig("A", host)
    aaaa, aaaa_err, aaaa_cname, aaaa_other = dig("AAAA", host)
    return {
        "a": a,
        "aaaa": aaaa,
        "cname": sorted(set(a_cname + aaaa_cname)),
        "error": None if not (a_err and aaaa_err) else (a_err or aaaa_err),
    }


def tcp_connect_v6(ip, port=443):
    """Connect to IPv6 address, return (sock, latency_ms) or (None, err)."""
    s = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    s.settimeout(TCP_TIMEOUT)
    t0 = time.monotonic()
    try:
        s.connect((ip, port, 0, 0))
        return s, int((time.monotonic() - t0) * 1000)
    except OSError as e:
        s.close()
        return None, str(e)


def tls_handshake(sock, hostname):
    """Wrap connected socket with TLS + certificate verification."""
    ctx = ssl.create_default_context()
    try:
        t0 = time.monotonic()
        ts = ctx.wrap_socket(sock, server_hostname=hostname)
        ms = int((time.monotonic() - t0) * 1000)
        cert = ts.getpeercert()
        cipher = ts.cipher()
        not_after = cert.get("notAfter")
        issuer = dict(x[0] for x in cert.get("issuer", ())).get("organizationName") or dict(
            x[0] for x in cert.get("issuer", ())
        ).get("commonName")
        san = [v for k, v in cert.get("subjectAltName", ()) if k == "DNS"]
        return ts, {
            "ok": True,
            "ms": ms,
            "version": ts.version(),
            "cipher": cipher[0] if cipher else None,
            "tls_version_protocol": cipher[1] if cipher else None,
            "not_after": not_after,
            "issuer": issuer,
            "san": san[:10],
            "error": None,
        }
    except ssl.SSLCertVerificationError as e:
        return None, {"ok": False, "error": f"cert_verify: {e.verify_message or e}"}
    except ssl.SSLError as e:
        return None, {"ok": False, "error": f"ssl: {e}"}
    except OSError as e:
        return None, {"ok": False, "error": f"tls_sock: {e}"}


def http_request(ts, hostname, method="HEAD", path="/"):
    req = (
        f"{method} {path} HTTP/1.1\r\n"
        f"Host: {hostname}\r\n"
        f"User-Agent: {USER_AGENT}\r\n"
        f"Accept: */*\r\n"
        f"Connection: close\r\n"
        f"\r\n"
    ).encode()
    t0 = time.monotonic()
    try:
        ts.settimeout(HTTP_TIMEOUT)
        ts.sendall(req)
        buf = b""
        while b"\r\n\r\n" not in buf and len(buf) < 65536:
            chunk = ts.recv(4096)
            if not chunk:
                break
            buf += chunk
        ms = int((time.monotonic() - t0) * 1000)
        head = buf.split(b"\r\n\r\n", 1)[0].decode("latin-1", "replace")
        lines = head.split("\r\n")
        if not lines or not lines[0].startswith("HTTP/"):
            return {"ok": False, "ms": ms, "error": "no http response", "raw": lines[0][:120] if lines else ""}
        m = re.match(r"HTTP/([\d.]+)\s+(\d{3})\s*(.*)", lines[0])
        headers = {}
        for line in lines[1:]:
            if ":" in line:
                k, v = line.split(":", 1)
                headers[k.strip().lower()] = v.strip()
        return {
            "ok": True,
            "ms": ms,
            "http_version": m.group(1) if m else None,
            "status": int(m.group(2)) if m else None,
            "reason": m.group(3).strip() if m else None,
            "server": headers.get("server"),
            "location": headers.get("location"),
            "error": None,
        }
    except Exception as e:
        return {"ok": False, "error": str(e)}


def tcp_connect_v4(ip, port=443, timeout=TCP_TIMEOUT):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect((ip, port))
        return True, None
    except OSError as e:
        return False, str(e)
    finally:
        s.close()


def probe_v4(rec):
    """If the v6 path failed, check whether IPv4 reaches the same service."""
    a = (rec.get("dns") or {}).get("a") or []
    if not a:
        rec["v4_tcp"] = {"ok": False, "error": "no A record"}
        return
    last = None
    for ip in a[:2]:
        ok, err = tcp_connect_v4(ip, rec.get("port", 443))
        if ok:
            rec["v4_tcp"] = {"ok": True, "ip": ip}
            return
        last = err
    rec["v4_tcp"] = {"ok": False, "error": last}


def audit_host(host, port=443):
    rec = {
        "host": host,
        "port": port,
        "dns": None,
        "tcp": None,
        "ssl": None,
        "http": None,
        "verdict": None,
        "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    }
    dns = dns_lookup(host)
    rec["dns"] = dns
    aaaa, a = dns["aaaa"], dns["a"]

    if not a and not aaaa:
        rec["verdict"] = "domain_dead" if not dns["error"] else "dns_fail"
        if not dns["error"] and host.startswith("www."):
            apex = host[4:]
            adig = dns_lookup(apex)
            if adig["a"] or adig["aaaa"]:
                rec["apex_check"] = {
                    "apex": apex,
                    "a": adig["a"],
                    "aaaa": adig["aaaa"],
                    "note": "www record missing but apex resolves",
                }
        return rec
    if not aaaa:
        rec["verdict"] = "no_aaaa"
        return rec

    # AAAA present -> walk the v6 path
    tcp_sock = None
    last_err = None
    for ip in aaaa:
        sock, r = tcp_connect_v6(ip, port)
        if sock is not None:
            tcp_sock, tcp_ip = sock, ip
            rec["tcp"] = {"ok": True, "ip": tcp_ip, "ms": r}
            break
        last_err = r
    if tcp_sock is None:
        rec["tcp"] = {"ok": False, "error": last_err}
        rec["verdict"] = "aaaa_tcp_fail"
        probe_v4(rec)
        return rec

    ts, ssl_info = tls_handshake(tcp_sock, host)
    rec["ssl"] = ssl_info
    if ts is None:
        rec["verdict"] = "aaaa_ssl_fail"
        probe_v4(rec)
        return rec

    resp = http_request(ts, host, "HEAD")
    if not resp.get("ok") or resp.get("status") in (405, 501):
        try:
            ts.close()
        except OSError:
            pass
        # retry once with GET over a fresh connection
        sock2, r2 = tcp_connect_v6(rec["tcp"]["ip"], port)
        if sock2 is not None:
            ts2, _ = tls_handshake(sock2, host)
            if ts2 is not None:
                resp = http_request(ts2, host, "GET")
                resp["method"] = "GET"
                try:
                    ts2.close()
                except OSError:
                    pass
    else:
        resp["method"] = "HEAD"
        try:
            ts.close()
        except OSError:
            pass
    rec["http"] = resp
    rec["verdict"] = "aaaa_ok" if resp.get("ok") else "aaaa_http_fail"
    if rec["verdict"] != "aaaa_ok":
        probe_v4(rec)
    return rec


def parse_host(url):
    p = urllib.parse.urlparse(url if "://" in url else "http://" + url)
    netloc = p.netloc
    host = netloc.lower().rstrip(".")
    port = 443
    if ":" in host and not host.startswith("["):
        host, _, pt = host.partition(":")
        try:
            port = int(pt)
        except ValueError:
            port = 443
    return host, port


def load_hosts(path):
    """host -> list of {category, subgroup, name, url}"""
    data = json.load(open(path))
    hosts = {}
    for cat, subs in data.items():
        for sub, sites in subs.items():
            for name, url in sites.items():
                urls = url if isinstance(url, list) else [url]
                for u in urls:
                    host, port = parse_host(u)
                    key = host if port == 443 else f"{host}:{port}"
                    hosts.setdefault(key, {"host": host, "port": port, "entries": []})
                    hosts[key]["entries"].append(
                        {"category": cat, "subgroup": sub, "name": name, "url": u}
                    )
    return hosts


def run(args):
    hosts = load_hosts(args.input)
    if args.only:
        wanted = set(x.strip() for x in args.only.split(","))
        hosts = {k: v for k, v in hosts.items() if v["host"] in wanted or k in wanted}
    print(f"auditing {len(hosts)} unique hosts ...", file=sys.stderr)

    results = {}
    done = 0
    t0 = time.monotonic()
    with cf.ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {
            ex.submit(audit_host, info["host"], info["port"]): key
            for key, info in hosts.items()
        }
        for fut in cf.as_completed(futs):
            key = futs[fut]
            try:
                rec = fut.result()
            except Exception as e:
                rec = {"host": hosts[key]["host"], "verdict": "error", "error": str(e)}
            rec["entries"] = hosts[key]["entries"]
            results[key] = rec
            done += 1
            if done % 25 == 0 or done == len(hosts):
                print(
                    f"  {done}/{len(hosts)} ({time.monotonic() - t0:.0f}s)",
                    file=sys.stderr,
                )

    out = {
        "meta": {
            "input": args.input,
            "generated": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
            "total_hosts": len(results),
        },
        "results": results,
    }
    with open(args.out, "w") as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
    print(f"wrote {args.out}", file=sys.stderr)
    summarize(results, args.summary)
    return results


def summarize(results, summary_path):
    from collections import Counter

    verdicts = Counter(r.get("verdict") for r in results.values())
    total = len(results)
    has_aaaa = [r for r in results.values() if r.get("dns", {}) and r["dns"].get("aaaa")]
    ok = [r for r in results.values() if r.get("verdict") == "aaaa_ok"]

    def group_of(r):
        names = {e["category"] for e in r.get("entries", [])}
        if "Universities and Higher Education Institutions" in names:
            return "university"
        hosts = r["host"]
        if hosts.endswith(".gov.lk") or ".gov.lk" in hosts:
            return "gov.lk"
        if hosts.endswith(".ac.lk") or ".ac.lk" in hosts:
            return "ac.lk"
        if hosts.endswith(".lk") or hosts.endswith(".sch.lk"):
            return "other.lk"
        return "non-lk"

    groups = {}
    for g in ("gov.lk", "ac.lk", "university", "other.lk", "non-lk"):
        members = [r for r in results.values() if group_of(r) == g]
        if not members:
            continue
        g_aaaa = [r for r in members if r.get("dns") and r["dns"].get("aaaa")]
        g_ok = [r for r in members if r.get("verdict") == "aaaa_ok"]
        groups[g] = {
            "total": len(members),
            "with_aaaa": len(g_aaaa),
            "aaaa_ok": len(g_ok),
        }

    lines = []
    lines.append(f"# IPv6 audit summary — {total} hosts")
    lines.append("")
    lines.append(f"Generated: {datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')}")
    lines.append("")
    lines.append("## Verdicts")
    lines.append("")
    lines.append("| Verdict | Count | % |")
    lines.append("|---|---:|---:|")
    for v, c in sorted(verdicts.items(), key=lambda x: -x[1]):
        lines.append(f"| {v} | {c} | {100 * c / total:.1f}% |")
    lines.append("")
    n_aaaa = len(has_aaaa)
    lines.append(
        f"**With AAAA:** {n_aaaa}/{total} ({100 * n_aaaa / total:.1f}%)  |  "
        f"**AAAA fully working:** {len(ok)}/{n_aaaa if n_aaaa else 0}"
        + (f" ({100 * len(ok) / n_aaaa:.1f}%) of those" if n_aaaa else "")
    )
    lines.append("")
    if groups:
        lines.append("## By group")
        lines.append("")
        lines.append("| Group | Hosts | With AAAA | AAAA works | % AAAA | % works (of AAAA) |")
        lines.append("|---|---:|---:|---:|---:|---:|")
        for g, s in groups.items():
            pct = 100 * s["with_aaaa"] / s["total"] if s["total"] else 0
            pct2 = 100 * s["aaaa_ok"] / s["with_aaaa"] if s["with_aaaa"] else 0
            lines.append(
                f"| {g} | {s['total']} | {s['with_aaaa']} | {s['aaaa_ok']} | {pct:.1f}% | {pct2:.1f}% |"
            )
        lines.append("")

    dead = [r for r in results.values() if r.get("verdict") == "domain_dead"]
    if dead:
        www_ok = [r for r in dead if r.get("apex_check")]
        lines.append("## Dead domains (NXDOMAIN)")
        lines.append("")
        lines.append(f"Total: {len(dead)}" + (f" — of which {len(www_ok)} have a live apex (only `www.` missing)" if www_ok else ""))
        lines.append("")
        for r in sorted(dead, key=lambda x: x["host"]):
            note = ""
            if r.get("apex_check"):
                ac = r["apex_check"]
                note = f" — apex `{ac['apex']}` resolves (A: {', '.join(ac['a']) or 'none'}, AAAA: {', '.join(ac['aaaa']) or 'none'})"
            lines.append(f"- `{r['host']}`{note}")
        lines.append("")

    fails = [
        r
        for r in results.values()
        if r.get("verdict", "").startswith("aaaa_") and r["verdict"] != "aaaa_ok"
    ]
    if fails:
        v6_only = [r for r in fails if (r.get("v4_tcp") or {}).get("ok")]
        site_down = [r for r in fails if not (r.get("v4_tcp") or {}).get("ok")]
        lines.append("## AAAA present but broken")
        lines.append("")
        lines.append(
            f"- **IPv6-only breakage** (IPv4 works): **{len(v6_only)}** — "
            "these are the real IPv6 failures"
        )
        lines.append(
            f"- **Site down entirely** (IPv4 also unreachable): {len(site_down)}"
        )
        lines.append("")
        lines.append("| Host | Verdict | IPv4 | Detail |")
        lines.append("|---|---|---|---|")
        for r in sorted(fails, key=lambda x: (not bool((x.get("v4_tcp") or {}).get("ok")), x["host"])):
            detail = (
                (r.get("tcp") or {}).get("error")
                or (r.get("ssl") or {}).get("error")
                or (r.get("http") or {}).get("error")
                or ""
            )
            v4 = "up" if (r.get("v4_tcp") or {}).get("ok") else "down"
            lines.append(f"| {r['host']} | {r['verdict']} | {v4} | {detail} |")
        lines.append("")

    txt = "\n".join(lines) + "\n"
    if summary_path:
        with open(summary_path, "w") as f:
            f.write(txt)
        print(f"wrote {summary_path}", file=sys.stderr)
    print(txt)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default="websites_merged.json")
    ap.add_argument("--out", default="ipv6_results.json")
    ap.add_argument("--summary", default="summary.md")
    ap.add_argument("--workers", type=int, default=20)
    ap.add_argument("--only", default=None, help="comma separated hostnames for a quick test")
    args = ap.parse_args()
    run(args)


if __name__ == "__main__":
    main()
