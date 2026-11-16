#!/usr/bin/env python3
"""把 run-abroad-local 目录整体推到 GitHub（一次 commit，Git Data API）。"""
import base64, json, os, sys, urllib.request, urllib.error

TOKEN = os.environ["GITHUB_TOKEN"]
OWNER, REPO = "112179", "run-abroad-local"
ROOT = "/var/minis/workspace/run-abroad-local"
SKIP_DIRS = {".git", "dist", "build", "out", "tools", "seed.json"}


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
        print(f"HTTP {e.code} {url}\n{e.read().decode()[:400]}", file=sys.stderr)
        raise


# 当前 head
parent = None
try:
    ref = api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/ref/heads/main")
    parent = ref["object"]["sha"]
except urllib.error.HTTPError:
    pass
base_tree = None
if parent:
    base_tree = api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/commits/{parent}")["tree"]["sha"]

# 收集文件
files = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if d not in (".git", "dist", "build", "out", "tools")]
    for f in filenames:
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, ROOT)
        if rel == "seed.json":   # 已在 Support/ 下
            continue
        files.append(rel)
files.sort()

# 删除旧 web 目录：列出当前树里的 www/*
if base_tree:
    def walk(sha, prefix=""):
        t = api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/trees/{sha}")
        for e in t["tree"]:
            path = f"{prefix}{e['path']}"
            if e["type"] == "tree":
                yield from walk(e["sha"], path + "/")
            else:
                yield path
    existing = list(walk(base_tree))
else:
    existing = []

new_paths = set(f.replace(os.sep, "/") for f in files)
deletions = [p for p in existing if p not in new_paths]

entries = [{"path": p, "mode": "100644", "type": "blob", "sha": None} for p in deletions]

for rel in files:
    content = open(os.path.join(ROOT, rel), "rb").read()
    b = api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/blobs", "POST",
            {"content": base64.b64encode(content).decode(), "encoding": "base64"})
    entries.append({"path": rel.replace(os.sep, "/"), "mode": "100644",
                    "type": "blob", "sha": b["sha"]})

print(f"{len(files)} files, {len(deletions)} deletions")

# 删除用 sha=None 在同一棵树里不生效，改用两次 tree 提交：先删后加
payload = {"tree": entries}
if base_tree:
    payload["base_tree"] = base_tree
tree_sha = api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/trees", "POST", payload)["sha"]

msg = sys.argv[1] if len(sys.argv) > 1 else "update"
commit = api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/commits", "POST", {
    "message": msg, "tree": tree_sha, "parents": [parent] if parent else []})
if parent:
    api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/refs/heads/main", "PATCH",
        {"sha": commit["sha"], "force": True})
else:
    api(f"https://api.github.com/repos/{OWNER}/{REPO}/git/refs", "POST",
        {"ref": "refs/heads/main", "sha": commit["sha"]})
print("commit:", commit["sha"])
