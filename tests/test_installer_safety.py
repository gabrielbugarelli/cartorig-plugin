"""Fail-closed static installer contracts. NOT a Resolve Studio host test."""
import hashlib
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
HISTORICAL=(
 "host/CartoRig Host Probe.lua",
 "host/CartoRig Native Integration Probe.lua",
 "host/CartoRig.lua",
 "src/CartoRig/native_probe.lua",
)

class InstallerSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.nsi=(ROOT/"packaging/cartorig-preview.nsi").read_text(encoding="utf-8")
        cls.win=(ROOT/".github/workflows/scene-timeline-windows.yml").read_text(encoding="utf-8")
        cls.launcher=(ROOT/"host/cartorig-dev-launcher.lua").read_text(encoding="utf-8")
        cls.scene=(ROOT/"host/cartorig-dev-scene.lua").read_text(encoding="utf-8")
        cls.cleaner=(ROOT/"support/cleanup-verified-legacy.ps1").read_text(encoding="utf-8")

    def test_single_utility_launcher_and_no_comp_reinstall(self):
        s=self.nsi
        self.assertIn('StrCpy $R2 "$APPDATA\\Blackmagic Design\\DaVinci Resolve\\Support\\Fusion\\Scripts\\Utility"',s)
        self.assertIn('SetOutPath "$R2"',s)
        self.assertEqual(s.count('File "/oname=cartorig-dev.lua.pending"'),1)
        self.assertIn('Rename "$R2\\cartorig-dev.lua.pending" "$R2\\cartorig-dev.lua"',s)
        self.assertNotIn('File "/oname=cartorig-dev.lua" "..\\host\\cartorig-dev-scene.lua"',s)
        self.assertIn('Rename "$R0\\cartorig-dev.lua" "$R0\\cartorig-dev.lua.migrated-060"',s)
        self.assertLess(s.index('Rename "$R2\\cartorig-dev.lua.pending"'),
                        s.index('Rename "$R0\\cartorig-dev.lua" "$R0\\cartorig-dev.lua.migrated-060"'))
        self.assertIn('DisplayVersion" "0.6.0"',s)

    def test_installer_dependencies_and_cleanup(self):
        s=self.nsi
        self.assertIn('File "/oname=timeline_service.lua" "..\\src\\CartoRig\\timeline_service.lua"',s)
        self.assertIn('File "/oname=cartorig_scene_ui.lua" "..\\host\\cartorig-dev-scene.lua"',s)
        self.assertIn('TimelineService missing',s)
        self.assertIn('Scene Fuse missing',s)
        self.assertIn('WorldMap Fuse missing',s)
        self.assertIn('Camera Fuse missing',s)
        self.assertIn('Delete "$INSTDIR\\Utility\\cartorig-dev.lua"',s)
        self.assertIn('Delete "$INSTDIR\\Comp\\cartorig-dev.lua.migrated-060"',s)
        self.assertIn('Delete "$LOCALAPPDATA\\CartoRig\\App\\lua\\CartoRig\\timeline_service.lua"',s)
        self.assertNotIn('RMDir /r "$APPDATA\\Blackmagic Design',s)

    def test_recovery_retains_old_comp_until_new_is_active(self):
        s=self.nsi
        self.assertNotIn('ExecWait \'"$LOCALAPPDATA\\CartoRig\\App\\Uninstall-CartoRig.exe"',s)
        self.assertIn('RestoreCartoRigUtility:',s)
        self.assertIn('MigrateCartoRigFailed:',s)
        self.assertIn('Previous migration backup',s) if 'Previous migration backup' in s else self.assertIn('migration backup',s)
        self.assertIn('cartorig-dev.lua.backup',s)

    def test_legacy_cleanup_only_for_verified_bytes(self):
        for relative in HISTORICAL:
            raw=(ROOT/relative).read_bytes().replace(b"\r\n",b"\n")
            for data in (raw,raw.replace(b"\n",b"\r\n")):
                self.assertIn(hashlib.sha256(data).hexdigest(),self.cleaner)
        self.assertIn('PRESERVED_UNKNOWN',self.cleaner)
        self.assertNotIn('Delete "$R0\\CartoRig.lua"',self.nsi)

    def test_utility_ui_has_no_open_scene_or_manual_context_dependency(self):
        s=self.scene
        self.assertIn('service.create,resolve,title',s)
        self.assertNotIn('OpenScene',s)
        self.assertNotIn('Open Scene',s)
        self.assertNotIn('WRONG_COMPOSITION',s)
        self.assertNotIn('SetActiveTool',s)
        self.assertIn('service.list_scenes,resolve',s)
        self.assertIn('fusion.UIManager',s)
        self.assertIn('status~=true',self.launcher)

    def test_windows_package_tests_real_upgrade_layout(self):
        s=self.win
        for marker in ('legacy-preview-0.5.2.nsi','cartorig-dev-0.6.0-win64.exe',
                       'Get-FileHash','Utility\\cartorig-dev.lua','Comp\\cartorig-dev.lua',
                       'TimelineService mismatch','Not exactly one Scripts menu entry',
                       'Foreign script affected','retention-days: 7'):
            self.assertIn(marker,s)
        self.assertNotIn('continue-on-error: true',s)

if __name__=="__main__":
    unittest.main()
