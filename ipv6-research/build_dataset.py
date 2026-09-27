#!/usr/bin/env python3
"""Build websites_merged.json = fork gov dataset + Sri Lanka universities.

Sources:
  1. https://raw.githubusercontent.com/miyurusankalpa/gov_lk_web_auditor/patch-1/static_data/websites.json
  2. https://en.wikipedia.org/wiki/List_of_universities_in_Sri_Lanka (3 tables)
     -> official website via Wikidata P856, fallback: Wikipedia external links,
        fallback: common domain guesses verified with a DNS A lookup.
"""

import json
import re
import socket
import sys
import urllib.parse
import urllib.request

UA = {"User-Agent": "lk-ipv6-blog-research/1.0 (blog post data collection)"}

FORK_URL = (
    "https://raw.githubusercontent.com/miyurusankalpa/gov_lk_web_auditor/"
    "patch-1/static_data/websites.json"
)
WIKI_RAW = "https://en.wikipedia.org/wiki/List_of_universities_in_Sri_Lanka?action=raw"

# Wikipedia article title -> guessed official domain candidates (verified via DNS A)
DOMAIN_GUESSES = {
    "Aquinas College of Higher Studies": ["www.aquinas.lk", "aquinas.ac.lk"],
    "Institute of Chartered Accountants of Sri Lanka": ["www.ca.lk", "casl.lk"],
    "Institute of Surveying and Mapping": ["ism.ac.lk"],
    "Institute of Technological Studies": ["www.itsuniversity.lk", "its.ac.lk"],
    "KAATSU": ["kiu.ac.lk", "www.kiu.ac.lk"],
    "National Institute of Social Development": ["www.nisd.ac.lk", "nisda.lk"],
    "Royal Institute Colombo": ["www.ri.lk", "royal.lk"],
    "SANASA Campus": ["sanasacampus.lk", "www.sanasacampus.lk"],
    "Saegis Campus": ["www.saegis.ac.lk", "saegis.lk"],
    "South Asian Institute of Technology and Medicine": ["www.saitm.edu.lk", "saitm.edu.lk"],
    "Sri Lanka Institute of Development Administration": ["www.slida.lk"],
    "Sri Lanka International Buddhist Academy": ["siba.edu.lk", "www.siba.edu.lk"],
    "Business Management School": ["www.bms.lk", "bms.ac.lk"],
    "Esoft Metro Campus": ["www.esoftmetrocampus.lk", "esoft.lk"],
}


def http_get(url, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")


def http_json(url, timeout=30):
    return json.loads(http_get(url, timeout))


def dns_a(host):
    """Return list of A records (empty if none)."""
    try:
        return sorted({ai[4][0] for ai in socket.getaddrinfo(host, None, socket.AF_INET)})
    except socket.gaierror:
        return []


def wiki_sections(text):
    lines = text.split("\n")
    headers = [
        (n, l.strip("=").strip())
        for n, l in enumerate(lines)
        if l.startswith("==") and l.endswith("==") and not l.startswith("===")
    ]
    def sec(title):
        idx = next(n for n, t in headers if t == title)
        nxt = min([n for n, t in headers if n > idx], default=len(lines))
        return lines[idx + 1 : nxt]

    unis = []
    for l in sec("Universities"):
        m = re.match(r"^\|\s*\{\{Sort\|[^|]*\|\[\[([^\]|]+)(?:\|([^\]]+))?\]\]\}", l)
        if m:
            unis.append(m.group(1))
    other = []
    for l in sec("Other government universities"):
        m = re.match(r"^\|\s*\{\{Sort\|[^|]*\|\[\[([^\]|]+)(?:\|([^\]]+))?\]\]\}", l)
        if m:
            unis_ = m.group(1)
            other.append(unis_)
        else:
            m2 = re.match(r"^\|\s*\{\{Sort\|([^|}]*)\}\}", l)
            if m2:
                other.append(m2.group(1).strip())
    inst = []
    for l in sec("Degree awarding institutes"):
        m = re.match(r"^\|\s*\[\[([^\]|]+)(?:\|([^\]]+))?\]\]", l)
        if m:
            inst.append(m.group(1))
        else:
            m2 = re.match(r"^\|\s*([A-Za-z][^|]+?)\s*\|\|", l)
            if m2 and "{{" not in m2.group(1):
                inst.append(m2.group(1).replace("<br />", " ").strip())
    return unis, other, inst


def resolve_qids(titles):
    """Wikipedia titles -> {title: qid} (handles redirects/normalization)."""
    fixed = {}
    for i in range(0, len(titles), 40):
        batch = titles[i : i + 40]
        url = (
            "https://en.wikipedia.org/w/api.php?action=query&format=json"
            "&prop=pageprops&ppprop=wikibase_item&redirects=1&titles="
            + urllib.parse.quote("|".join(batch))
        )
        data = http_json(url)["query"]
        norm = {n["from"]: n["to"] for n in data.get("normalized", [])}
        redirects = {r["from"]: r["to"] for r in data.get("redirects", [])}
        by_title = {}
        for page in data["pages"].values():
            by_title[page["title"]] = page.get("pageprops", {}).get("wikibase_item")
        for t in batch:
            t2 = norm.get(t, t)
            t2 = redirects.get(t2, t2)
            fixed[t] = by_title.get(t2)
    return fixed


def wikidata_websites(qids):
    """qid -> [urls]"""
    out = {}
    qids = [q for q in qids if q]
    for i in range(0, len(qids), 40):
        url = (
            "https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&ids="
            + "|".join(qids[i : i + 40])
            + "&props=claims"
        )
        for qid, ent in http_json(url).get("entities", {}).items():
            urls = []
            for claim in ent.get("claims", {}).get("P856", []):
                try:
                    urls.append(claim["mainsnak"]["datavalue"]["value"])
                except (KeyError, IndexError):
                    pass
            out[qid] = urls
    return out


def wiki_external_links(title):
    """External http(s) links from a Wikipedia article body (non-wikimedia)."""
    url = "https://en.wikipedia.org/wiki/" + urllib.parse.quote(title.replace(" ", "_")) + "?action=raw"
    try:
        text = http_get(url)
    except Exception:
        return []
    links = []
    for m in re.finditer(r"https?://[^\s|\}\]<>\"]+", text):
        link = m.group(0).rstrip(".,);")
        host = urllib.parse.urlparse(link).netloc.lower()
        if not host:
            continue
        if any(
            bad in host
            for bad in (
                "wikipedia.org",
                "wikimedia.org",
                "wikidata.org",
                "archive.org",
                "creativecommons.org",
            )
        ):
            continue
        links.append(link)
    return links


def normalize_url(url):
    url = url.strip()
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    return url


def host_of(url):
    return (urllib.parse.urlparse(url).netloc or "").lower()


def pick_website(title, wikidata_urls, wiki_links):
    """Return (url, source) or (None, None)."""
    for u in wikidata_urls:
        if u.startswith(("http://", "https://")):
            return normalize_url(u), "wikidata:P856"
    for guess in DOMAIN_GUESSES.get(title, []):
        if dns_a(guess):
            return "https://" + guess + "/", "dns-guess"
    for u in wiki_links:
        host = host_of(u)
        if host.endswith(".ac.lk") or host.endswith(".edu.lk") or host.endswith(".lk"):
            return normalize_url(u), "wikipedia:extlinks"
    for u in wiki_links:
        return normalize_url(u), "wikipedia:extlinks:any"
    return None, None


def main():
    print("1) fetching fork dataset ...", file=sys.stderr)
    fork = http_json(FORK_URL)
    fork_hosts = set()
    for cat, subs in fork.items():
        for sub, sites in subs.items():
            for name, url in sites.items():
                for u in url if isinstance(url, list) else [url]:
                    fork_hosts.add(host_of(u))
    print(f"   fork: {len(fork_hosts)} unique hosts", file=sys.stderr)

    print("2) parsing Wikipedia list ...", file=sys.stderr)
    raw = http_get(WIKI_RAW)
    unis, other, inst = wiki_sections(raw)
    print(f"   state={len(unis)} other_gov={len(other)} institutes={len(inst)}", file=sys.stderr)

    all_titles = unis + other + inst
    print("3) resolving Wikidata ...", file=sys.stderr)
    qids = resolve_qids(all_titles)
    webs = wikidata_websites(list(qids.values()))

    print("4) resolving missing websites ...", file=sys.stderr)
    rows = []  # (title, url, source)
    for title in all_titles:
        qid = qids.get(title)
        wd_urls = webs.get(qid, []) if qid else []
        links = []
        url, source = pick_website(title, wd_urls, links)
        if not url:
            links = wiki_external_links(title)
            url, source = pick_website(title, wd_urls, links)
        rows.append((title, url, source))
        status = url or "NOT-RESOLVED"
        print(f"   {title:60s} {source or '-':22s} {status}", file=sys.stderr)

    # group into the new category
    def group(titles, rows_map):
        return {
            t: rows_map[t][0]
            for t in titles
            if rows_map.get(t, (None, None, None))[0]
        }

    rows_map = {t: (u, s) for t, u, s in rows}
    new_cat = {
        "State Universities (UGC)": group(unis, rows_map),
        "Other Government Universities": group(other, rows_map),
        "Degree Awarding Institutes": group(inst, rows_map),
    }

    # dedupe: drop entries whose host already exists in fork (any category)
    kept = {}
    dupes = []
    for sub, sites in new_cat.items():
        kept[sub] = {}
        for name, url in sites.items():
            if host_of(url) in fork_hosts:
                dupes.append((name, url))
            else:
                kept[sub][name] = url
    print(
        f"5) deduped {len(dupes)} university entries already in fork dataset:",
        file=sys.stderr,
    )
    for name, url in dupes:
        print(f"   - {name}: {url}", file=sys.stderr)

    merged = dict(fork)
    merged["Universities and Higher Education Institutions"] = kept

    unresolved = [(t, u, s) for t, u, s in rows if not u]
    out_path = __file__.rsplit("/", 1)[0] + "/websites_merged.json"
    with open(out_path, "w") as f:
        json.dump(merged, f, indent=2, ensure_ascii=False)

    total_urls = 0
    hosts = set()
    for cat, subs in merged.items():
        for sub, sites in subs.items():
            for name, url in sites.items():
                for u in url if isinstance(url, list) else [url]:
                    total_urls += 1
                    hosts.add(host_of(u))
    print(f"\nwrote {out_path}", file=sys.stderr)
    print(f"total urls={total_urls} unique hosts={len(hosts)}", file=sys.stderr)
    if unresolved:
        print("UNRESOLVED institutions:", file=sys.stderr)
        for t, u, s in unresolved:
            print(f"   ? {t}", file=sys.stderr)
    json.dump(
        {
            "total_urls": total_urls,
            "unique_hosts": len(hosts),
            "unresolved": [t for t, u, s in unresolved],
            "dupes_removed": [d[0] for d in dupes],
        },
        sys.stdout,
        indent=2,
    )


if __name__ == "__main__":
    main()
