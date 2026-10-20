#!/usr/bin/env python3
"""Builds the Safari content-blocker rule files from open-licensed adult-domain lists.

Run on your Mac before each release (needs internet):

    python3 tools/blocklist/build_blocklist.py

Writes:
    Extensions/BlockerA/blockerA.base.json   top ~140k domains (one block rule each)
    Extensions/BlockerB/blockerB.base.json   next ~130k domains + adult TLD rules
    Resources/blocklist-meta.json            counts + source info, shown in the app
    LICENSES/blocklists.md                   attribution for the lists

Standard library only. Never edit the JSON by hand: change this script and re-run it.
"""
import json, os, re, sys, urllib.request, datetime

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE_URL = "https://raw.githubusercontent.com/blocklistproject/Lists/master/alt-version/porn-nl.txt"
RANK_URL = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"
LIMIT_A = 140_000          # Safari allows 150,000 rules per extension; keep headroom
LIMIT_B = 130_000          # B also carries the user's custom rules at runtime
ADULT_TLDS = ["xxx", "porn", "sex", "adult"]

# Domains that must never be blocked, whatever an upstream list says.
NEVER_BLOCK = {
    "apple.com", "icloud.com", "google.com", "googleapis.com", "gstatic.com", "bing.com",
    "duckduckgo.com", "wikipedia.org", "wikimedia.org", "github.com", "githubusercontent.com",
    "microsoft.com", "live.com", "office.com", "amazon.com", "cloudflare.com", "akamaihd.net",
    "youtube.com", "ytimg.com", "reddit.com", "redd.it", "x.com", "twitter.com", "instagram.com",
    "facebook.com", "whatsapp.com", "tiktok.com", "tumblr.com", "imgur.com", "blogspot.com",
    "wordpress.com", "medium.com", "yahoo.com", "mozilla.org",
}

LABEL = re.compile(r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")


def fetch(url, cache):
    path = os.path.join(ROOT, "tools", "blocklist", ".cache", cache)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if not os.path.exists(path) or "--refresh" in sys.argv:
        print("downloading", url)
        with urllib.request.urlopen(url, timeout=120) as r, open(path, "wb") as fh:
            fh.write(r.read())
    with open(path, encoding="utf-8", errors="ignore") as fh:
        return fh.read()


def valid(domain):
    if len(domain) > 253 or "." not in domain:
        return False
    labels = domain.split(".")
    return all(LABEL.match(l) for l in labels) and not labels[-1].isdigit()


def parse_domains(text):
    out = set()
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip().lower()
        if not line:
            continue
        parts = line.split()
        d = parts[-1] if parts[0] in ("0.0.0.0", "127.0.0.1") else parts[0]
        if d.startswith("www."):
            d = d[4:]
        if valid(d) and d not in ("localhost", "0.0.0.0"):
            out.add(d)
    return out


def header_value(text, key):
    m = re.search(r"^#\s*" + key + r":\s*(.+)$", text, re.M | re.I)
    return m.group(1).strip() if m else "unknown"


def ancestors(d):
    parts = d.split(".")
    return [".".join(parts[i:]) for i in range(1, len(parts) - 1)]


def collapse(domains):
    """Drop a.example.com when example.com is itself on the list (example.com's rule covers it)."""
    return {d for d in domains if not any(a in domains for a in ancestors(d))}


def blocked_by_never(d):
    # Exact match only: a rule for "someblog.tumblr.com" blocks just that blog, which is fine,
    # but "tumblr.com" itself must never be blocked.
    return d in NEVER_BLOCK


def rule(domain):
    pattern = "^[^:]+://+([^:/]+\\.)?" + domain.replace(".", "\\.") + "[/:]"
    return {"trigger": {"url-filter": pattern}, "action": {"type": "block"}}


def tld_rule(tld):
    return {"trigger": {"url-filter": "^[^:]+://+[^:/]+\\." + tld + "[/:]"}, "action": {"type": "block"}}


def write_json(path, rules):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(rules, fh, separators=(",", ":"))
    return os.path.getsize(path)


def main():
    src_text = fetch(SOURCE_URL, "blp-porn.txt")
    rank_text = fetch(RANK_URL, "stevenblack-porn.txt")
    src = parse_domains(src_text)
    rank = parse_domains(rank_text)
    print(f"source domains: {len(src):,}  rank list: {len(rank):,}")

    # Remove never-block domains first, so collapsing can't hide their listed subdomains.
    kept = collapse({d for d in src if not blocked_by_never(d)})
    # Drop domains covered by the TLD rules.
    kept = {d for d in kept if d.rsplit(".", 1)[-1] not in ADULT_TLDS}
    print(f"after collapse + never-block + TLD: {len(kept):,}")

    # Rank: domains confirmed by a second independent list first, then shorter / fewer labels.
    ordered = sorted(kept, key=lambda d: (d not in rank, d.count("."), len(d), d))
    a, b = ordered[:LIMIT_A], ordered[LIMIT_A:LIMIT_A + LIMIT_B]
    dropped = max(0, len(ordered) - LIMIT_A - LIMIT_B)

    size_a = write_json(os.path.join(ROOT, "Extensions", "BlockerA", "blockerA.base.json"), [rule(d) for d in a])
    rules_b = [tld_rule(t) for t in ADULT_TLDS] + [rule(d) for d in b]
    size_b = write_json(os.path.join(ROOT, "Extensions", "BlockerB", "blockerB.base.json"), rules_b)

    meta = {
        "listVersion": datetime.date.today().strftime("%Y.%m.%d"),
        "source": "The Block List Project – porn list",
        "sourceURL": "https://github.com/blocklistproject/Lists",
        "sourceLastModified": header_value(src_text, "Last modified"),
        "sourceDomains": len(src),
        "domainCount": len(a) + len(b),
        "tldRules": ADULT_TLDS,
        "ruleCountA": len(a),
        "ruleCountB": len(rules_b),
        "notIncluded": dropped,
    }
    write_json(os.path.join(ROOT, "Resources", "blocklist-meta.json"), meta)

    os.makedirs(os.path.join(ROOT, "LICENSES"), exist_ok=True)
    with open(os.path.join(ROOT, "LICENSES", "blocklists.md"), "w", encoding="utf-8") as fh:
        fh.write(
            "# Block list sources\n\n"
            "## The Block List Project – porn list\n"
            "https://github.com/blocklistproject/Lists\n"
            f"Last modified upstream: {meta['sourceLastModified']}\n\n"
            "Released into the public domain under The Unlicense (repository LICENSE); "
            "the list file header states MIT. Either way, commercial use and redistribution are allowed. "
            "Thank you to the maintainers.\n\n"
            "## StevenBlack/hosts – porn-only alternate (ranking only)\n"
            "https://github.com/StevenBlack/hosts (MIT)\n"
            "Used only to decide which domains go first. No domain is shipped that is not in the Block List Project list.\n"
        )
    print(f"A: {len(a):,} rules ({size_a/1e6:.1f} MB)  B: {len(rules_b):,} rules ({size_b/1e6:.1f} MB)  not included: {dropped:,}")


if __name__ == "__main__":
    main()
