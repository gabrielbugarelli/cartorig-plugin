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
        cls.shared=(ROOT/"support/verify-managed-shared.ps1").read_text(encoding="utf-8")

    def test_build_identity_is_embedded_and_reportable(self):
        s=self.nsi
        self.assertIn('!define BUILDSHA "development-unpinned"',s)
        self.assertIn('Build commit: ${BUILDSHA}',s)
        self.assertIn('build-info.txt',s)
        self.assertIn('"/DBUILDSHA=$env:GITHUB_SHA"',self.win)
        self.assertIn("commit=$env:GITHUB_SHA",self.win)
        self.assertIn('Build commit: ',self.scene)

    def test_install_and_uninstall_require_resolve_closed(self):
        s=self.nsi
        self.assertGreaterEqual(s.count('Get-Process -Name Resolve'),2)
        self.assertIn('DaVinci Resolve must be closed before installing or updating cartorig-dev',s)
        self.assertIn('DaVinci Resolve must be closed before uninstalling cartorig-dev',s)
        first_write=s.index('SetOutPath "$LOCALAPPDATA\\CartoRig\\App"')
        process_check=s.index('Get-Process -Name Resolve')
        self.assertLess(process_check,first_write)

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
        self.assertIn('DisplayVersion" "0.6.4"',s)

    def test_installer_dependencies_and_cleanup(self):
        s=self.nsi
        self.assertIn('File "/oname=timeline_service.lua" "..\\src\\CartoRig\\timeline_service.lua"',s)
        self.assertIn('File "/oname=blackmagic_api.lua" "..\\src\\CartoRig\\blackmagic_api.lua"',s)
        self.assertIn('File "/oname=fusion_contract.lua" "..\\src\\CartoRig\\fusion_contract.lua"',s)
        self.assertIn('File "/oname=cartorig_scene_ui.lua" "..\\host\\cartorig-dev-scene.lua"',s)
        self.assertIn('Blackmagic API contract boundary missing',s)
        self.assertIn('Fusion contract boundary missing',s)
        self.assertIn('TimelineService missing',s)
        self.assertIn('Scene Fuse missing',s)
        self.assertIn('WorldMap Fuse missing',s)
        self.assertIn('Camera Fuse missing',s)
        self.assertIn('Delete "$INSTDIR\\Utility\\cartorig-dev.lua"',s)
        self.assertNotIn('Delete "$INSTDIR\\Comp\\cartorig-dev.lua.migrated-060"',s)
        self.assertIn('Delete "$LOCALAPPDATA\\CartoRig\\App\\lua\\CartoRig\\blackmagic_api.lua"',s)
        self.assertIn('Delete "$LOCALAPPDATA\\CartoRig\\App\\lua\\CartoRig\\fusion_contract.lua"',s)
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
        self.assertIn('require,"CartoRig.blackmagic_api"',s)
        self.assertIn('api.call_function(bmd,"scriptapp","Resolve")',s)
        self.assertIn('api.call_function(bmd,"UIDispatcher",ui)',s)
        self.assertNotIn('local function api_member',s)
        self.assertIn('status~=true',self.launcher)

    def test_resolve_api_receivers_are_validated_by_shared_boundary(self):
        service=(ROOT/"src/CartoRig/timeline_service.lua").read_text(encoding="utf-8")
        boundary=(ROOT/"src/CartoRig/blackmagic_api.lua").read_text(encoding="utf-8")
        self.assertIn('require("CartoRig.blackmagic_api")',service)
        self.assertIn('API_INVALID_RECEIVER:',boundary)
        self.assertIn('API_INVALID_HANDLE:',boundary)
        self.assertIn('pcall(function() return receiver[key] end)',boundary)
        self.assertIn('require_handle(manager,"GetProjectManager"',service)
        self.assertIn('require_handle(comp,"GetFusionCompByIndex","GetToolList")',service)
        self.assertIn('api.method(supplied_resolve,"GetProjectManager")',self.scene)
        self.assertIn('api.call_function(bmd,"scriptapp","Resolve")',self.scene)
        self.assertIn('RESOLVE_CONTEXT_INVALID:',self.scene)

    def test_historical_buggy_060_upgrade_is_an_actual_fixture(self):
        current=(ROOT/"src/CartoRig/timeline_service.lua").read_text(encoding="utf-8")
        prior=(ROOT/"src/CartoRig/legacy_timeline_service_0.6.0.lua").read_text(encoding="utf-8")
        self.assertIn('return o and type(o[name])=="function"',prior)
        self.assertNotIn('return o and type(o[name])=="function"',current)
        fixture=(ROOT/"packaging/legacy-preview-0.6.0.nsi").read_text(encoding="utf-8")
        self.assertIn('legacy_timeline_service_0.6.0.lua',fixture)
        self.assertIn('legacy-scene-ui-0.6.0.lua',fixture)
        self.assertIn('originalService',self.win)
        self.assertIn('originalUi',self.win)

    def test_historical_061_missing_subframe_flag_is_an_actual_fixture(self):
        prior=(ROOT/"src/CartoRig/legacy_timeline_service_0.6.1.lua").read_text(encoding="utf-8")
        current=(ROOT/"src/CartoRig/timeline_service.lua").read_text(encoding="utf-8")
        self.assertIn('call(item,"GetStart")',prior)
        self.assertIn('call(item,"GetEnd")',prior)
        self.assertNotIn('call(item,"GetStart")',current)
        self.assertNotIn('call(item,"GetEnd")',current)
        self.assertIn('call(item,"GetStart",false)',current)
        self.assertIn('call(item,"GetEnd",false)',current)
        fixture=(ROOT/"packaging/legacy-preview-0.6.1.nsi").read_text(encoding="utf-8")
        self.assertIn('legacy_timeline_service_0.6.1.lua',fixture)
        self.assertIn('service061',self.win)

    def test_all_installer_error_dialogs_have_silent_defaults(self):
        dialogs=[line for line in self.nsi.splitlines() if 'MessageBox ' in line]
        self.assertGreater(len(dialogs),0)
        self.assertTrue(all('/SD IDOK' in line for line in dialogs), dialogs)
    def test_legacy_comp_migration_requires_exact_content_ownership(self):
        s=self.nsi
        verifier=(ROOT/"support/verify-managed-comp-launcher.ps1").read_text(encoding="utf-8")
        self.assertIn('verify-managed-comp-launcher.ps1',s)
        self.assertIn('Comp\\cartorig-dev.lua is not an exact recognized CartoRig 0.5.1/0.5.2 launcher',s)
        self.assertIn('cartorig-dev.lua.backup is unrecognized',s)
        self.assertIn('cartorig-dev.lua.pending is unrecognized',s)
        self.assertIn('Comp migration backup is unrecognized',s)
        self.assertIn('Delete "$R0\\cartorig-dev.lua.migrated-060"',s)
        self.assertLess(s.index('verify-managed-comp-launcher.ps1'),
                        s.index('Delete "$R0\\cartorig-dev.lua.backup"'))
        self.assertIn('Both Utility and Comp cartorig-dev.lua exist',s)
        self.assertIn('997bd170c2b2a1ea921119c61ce53a5cee53bc1324ee715446c84cd96248ea4a',verifier)
        self.assertIn('6d1bd1fd52575bea31e73754f3408dbb0351d6089701690e6e82c95240a9b262',verifier)
        self.assertIn('Replace("`r`n","`n")',verifier)
        self.assertIn('0.6.4 changed conflicting external Comp/cartorig-dev.lua',self.win)
        self.assertIn('0.6.4 changed unrecognized/modified legacy Comp launcher',self.win)
        self.assertIn('Verified 0.5.2 legacy launcher did not migrate cleanly to 0.6.4',self.win)
    def test_shared_resolve_files_require_content_ownership(self):
        s=self.nsi
        verifier=self.shared
        self.assertIn('verify-managed-shared.ps1',s)
        self.assertIn('-Kind launcher',s)
        self.assertIn('-Kind scene-fuse',s)
        self.assertIn('-Kind worldmap-fuse',s)
        self.assertIn('-Kind camera-fuse',s)
        self.assertIn('c088214364f1226508348ebe662ed310a253fd5606253ab211307d7c17a3672f',verifier)
        self.assertIn('17c28628c767353a7a558674f202371d325655bba5613e195b02fe603ab93759',verifier)
        self.assertIn('e01a3e4c6823495612ccf11149a73f8f988e35ce1fa539028c8de1d06f6c9960',verifier)
        self.assertIn('617eaf8578fce3ac21f150eff6124c71070149995e3753cad082b2bde04f4cb3',verifier)
        self.assertIn('Existing Utility cartorig-dev.lua was modified',s)
        self.assertIn('CartoRig Scene Fuse was modified',s)
        self.assertIn('Uninstaller deleted or changed modified Utility/cartorig-dev.lua',self.win)
        self.assertIn('Uninstaller deleted or changed modified CartoRigScene.fuse',self.win)

    def test_reviewed_uninstaller_preserves_unowned_comp_entry(self):
        s=self.nsi
        self.assertNotIn('Delete "$INSTDIR\\Comp\\cartorig-dev.lua"',s)
        self.assertNotIn('Delete "$INSTDIR\\Comp\\cartorig-dev.lua.pending"',s)
        self.assertNotIn('Delete "$INSTDIR\\Comp\\cartorig-dev.lua.backup"',s)
        self.assertNotIn('Delete "$INSTDIR\\Comp\\cartorig-dev.lua.migrated-060"',s)
        self.assertIn('Uninstaller deleted or changed unowned Comp/cartorig-dev.lua',self.win)

    def test_historical_062_fixture_is_pinned_before_reviewed_063(self):
        current=(ROOT/"src/CartoRig/timeline_service.lua").read_text(encoding="utf-8")
        prior=(ROOT/"src/CartoRig/legacy_timeline_service_0.6.2.lua").read_text(encoding="utf-8")
        self.assertIn('require_existing_mediaout',prior)
        self.assertNotIn('require_existing_mediaout',current)
        self.assertIn('disallow_new_mediaout=true',current)
        fixture=(ROOT/"packaging/legacy-preview-0.6.2.nsi").read_text(encoding="utf-8")
        self.assertIn('legacy_timeline_service_0.6.2.lua',fixture)
        self.assertIn('legacy_node_factory_0.6.2.lua',fixture)
        self.assertIn('service062',self.win)
        self.assertIn('factory062',self.win)

    def test_historical_063_flags_iteration_bug_is_pinned_before_064(self):
        current=(ROOT/"src/CartoRig/timeline_service.lua").read_text(encoding="utf-8")
        prior=(ROOT/"src/CartoRig/legacy_timeline_service_0.6.3.lua").read_text(encoding="utf-8")
        boundary=(ROOT/"src/CartoRig/blackmagic_api.lua").read_text(encoding="utf-8")
        self.assertIn('for index,item in pairs(items)',prior)
        self.assertIn('for _,item in pairs(clips)',prior)
        self.assertNotIn('for index,item in pairs(items)',current)
        self.assertNotIn('for _,item in pairs(clips)',current)
        self.assertIn('api.sequence(raw or {}',current)
        self.assertIn('BINDING_METADATA={__flags=true}',boundary)
        fixture=(ROOT/"packaging/legacy-preview-0.6.3.nsi").read_text(encoding="utf-8")
        self.assertIn('legacy_timeline_service_0.6.3.lua',fixture)
        self.assertIn('legacy_node_factory_0.6.3.lua',fixture)
        self.assertIn('legacy_domain_0.6.3.lua',fixture)
        self.assertIn('legacy-scene-ui-0.6.3.lua',fixture)
        self.assertIn('$old063',self.win)
        self.assertIn('domain063',self.win)
        self.assertIn('service063',self.win)
        self.assertIn('factory063',self.win)
        self.assertIn('ui063',self.win)

    def test_windows_package_tests_real_upgrade_layout(self):
        s=self.win
        for marker in ('legacy-preview-0.5.2.nsi','legacy-preview-0.6.0.nsi','legacy-preview-0.6.1.nsi','legacy-preview-0.6.2.nsi','legacy-preview-0.6.3.nsi','cartorig-dev-0.6.4-win64.exe',
                       'Get-FileHash','Utility\\cartorig-dev.lua','Comp\\cartorig-dev.lua',
                       'TimelineService mismatch','Not exactly one Scripts menu entry',
                       'Foreign script affected','retention-days: 7'):
            self.assertIn(marker,s)
        self.assertNotIn('continue-on-error: true',s)

if __name__=="__main__":
    unittest.main()
