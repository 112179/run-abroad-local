#!/usr/bin/env python3
"""用 GitHub Contents Data API 把 run-abroad-local 目录整体推到新仓库（一次 commit）。"""
import base64, json, os, sys, urllib.request

TOKEN = os.environ["GITHUB_TOKEN"]
OWNER, REPO = "112179", "run-abroad-local"
ROOT = "/var/minis/workspace/run-abroad-local"

def api(url, method="GET", payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {TOKEN}",
        "Accept": "application/vnd.github+json",
        "Content-Type": "application/json",
        "User-Agent": "minis",
    })
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r) if r.status != 204 else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:500]
        print(f"HTTP {e.code} {url}\n{body}", file=sys.stderr)
        raise
    except urllib.error.URLError as e:
        print(f"URLError {url}: {e.reason}", file=sys.stderr)
        raise

# 1. create repo (fresh empty repo, no base tree)
created = False
try:
    api("https://api.github.com/user/repos", "POST", {
        "name": REPO, "private": False,
        "description": "润学导航（run-abroad）离线 iOS 版：WKWebView 纯本地壳，无网络请求",
        "auto_init": False})
    print("repo created")
    created = True
except urllib.error.HTTPError as e:
    if e.code == 422:
        print("repo already exists")
    else:
        raise

# 2. collect files
files = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in (".git", "dist", "build", "out")]
    for f in filenames:
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, ROOT)
        if os.path.getsize(p) < 1_500_000:
            files.append(rel)
files.sort()

# 3. one tree + one commit
parent = None
# 2.5 empty repo: seed one file via Contents API to create the root commit
if not parent:
    seed = open(os.path.join(ROOT, "README.md"), "rb").read()
    r = api(f"https://api.github.com/repos/{OWNER}/{REPO}/contents/README.md", "PUT", {
        "message": "init", "content": base64.b64encode(seed).decode()})
    parent = r["commit"]["sha"]
    base_commit = api(f"https://api.github.com/repos/{OWNER}/{REPO}/commits/{parent}")
    base_tree = base_commit["commit"]["tree"]["sha"]
    print("seeded root commit", parent)
else:
    try:
        heads = api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/matching-refs/heads/main")
        parent = heads[0]["object"]["sha"] if heads else parent
    except urllib.error.HTTPError:
        pass
base_commit = api(f"https://api.github.com/repos/{OWNER}/{REPO}/commits/{parent}") if parent else None
base_tree = base_commit["commit"]["tree"]["sha"] if base_commit else None

tree = []
blobs = []
for rel in files:
    content = open(os.path.join(ROOT, rel), "rb").read()
    b = api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/blobs", "POST",
            {"content": base64.b64encode(content).decode(), "encoding": "base64"})
    tree.append({"path": rel.replace(os.sep, "/"), "mode": "100644",
                 "type": "blob", "sha": b["sha"]})
    blobs.append(rel)
print(f"{len(tree)} blobs uploaded")

tree_sha = api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/trees", "POST",
               {"tree": tree})["sha"]
commit = api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/commits", "POST", {
    "message": "run-abroad offline iOS app v1.0",
    "tree": tree_sha,
    "parents": [parent] if parent else []})
api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/refs", "POST",
    {"ref": "refs/heads/main", "sha": commit["sha"]}) if not parent else \
    api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/refs/heads/main", "PATCH",
        {"sha": commit["sha"], "force": False})
print("commit:", commit["sha"])
