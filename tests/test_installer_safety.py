"""Source-level guardrails for the only cartorig-dev Scripts entry.

These tests deliberately do not claim to execute licensed DaVinci Resolve.
"""
from pathlib import Path
import hashlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
HISTORICAL = (
    "host/CartoRig Host Probe.lua",
    "host/CartoRig Native Integration Probe.lua",
    "host/CartoRig.lua",
    "src/CartoRig/native_probe.lua",
)

class InstallerSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.nsi=(ROOT/"packaging/cartorig-preview.nsi").read_text(encoding="utf-8")
        cls.workflow=(ROOT/".github/workflows/cartorig-preview-windows.yml").read_text(encoding="utf-8")
        cls.launcher=(ROOT/"host/cartorig-dev-launcher.lua").read_text(encoding="utf-8")
        cls.scene=(ROOT/"host/cartorig-dev-scene.lua").read_text(encoding="utf-8")
        cls.cleanup=(ROOT/"support/cleanup-verified-legacy.ps1").read_text(encoding="utf-8")
        cls.prior=(ROOT/"packaging/legacy-preview-0.5.1.nsi").read_text(encoding="utf-8")

    def test_only_one_stable_comp_entry_is_written(self):
        self.assertEqual(len(re.findall(r'File "/oname=cartorig-dev.lua"',self.nsi)),0)
        self.assertEqual(len(re.findall(r'File "/oname=cartorig-dev.lua.pending"',self.nsi)),1)
        self.assertIn('host\\cartorig-dev-launcher.lua',self.nsi)
        self.assertIn('host\\cartorig-dev-scene.lua',self.nsi)
        self.assertIn('cartorig_scene_ui.lua',self.nsi)
        self.assertIn('cartorig-dev.lua.backup',self.nsi)
        self.assertIn('StrCpy $R0 "$APPDATA\\Blackmagic Design\\DaVinci Resolve\\Support\\Fusion\\Scripts\\Comp"',self.nsi)

    def test_no_pre_activation_uninstall_and_recoverable_upgrade(self):
        nsi=self.nsi
        self.assertNotIn('ExecWait \'"$LOCALAPPDATA\\CartoRig\\App\\Uninstall-CartoRig.exe"',nsi)
        self.assertNotIn('Uninstall-HostProbe.exe',nsi)
        self.assertNotIn('Uninstall-NativeIntegration.exe',nsi)
        self.assertIn('Rename "$R0\\cartorig-dev.lua.pending" "$R0\\cartorig-dev.lua"',nsi)
        self.assertIn('Rename "$R0\\cartorig-dev.lua.backup" "$R0\\cartorig-dev.lua"',nsi)
        self.assertIn('RestoreCartoRigLauncher:',nsi)
        self.assertIn('Recover the launcher from a previous interrupted update',nsi)
        self.assertIn('Version: 0.5.2',nsi)

    def test_unrecognized_legacy_never_deletes_untrusted_scripts(self):
        nsi=self.nsi
        active=nsi.index('VerifyCartoRigLauncher:')
        cleanup_call=nsi.index('ExecWait',active)
        self.assertLess(active,cleanup_call)
        self.assertIn('cleanup-verified-legacy.ps1',nsi)
        self.assertNotIn('An unmanaged old CartoRig script remains. Upgrade stopped.',nsi)
        self.assertNotIn('Delete "$R0\\CartoRig.lua"',nsi)
        self.assertIn('Get-FileHash -LiteralPath $path -Algorithm SHA256',self.cleanup)
        self.assertIn('if($item.Hashes -contains $sha)',self.cleanup)
        self.assertIn('Remove-Item -LiteralPath $path -Force',self.cleanup)
        self.assertIn('PRESERVED_UNKNOWN',self.cleanup)
        self.assertIn('Active cartorig-dev.lua is NEVER eligible',self.cleanup)

    def test_allowlist_matches_exact_historical_repository_bytes(self):
        for path in HISTORICAL:
            raw=(ROOT/path).read_bytes()
            canonical=raw.replace(b"\r\n",b"\n")
            lf=hashlib.sha256(canonical).hexdigest()
            crlf=hashlib.sha256(canonical.replace(b"\n",b"\r\n")).hexdigest()
            with self.subTest(path=path):
                self.assertIn(lf,self.cleanup,path)
                self.assertIn(crlf,self.cleanup,path)
        self.assertNotIn('"cartorig-dev.lua"',self.cleanup)

    def test_launcher_detects_false_and_nil_top_level_ui_returns(self):
        self.assertIn('pcall(dofile,ui)',self.launcher)
        self.assertIn('status~=true',self.launcher)
        self.assertIn('startup_failure',self.launcher)
        self.assertIn('last-error.txt',self.launcher)
        self.assertIn('return true',self.scene)
        for text in ('Fusion/UIManager is unavailable','LOCALAPPDATA missing',
                     'NodeFactory module not installed','open Fusion Composition first'):
            self.assertIn(text,self.scene)
        self.assertNotIn('FuRegisterClass',self.launcher)

    def test_installer_checks_critical_runtime_before_activation(self):
        source=self.nsi
        staging=source.index('File "/oname=cartorig-dev.lua.pending"')
        for message in ("Scene UI missing","NodeFactory missing","Offline map data missing",
                        "Scene Fuse missing","WorldMap Fuse missing","Camera Fuse missing"):
            self.assertLess(source.index(message),staging)
        self.assertIn('File "/oname=cleanup-verified-legacy.ps1"',source)
        self.assertIn('File "/oname=cartorig_scene_ui.lua"',source)

    def test_actions_reproduce_prior_051_and_failure_cases(self):
        w=self.workflow
        for marker in ('legacy-preview-0.5.nsi','legacy-preview-0.5.1.nsi',
                       'expectedLauncherHash','expectedUiHash',
                       'Interrupted update','Stale backup','Unknown orphaned',
                       'REMOVED_VERIFIED:', 'PRESERVED_UNKNOWN:', 'Fresh install must also publish'):
            self.assertIn(marker,w)
        self.assertIn('retention-days: 7',w)
        self.assertNotIn('continue-on-error: true',w)
        self.assertIn('File "/oname=cartorig-dev.lua.pending"',self.prior)
        self.assertNotIn('cleanup-verified-legacy.ps1',self.prior)

    def test_uninstaller_scope_is_limited_to_owned_files(self):
        source=self.nsi
        self.assertIn('Delete "$INSTDIR\\Comp\\cartorig-dev.lua"',source)
        self.assertIn('Delete "$LOCALAPPDATA\\CartoRig\\App\\lua\\cartorig_scene_ui.lua"',source)
        self.assertIn('Delete "$LOCALAPPDATA\\CartoRig\\App\\cleanup-verified-legacy.ps1"',source)
        self.assertNotIn('RMDir /r "$APPDATA\\Blackmagic Design',source)
        self.assertNotIn('Delete "$INSTDIR\\Comp\\CartoRig.lua"',source)

if __name__=="__main__":
    unittest.main()
