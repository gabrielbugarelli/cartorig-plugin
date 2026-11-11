"""Exercise actual Lua source modules on a free runner, no Resolve acceptance mock."""
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
                                capture_output=True, text=True, timeout=40, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + "\n" + result.stderr)
        self.assertIn("PASS", result.stdout)
        return result

    def test_core_scene_identity_and_region_lifecycle(self):
        self.invoke("tests/lua/test_domain.lua")

    def test_shared_projection_geoanchor_and_dateline(self):
        self.invoke("tests/lua/test_geo.lua")

    def test_offline_catalog_search_and_disambiguation(self):
        self.invoke("tests/lua/test_catalog.lua")

    def test_defensive_fusion_bridge_mock_unit(self):
        self.invoke("tests/lua/test_native_probe.lua")

    def test_single_menu_launcher_fail_safe(self):
        self.invoke("tests/lua/test_launcher.lua")

    def test_factory_transactions_and_external_node_protection(self):
        self.invoke("tests/lua/test_node_factory.lua")

    def test_timeline_scene_lifecycle_and_non_destructive_append(self):
        # Resolve API mocked; does not count as Studio 20 acceptance.
        self.invoke("tests/lua/test_timeline_service.lua")

    def test_pinned_natural_earth_real_world_data(self):
        self.invoke("tests/lua/test_land_source.lua")

if __name__ == "__main__":
    unittest.main()
