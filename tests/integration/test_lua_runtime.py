"""Exercise actual Lua core modules on a free Linux runner, no Resolve mock."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
LUA = os.getenv("CARTORIG_LUA_EXECUTABLE", "lua5.1")

class LuaRuntimeIntegration(unittest.TestCase):
    def invoke(self, script):
        env = dict(os.environ)
        env["LUA_PATH"] = str(ROOT / "src/?.lua") + ";" + str(ROOT / "src/?/init.lua") + ";;"
        result = subprocess.run([LUA, str(ROOT / script)], cwd=ROOT, env=env,
                                capture_output=True, text=True, timeout=15, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + "\n" + result.stderr)
        self.assertIn("PASS", result.stdout)
        return result

    def test_core_scene_identity_and_region_lifecycle(self):
        self.invoke("tests/lua/test_domain.lua")

    def test_shared_projection_geoanchor_and_dateline(self):
        self.invoke("tests/lua/test_geo.lua")

    def test_offline_catalog_search_and_disambiguation(self):
        self.invoke("tests/lua/test_catalog.lua")

if __name__ == "__main__":
    unittest.main()
