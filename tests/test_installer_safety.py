"""Local installer/build-policy contracts. NOT a Resolve Studio host test."""
from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]

def normalized_sha256(path: Path) -> str:
    data=path.read_bytes().replace(b"\r\n",b"\n").replace(b"\r",b"\n")
    return hashlib.sha256(data).hexdigest()

class InstallerSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.nsi=(ROOT/"packaging/cartorig-preview.nsi").read_text(encoding="utf-8")
        cls.workflow_path=ROOT/".github/workflows/scene-timeline-windows.yml"
        cls.workflow=cls.workflow_path.read_text(encoding="utf-8")
        cls.scene=(ROOT/"host/cartorig-dev-scene.lua").read_text(encoding="utf-8")
        cls.shared=(ROOT/"support/verify-managed-shared.ps1").read_text(encoding="utf-8")
        cls.diagnostic=(ROOT/"support/cartorig-dev-diagnose.ps1").read_text(encoding="utf-8")

    def test_current_fuse_sources_are_recognized_by_strict_ownership(self):
        # Installer must recognize its own current Fuse bytes without
        # accepting arbitrary foreign or user-modified Resolve files.
        for filename in (
            "CartoRigWorldMap.fuse",
            "CartoRigCamera.fuse",
            "CartoRigRegion.fuse",
        ):
            source=ROOT/"fuses"/filename
            digest=normalized_sha256(source)
            self.assertIn(digest,self.shared,
                f"installer ownership verifier does not recognize {filename}: {digest}")

    def test_github_actions_is_build_only_and_manual(self):
        workflows=sorted((ROOT/".github/workflows").glob("*.y*ml"))
        self.assertEqual(workflows,[self.workflow_path],
            "GitHub Actions must be reserved exclusively for the final installer build")
        s=self.workflow
        self.assertIn("workflow_dispatch:",s)
        self.assertNotIn("\n  push:",s)
        self.assertNotIn("pull_request:",s)
        self.assertIn("build installer only",s)
        self.assertIn("makensis",s.lower())
        self.assertIn("upload-artifact@",s)
        self.assertIn("cartorig-dev-0.7.0-win64.exe",s)
        self.assertIn("tools/build_natural_earth.py",s)
        self.assertIn("purpose='build-only; tests executed outside GitHub Actions'",s)
        forbidden=(
            "pytest","unittest","test_lua","run_integration","package-validation",
            "legacy-preview-0.6","Start-Process -FilePath $new","diagnose.ps1"
        )
        for marker in forbidden:
            self.assertNotIn(marker,s,marker)

    def test_installer_version_and_build_identity(self):
        s=self.nsi
        self.assertIn('!define OUTPUTFILE "cartorig-dev-0.7.0-win64.exe"',s)
        self.assertIn('DisplayVersion" "0.7.0"',s)
        self.assertIn('Version: 0.7.0',s)
        self.assertIn('version=0.7.0',s)
        self.assertIn('!define BUILDSHA "development-unpinned"',s)
        self.assertIn('Build commit: ${BUILDSHA}',s)
        self.assertIn('build-info.txt',s)
        self.assertIn('"/DBUILDSHA=$env:GITHUB_SHA"',self.workflow)
        self.assertIn("commit=$env:GITHUB_SHA",self.workflow)
        self.assertIn('Build commit: ',self.scene)

    def test_install_and_uninstall_require_resolve_closed(self):
        s=self.nsi
        self.assertGreaterEqual(s.count('Get-Process -Name Resolve'),2)
        self.assertIn('DaVinci Resolve must be closed before installing or updating cartorig-dev',s)
        self.assertIn('DaVinci Resolve must be closed before uninstalling cartorig-dev',s)
        first_write=s.index('SetOutPath "$LOCALAPPDATA\\CartoRig\\App"')
        process_check=s.index('Get-Process -Name Resolve')
        self.assertLess(process_check,first_write)

    def test_runtime_dependencies_data_and_region_fuse_are_packaged(self):
        s=self.nsi
        expected=(
            'domain.lua','geo.lua','catalog.lua','blackmagic_api.lua',
            'fusion_contract.lua','render_geometry.lua','node_factory.lua','timeline_service.lua',
            'ne_50m_land.lua','ne_50m_admin0_borders.lua','ne_catalog.tsv',
            'natural-earth-manifest.json','CartoRigScene.fuse','CartoRigWorldMap.fuse',
            'CartoRigCamera.fuse','CartoRigRegion.fuse'
        )
        for marker in expected:
            self.assertIn(marker,s)
        self.assertIn('File /r "..\\build\\cartorig-data\\regions\\*"',s)
        self.assertIn('RMDir /r "$LOCALAPPDATA\\CartoRig\\App\\data\\regions"',s)
        self.assertNotIn('RMDir /r "$APPDATA\\Blackmagic Design',s)

    def test_single_utility_launcher_and_no_comp_reinstall(self):
        s=self.nsi
        self.assertIn('Scripts\\Utility"',s)
        self.assertEqual(s.count('File "/oname=cartorig-dev.lua.pending"'),1)
        self.assertIn('Rename "$R2\\cartorig-dev.lua.pending" "$R2\\cartorig-dev.lua"',s)
        self.assertNotIn('File "/oname=cartorig-dev.lua" "..\\host\\cartorig-dev-scene.lua"',s)
        self.assertIn('Rename "$R0\\cartorig-dev.lua" "$R0\\cartorig-dev.lua.migrated-060"',s)

    def test_shared_resolve_files_are_content_owned(self):
        verifier=self.shared
        current={
            "launcher": ROOT/"host/cartorig-dev-launcher.lua",
            "scene-fuse": ROOT/"fuses/CartoRigScene.fuse",
            "worldmap-fuse": ROOT/"fuses/CartoRigWorldMap.fuse",
            "camera-fuse": ROOT/"fuses/CartoRigCamera.fuse",
            "region-fuse": ROOT/"fuses/CartoRigRegion.fuse",
        }
        for kind,path in current.items():
            digest=normalized_sha256(path)
            self.assertIn(digest,verifier,
                f"ownership allowlist is stale for {kind}: {digest}")
            self.assertIn(f"-Kind {kind}",self.nsi)
        self.assertIn("SHA256",verifier)
        self.assertIn('Existing Utility cartorig-dev.lua was modified',self.nsi)
        self.assertIn('CartoRig Region Fuse was modified',self.nsi)

    def test_uninstaller_never_deletes_unverified_comp_launcher(self):
        s=self.nsi
        for suffix in ("","pending","backup","migrated-060"):
            filename="cartorig-dev.lua"+(("."+suffix) if suffix else "")
            self.assertNotIn(f'Delete "$INSTDIR\\Comp\\{filename}"',s)
        self.assertIn('verify-managed-comp-launcher.ps1',s)
        self.assertIn('Comp migration backup is unrecognized',s)

    def test_all_installer_error_dialogs_have_silent_defaults(self):
        dialogs=[line for line in self.nsi.splitlines() if 'MessageBox ' in line]
        self.assertGreater(len(dialogs),0)
        self.assertTrue(all('/SD IDOK' in line for line in dialogs),dialogs)

    def test_scene_ui_stays_structural(self):
        s=self.scene
        self.assertIn('service.create,resolve,title',s)
        self.assertIn('service.list_scenes,resolve',s)
        self.assertIn('service.search_locations,query,filter',s)
        self.assertIn(
            'service.add_region,resolve,scene.scene_id,result.dataset_id,result.source_id',s)
        self.assertIn(
            'service.rename_object,resolve,scene.scene_id,obj.id,newName',s)
        self.assertIn('ID="ObjectContext"',s)
        self.assertIn('ID="RenameObject"',s)
        self.assertNotIn('SetActiveTool',s)
        self.assertNotIn('TOOLB_Selected',s)
        self.assertNotIn('Open Scene',s)
        self.assertNotIn('OpenScene',s)

    def test_support_diagnostic_knows_milestone_a_runtime(self):
        d=self.diagnostic
        for marker in (
            "blackmagic_api.lua","fusion_contract.lua","render_geometry.lua","ne_catalog.tsv",
            "natural-earth-manifest.json","CartoRigRegion.fuse",
            "REGION_GEOMETRY_FILES","MILESTONE_A_RUNTIME_INCOMPLETE"
        ):
            self.assertIn(marker,d)

if __name__=="__main__":
    unittest.main()
