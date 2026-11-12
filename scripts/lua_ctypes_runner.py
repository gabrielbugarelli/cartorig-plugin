#!/usr/bin/env python3
"""Minimal local Lua runner backed by a system liblua shared library.

This is test infrastructure only. It does not ship in the CartoRig installer and
does not represent DaVinci Resolve's Lua host. It exists so the local source gate
can execute the same Lua test scripts when no lua5.1/luajit CLI is installed.
"""
from __future__ import annotations

import ctypes
import ctypes.util
import os
from pathlib import Path
import sys


def load_lua():
    candidates=("lua5.4","lua5.3","lua")
    for candidate in candidates:
        found=ctypes.util.find_library(candidate)
        if found:
            return ctypes.CDLL(found),candidate
    raise RuntimeError("No supported system liblua shared library found")


def quote_lua(value: str) -> str:
    return '"'+value.replace("\\","\\\\").replace('"','\\"')+'"'


def main() -> int:
    if len(sys.argv)<2:
        print("usage: lua_ctypes_runner.py SCRIPT [ARGS...]",file=sys.stderr)
        return 2
    lua,flavor=load_lua()
    L=ctypes.c_void_p
    lua.luaL_newstate.restype=L
    lua.luaL_openlibs.argtypes=[L]
    lua.luaL_loadfilex.argtypes=[L,ctypes.c_char_p,ctypes.c_char_p]
    lua.luaL_loadfilex.restype=ctypes.c_int
    lua.luaL_loadstring.argtypes=[L,ctypes.c_char_p]
    lua.luaL_loadstring.restype=ctypes.c_int
    lua.lua_pcallk.argtypes=[
        L,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p
    ]
    lua.lua_pcallk.restype=ctypes.c_int
    lua.lua_tolstring.argtypes=[L,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
    lua.lua_tolstring.restype=ctypes.c_char_p
    lua.lua_close.argtypes=[L]

    def error(state) -> str:
        size=ctypes.c_size_t()
        pointer=lua.lua_tolstring(state,-1,ctypes.byref(size))
        if not pointer:
            return "<no Lua error>"
        return ctypes.string_at(pointer,size.value).decode("utf-8","replace")

    root=Path.cwd().resolve()
    script=Path(sys.argv[1]).resolve()
    args=[str(script),*sys.argv[2:]]
    package_path=";".join((
        str(root/"src"/"?.lua"),
        str(root/"src"/"?"/"init.lua"),
        str(root/"src"/"CartoRig"/"?.lua"),
    ))+";"

    bootstrap=(
        "package.path="+quote_lua(package_path)+"..package.path; "
        "arg={"+",".join(
            f"[{index}]={quote_lua(value)}" for index,value in enumerate(args)
        )+"}; "
        "_G.CARTORIG_LOCAL_LUA_FLAVOR="+quote_lua(flavor)
    )

    state=lua.luaL_newstate()
    if not state:
        raise RuntimeError("luaL_newstate failed")
    lua.luaL_openlibs(state)
    try:
        for kind,payload in (
            ("string",bootstrap.encode("utf-8")),
            ("file",str(script).encode("utf-8")),
        ):
            if kind=="string":
                rc=lua.luaL_loadstring(state,payload)
            else:
                rc=lua.luaL_loadfilex(state,payload,None)
            if rc:
                print(error(state),file=sys.stderr)
                return rc
            rc=lua.lua_pcallk(state,0,0,0,0,None)
            if rc:
                print(error(state),file=sys.stderr)
                return rc
    finally:
        lua.lua_close(state)
    return 0


if __name__=="__main__":
    raise SystemExit(main())
