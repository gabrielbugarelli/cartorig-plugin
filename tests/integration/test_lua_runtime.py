"""Exercise Lua source modules locally; mocked tests are not Resolve host acceptance."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import unittest
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
configured = os.getenv("CARTORIG_LUA_EXECUTABLE")
if configured:
    LUA = [configured]
else:
    executable = next((shutil.which(x) for x in ("lua5.1", "luajit", "lua")
                       if shutil.which(x)), None)
    LUA = [executable] if executable else [
        sys.executable, str(ROOT / "scripts/lua_ctypes_runner.py")]

class LuaRuntimeIntegration(unittest.TestCase):
    def invoke(self, script, *args):
        env = dict(os.environ)
        env["LUA_PATH"] = str(ROOT / "src/?.lua") + ";" + str(ROOT / "src/?/init.lua") + ";;"
        result = subprocess.run([*LUA, str(ROOT / script), *map(str,args)], cwd=ROOT, env=env,
                                capture_output=True, text=True, timeout=40, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + "\n" + result.stderr)
        self.assertIn("PASS", result.stdout)
        return result

    def test_core_scene_identity_and_region_lifecycle(self):
        self.invoke("tests/lua/test_domain.lua")

    def test_shared_projection_geoanchor_and_dateline(self):
        self.invoke("tests/lua/test_geo.lua")

    def test_offline_catalog_search_and_disambiguation(self):
        data_dir=os.getenv("CARTORIG_DATA_DIR")
        source=Path(data_dir)/"ne_catalog.tsv" if data_dir else ROOT/"tests/fixtures/natural_earth_synthetic.tsv"
        self.invoke("tests/lua/test_catalog.lua",source)

    def test_defensive_fusion_bridge_mock_unit(self):
        self.invoke("tests/lua/test_native_probe.lua")

    def test_single_menu_launcher_fail_safe(self):
        self.invoke("tests/lua/test_launcher.lua")

    def test_blackmagic_api_contract_boundary(self):
        self.invoke("tests/lua/test_blackmagic_api.lua")

    def test_fusion_contract_boundary(self):
        self.invoke("tests/lua/test_fusion_contract.lua")

    def test_resolve_handle_type_safety_regressions(self):
        self.invoke("tests/lua/test_resolve_api_handles.lua")

    def test_scene_ui_uses_valid_resolve_handle_for_five_clicks(self):
        self.invoke("tests/lua/test_scene_ui_dispatch.lua")

    def test_factory_transactions_and_external_node_protection(self):
        self.invoke("tests/lua/test_node_factory.lua")

    def test_timeline_scene_lifecycle_and_non_destructive_append(self):
        # Resolve API mocked; does not count as Studio 20 acceptance.
        self.invoke("tests/lua/test_timeline_service.lua")

    def test_pinned_natural_earth_real_world_data(self):
        data_dir=os.getenv("CARTORIG_DATA_DIR")
        source=Path(data_dir)/"ne_50m_land.lua" if data_dir else ROOT/"data/ne_50m_land.lua"
        self.invoke("tests/lua/test_land_source.lua",source)

if __name__ == "__main__":
    unittest.main()
