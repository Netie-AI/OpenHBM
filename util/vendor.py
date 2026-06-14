"""util/vendor.py -- pin and pull external sources into hw/vendor/.

Modelled after lowRISC's `util/vendor.py` from OpenTitan. Reads a manifest of
upstream sources (`hw/vendor/<name>.lock.hjson`), shallow-clones each at the
pinned commit, optionally applies patches, and stages the result under
`hw/vendor/<name>/`. Designed to be hermetic and reproducible.

Usage
-----

    # Update everything from the manifest, in-place:
    python util/vendor.py --refresh

    # Refresh only one library:
    python util/vendor.py --refresh lowrisc_prim

    # Verify that vendored sources match their lockfile (CI gate):
    python util/vendor.py --verify

    # List configured libraries:
    python util/vendor.py --list

Manifest format (Hjson)
-----------------------

    // hw/vendor/lowrisc_prim.lock.hjson
    {
      name:        "lowrisc_prim",
      target_dir:  "hw/vendor/lowrisc_prim",
      upstream: {
        url:    "https://github.com/lowRISC/opentitan.git",
        rev:    "<git sha>",
        only_subdir: "hw/ip/prim",
      },
      patch_dir: "hw/vendor/patches/lowrisc_prim",  // optional
      exclude: [
        "*/dv/cov/*",
      ],
    }
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import hjson  # type: ignore
except ImportError:
    print("ERROR: hjson not installed. Run `uv sync`.", file=sys.stderr)
    sys.exit(2)

REPO_ROOT = Path(__file__).resolve().parents[1]
VENDOR_DIR = REPO_ROOT / "hw" / "vendor"


@dataclass
class Manifest:
    name: str
    target_dir: Path
    url: str
    rev: str
    only_subdir: str | None = None
    patch_dir: Path | None = None
    exclude: list[str] | None = None
    license: str = "see-upstream"

    @classmethod
    def from_dict(cls, d: dict) -> Manifest:
        upstream = d["upstream"]
        return cls(
            name=d["name"],
            target_dir=REPO_ROOT / d["target_dir"],
            url=upstream["url"],
            rev=upstream["rev"],
            only_subdir=upstream.get("only_subdir"),
            patch_dir=(REPO_ROOT / d["patch_dir"]) if d.get("patch_dir") else None,
            exclude=d.get("exclude") or [],
            license=d.get("license", "see-upstream"),
        )


def load_manifests(filter_: str | None = None) -> list[Manifest]:
    manifests: list[Manifest] = []
    for path in sorted(VENDOR_DIR.glob("*.lock.hjson")):
        with path.open() as f:
            data = hjson.load(f)
        m = Manifest.from_dict(data)
        if filter_ is None or m.name == filter_:
            manifests.append(m)
    return manifests


def run(cmd: list[str], cwd: Path | None = None) -> None:
    print(f"+ {' '.join(cmd)}")
    subprocess.run(cmd, check=True, cwd=cwd)


def fetch_one(m: Manifest, work_root: Path) -> Path:
    """Shallow-clone the upstream and check out the pinned rev. Returns the
    directory containing the staged sources (possibly a subdirectory of the
    clone, if `only_subdir` is set)."""
    work = work_root / m.name
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)

    run(["git", "init", "-q"], cwd=work)
    run(["git", "remote", "add", "origin", m.url], cwd=work)
    run(["git", "fetch", "--depth=1", "origin", m.rev], cwd=work)
    run(["git", "checkout", "-q", "FETCH_HEAD"], cwd=work)

    src = work / m.only_subdir if m.only_subdir else work
    if not src.exists():
        raise RuntimeError(f"only_subdir {m.only_subdir!r} not present in {m.url} @ {m.rev}")
    return src


def apply_excludes(staging: Path, patterns: list[str]) -> None:
    for pat in patterns:
        for path in staging.rglob(pat.lstrip("/")):
            if path.is_dir():
                shutil.rmtree(path)
            elif path.exists():
                path.unlink()


def apply_patches(staging: Path, patch_dir: Path | None) -> None:
    if patch_dir is None or not patch_dir.exists():
        return
    for patch in sorted(patch_dir.glob("*.patch")):
        run(["git", "apply", "--directory", str(staging), str(patch)])


def install_one(m: Manifest, work_root: Path) -> None:
    print(f"\n=== {m.name} ===")
    src = fetch_one(m, work_root)

    if m.exclude:
        apply_excludes(src, m.exclude)
    if m.patch_dir:
        apply_patches(src, m.patch_dir)

    if m.target_dir.exists():
        shutil.rmtree(m.target_dir)
    m.target_dir.mkdir(parents=True, exist_ok=True)
    # Copy contents only (do not nest yet another src/).
    for child in src.iterdir():
        if child.name == ".git":
            continue
        dst = m.target_dir / child.name
        if child.is_dir():
            shutil.copytree(child, dst)
        else:
            shutil.copy2(child, dst)

    (m.target_dir / "VENDOR.lock.json").write_text(
        json.dumps(
            {"name": m.name, "url": m.url, "rev": m.rev, "license": m.license},
            indent=2,
            sort_keys=True,
        )
    )
    print(f"OK: {m.name} -> {m.target_dir.relative_to(REPO_ROOT)} (rev {m.rev[:12]})")


def verify(manifests: list[Manifest]) -> int:
    bad = 0
    for m in manifests:
        lock = m.target_dir / "VENDOR.lock.json"
        if not lock.exists():
            print(f"FAIL: {m.name} not vendored")
            bad += 1
            continue
        data = json.loads(lock.read_text())
        if data["rev"] != m.rev or data["url"] != m.url:
            print(f"FAIL: {m.name} drifted (lock={data['rev'][:12]} manifest={m.rev[:12]})")
            bad += 1
        else:
            print(f"OK:   {m.name} @ {data['rev'][:12]}")
    return bad


def main() -> None:
    ap = argparse.ArgumentParser(description="Vendor external sources into hw/vendor/")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument(
        "--refresh",
        nargs="?",
        const="__all__",
        metavar="NAME",
        help="Refresh all (no arg) or one named library",
    )
    g.add_argument(
        "--verify", action="store_true", help="Verify vendored sources match their lockfiles"
    )
    g.add_argument("--list", action="store_true", help="List configured libraries")
    args = ap.parse_args()

    if args.list:
        for m in load_manifests():
            print(f"{m.name:<24} {m.url}@{m.rev[:12]}")
        return

    manifests = load_manifests(None if args.refresh in (None, "__all__") else args.refresh)
    if not manifests:
        print("No matching manifests under hw/vendor/*.lock.hjson")
        sys.exit(1)

    if args.verify:
        sys.exit(verify(manifests))

    work_root = REPO_ROOT / "build" / "vendor_work"
    work_root.mkdir(parents=True, exist_ok=True)
    try:
        for m in manifests:
            install_one(m, work_root)
    finally:
        shutil.rmtree(work_root, ignore_errors=True)


if __name__ == "__main__":
    main()
