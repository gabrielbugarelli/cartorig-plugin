#!/usr/bin/env python3
"""CartoRig local test gate.

GitHub Actions is intentionally excluded from test execution. This runner has
two phases:

  source  - source/unit/integration contracts that need no downloaded Natural
            Earth checkout. Uses repository fixtures and the configured Lua
            interpreter.
  full    - everything in source plus tests against CARTORIG_DATA_DIR generated
            by the installer build. Run this locally after downloading the
            build artifact.

A Resolve Studio host run is a separate acceptance gate and is never implied by
this runner.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]


def lua_command() -> list[str]:
    configured=os.getenv("CARTORIG_LUA_EXECUTABLE")
    if configured:
        return [configured]
    for candidate in ("lua5.1","luajit","lua"):
        found=shutil.which(candidate)
        if found:
            return [found]
    fallback=ROOT/"scripts/lua_ctypes_runner.py"
    if fallback.is_file():
        return [sys.executable,str(fallback)]
    raise RuntimeError("No local Lua runtime or ctypes fallback is available")


def run_unittest_paths(paths: list[Path], *, env: dict[str,str]) -> bool:
    loader=unittest.TestLoader()
    suite=unittest.TestSuite()
    for path in paths:
        suite.addTests(loader.discover(
            str(path.parent), pattern=path.name, top_level_dir=str(ROOT)
        ))
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    return result.wasSuccessful()


def python_source_tests(env: dict[str,str]) -> bool:
    paths=sorted(ROOT.glob("tests/test_*.py"))
    if not paths:
        raise RuntimeError("No source Python tests found")
    return run_unittest_paths(paths,env=env)


def lua_contract_tests(env: dict[str,str]) -> bool:
    command=lua_command()
    env=dict(env)
    env["LUA_PATH"]=str(ROOT/"src/?.lua")+";"+str(ROOT/"src/?/init.lua")+";;"
    scripts=sorted((ROOT/"tests/lua").glob("test_*.lua"))
    if not scripts:
        raise RuntimeError("No Lua tests found")
    ok=True
    for script in scripts:
        args: list[str]=[]
        if script.name=="test_catalog.lua":
            args=[str(ROOT/"tests/fixtures/natural_earth_synthetic.tsv")]
        elif script.name=="test_land_source.lua":
            # The generated real Land is a full-phase test. The source phase
            # uses the committed/synthetic fixture only when present.
            source=ROOT/"data/ne_50m_land.lua"
            if not source.exists():
                print(f"LOCAL SOURCE SKIP: {script.name} (real generated data is full-phase)")
                continue
            args=[str(source)]
        print("LOCAL LUA:",script.relative_to(ROOT))
        result=subprocess.run(
            [*command,str(script),*args],cwd=ROOT,env=env,
            text=True,capture_output=True,timeout=60,check=False,
        )
        if result.stdout:
            print(result.stdout,end="")
        if result.stderr:
            print(result.stderr,end="",file=sys.stderr)
        if result.returncode!=0 or "PASS" not in result.stdout:
            ok=False
            print(f"FAILED: {script.relative_to(ROOT)}",file=sys.stderr)
    return ok


def generated_data_tests(env: dict[str,str]) -> bool:
    data_dir=env.get("CARTORIG_DATA_DIR")
    if not data_dir:
        raise RuntimeError("full phase requires CARTORIG_DATA_DIR")
    root=Path(data_dir)
    required=("ne_50m_land.lua","ne_50m_admin0_borders.lua","ne_catalog.tsv",
              "natural-earth-manifest.json")
    missing=[name for name in required if not (root/name).is_file()]
    if missing:
        raise RuntimeError("generated Natural Earth data missing: "+", ".join(missing))

    # Run the actual generated-data integration module locally.
    path=ROOT/"tests/integration/test_natural_earth_runtime.py"
    if not run_unittest_paths([path],env=env):
        return False

    command=lua_command()
    lua_env=dict(env)
    lua_env["LUA_PATH"]=str(ROOT/"src/?.lua")+";"+str(ROOT/"src/?/init.lua")+";;"
    for script,args in (
        (ROOT/"tests/lua/test_catalog.lua",[root/"ne_catalog.tsv"]),
        (ROOT/"tests/lua/test_land_source.lua",[root/"ne_50m_land.lua"]),
    ):
        result=subprocess.run(
            [*command,str(script),*map(str,args)],cwd=ROOT,env=lua_env,
            text=True,capture_output=True,timeout=120,check=False,
        )
        if result.stdout:
            print(result.stdout,end="")
        if result.stderr:
            print(result.stderr,end="",file=sys.stderr)
        if result.returncode!=0 or "PASS" not in result.stdout:
            return False
    return True


def main() -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument("--phase",choices=("source","full"),default="source")
    args=parser.parse_args()

    env=dict(os.environ)
    checks=[
        ("Python source tests",lambda: python_source_tests(env)),
        ("Lua source/contracts",lambda: lua_contract_tests(env)),
    ]
    if args.phase=="full":
        checks.append(("Generated Natural Earth runtime",lambda: generated_data_tests(env)))

    for label,check in checks:
        print("\n==",label,"==")
        try:
            passed=check()
        except Exception as exc:
            print(f"BLOCKED: {label}: {exc}",file=sys.stderr)
            return 1
        if not passed:
            print(f"FAILED: {label}",file=sys.stderr)
            return 1

    print(
        f"LOCAL {args.phase.upper()} GATE: PASS. "
        "DaVinci Resolve Studio host acceptance remains NOT RUN."
    )
    return 0


if __name__=="__main__":
    raise SystemExit(main())
