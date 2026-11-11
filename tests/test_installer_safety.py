"""Fail-closed static deployment contracts for the single Fusion script entry.

These are source/installer checks, not evidence of DaVinci Resolve's live menu.
"""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]

class InstallerSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.nsi=(ROOT/"packaging/cartorig-preview.nsi").read_text(encoding="utf-8")
        cls.workflow=(ROOT/".github/workflows/cartorig-preview-windows.yml").read_text(encoding="utf-8")
        cls.launcher=(ROOT/"host/cartorig-dev-launcher.lua").read_text(encoding="utf-8")
        cls.prior=(ROOT/"packaging/legacy-preview-0.5.nsi").read_text(encoding="utf-8")

    def test_only_one_stable_comp_entry_is_written(self):
        self.assertEqual(len(re.findall(r'File "/oname=cartorig-dev.lua"',self.nsi)),0)
        self.assertEqual(len(re.findall(r'File "/oname=cartorig-dev.lua.pending"',self.nsi)),1)
        self.assertIn('host\\cartorig-dev-launcher.lua',self.nsi)
        self.assertIn('host\\cartorig-dev-scene.lua',self.nsi)
        self.assertIn('cartorig_scene_ui.lua',self.nsi)
        self.assertIn('cartorig-dev.lua.pending',self.nsi)
        self.assertIn('cartorig-dev.lua.backup',self.nsi)
        self.assertIn('StrCpy $R0 "$APPDATA\\Blackmagic Design\\DaVinci Resolve\\Support\\Fusion\\Scripts\\Comp"',self.nsi)

    def test_previous_installer_does_not_run_during_in_place_upgrade(self):
        self.assertNotIn('ExecWait \'"$LOCALAPPDATA\\CartoRig\\App\\Uninstall-CartoRig.exe"',self.nsi)
        self.assertIn('Uninstall-HostProbe.exe',self.nsi)
        self.assertIn('Uninstall-NativeIntegration.exe',self.nsi)
        self.assertIn('Rename "$R0\\cartorig-dev.lua.pending" "$R0\\cartorig-dev.lua"',self.nsi)
        self.assertIn('Rename "$R0\\cartorig-dev.lua.backup" "$R0\\cartorig-dev.lua"',self.nsi)

    def test_launcher_reports_runtime_failures_instead_of_silent_disappearance(self):
        self.assertIn('pcall(dofile,ui)',self.launcher)
        self.assertIn('last-error.txt',self.launcher)
        self.assertIn('cartorig_scene_ui.lua',self.launcher)
        self.assertNotIn('FuRegisterClass',self.launcher)

    def test_actions_reproduce_previous_bug_and_verify_both_install_modes(self):
        self.assertIn('legacy-preview-0.5.nsi',self.workflow)
        self.assertIn('expectedLauncherHash',self.workflow)
        self.assertIn('expectedUiHash',self.workflow)
        self.assertIn('Fresh install must also publish',self.workflow)
        self.assertIn('install-location.txt',self.workflow)
        self.assertIn('retention-days: 7',self.workflow)
        self.assertNotIn('continue-on-error: true',self.workflow)
        self.assertIn('File "/oname=cartorig-dev.lua" "..\\host\\cartorig-dev-scene.lua"',self.prior)
        self.assertNotIn('cartorig-dev.lua.pending',self.prior)

    def test_legacy_files_never_block_launcher_activation(self):
        source=self.nsi
        activation=source.index('Rename "$R0\\cartorig-dev.lua.pending" "$R0\\cartorig-dev.lua"')
        self.assertLess(activation,source.index('ExecWait \'"$LOCALAPPDATA\\CartoRig\\HostProbe\\Uninstall-HostProbe.exe"'))
        self.assertLess(activation,source.index('ExecWait \'"$LOCALAPPDATA\\CartoRig\\NativeIntegrationProbe\\Uninstall-NativeIntegration.exe"'))
        self.assertNotIn('An unmanaged old CartoRig script remains. Upgrade stopped.',source)
        self.assertIn('Old CartoRig.lua persists; not removed without ownership',source)
        self.assertIn('Recover the launcher from a previous interrupted update',source)
        self.assertIn('Rename "$R0\\cartorig-dev.lua.backup" "$R0\\cartorig-dev.lua"',source)
        self.assertIn('Version: 0.5.2',source)

    def test_required_runtime_is_checked_before_replacing_launcher(self):
        source=self.nsi
        marker=source.index('File "/oname=cartorig-dev.lua.pending"')
        self.assertLess(source.index('UI missing; the existing menu script was preserved.'),marker)
        self.assertLess(source.index('NodeFactory missing; the existing menu script was preserved.'),marker)
        self.assertLess(source.index('Offline map data missing; the existing menu script was preserved.'),marker)
        self.assertIn('File "/oname=cartorig_scene_ui.lua"',source)
        self.assertIn('Unmanaged',source)

    def test_update_and_uninstall_have_one_owned_scope(self):
        self.assertIn('Delete "$INSTDIR\\Comp\\cartorig-dev.lua"',self.nsi)
        self.assertIn('Delete "$LOCALAPPDATA\\CartoRig\\App\\lua\\cartorig_scene_ui.lua"',self.nsi)
        self.assertNotIn('RMDir /r "$APPDATA\\Blackmagic Design',self.nsi)

if __name__=="__main__":
    unittest.main()
