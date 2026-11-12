!include "MUI2.nsh"
!include "LogicLib.nsh"
!ifndef OUTPUTFILE
  !define OUTPUTFILE "cartorig-dev-0.6.4-win64.exe"
!endif
!ifndef BUILDSHA
  !define BUILDSHA "development-unpinned"
!endif
Unicode true
Name "cartorig-dev"
OutFile "${OUTPUTFILE}"
RequestExecutionLevel user
InstallDir "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts"
ShowInstDetails show
ShowUninstDetails show
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install cartorig-dev"
  ; Canonical per-user location; never rely on user-customizable $INSTDIR.
  StrCpy $R0 "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp"
  ; Utility is visible on every Resolve page; Comp is Fusion-context-only.
  StrCpy $R2 "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility"
  StrCpy $R9 "Managed legacy cleanup: no error"
  ; Stage ownership verifiers before any shared Resolve file is inspected.
  InitPluginsDir
  SetOutPath "$PLUGINSDIR"
  File "/oname=verify-managed-comp-launcher.ps1" "..\support\verify-managed-comp-launcher.ps1"
  File "/oname=verify-managed-shared.ps1" "..\support\verify-managed-shared.ps1"
  ; Resolve caches scripts/Fuses while running. Refuse mutation until the host is
  ; closed so installation cannot leave menu visibility or loaded Fuse versions stale.
  ClearErrors
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -Command "if(Get-Process -Name Resolve -ErrorAction SilentlyContinue){exit 10}else{exit 0}"' $0
  ${If} $0 != 0
    MessageBox MB_OK|MB_ICONSTOP "DaVinci Resolve must be closed before installing or updating cartorig-dev. No persistent files were changed." /SD IDOK
    Abort
  ${EndIf}
  ; The only development entry must be installed by a CartoRig-managed installer.
  ${If} ${FileExists} "$R0\cartorig-dev.lua"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "Existing Comp cartorig-dev.lua is unmanaged; no files were changed." /SD IDOK
      Abort
    ${EndIf}
  ${EndIf}
  ${If} ${FileExists} "$R2\cartorig-dev.lua"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "Existing Utility cartorig-dev.lua is unmanaged. No files were changed." /SD IDOK
      Abort
    ${EndIf}
    ClearErrors
    ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\verify-managed-shared.ps1" -Path "$R2\cartorig-dev.lua" -Kind launcher' $0
    ${If} $0 != 0
      MessageBox MB_OK|MB_ICONSTOP "Existing Utility cartorig-dev.lua was modified or is not a recognized CartoRig launcher. It was preserved and upgrade stopped." /SD IDOK
      Abort
    ${EndIf}
    ${If} ${FileExists} "$R0\cartorig-dev.lua"
      MessageBox MB_OK|MB_ICONSTOP "Both Utility and Comp cartorig-dev.lua exist. The Comp file is preserved as unverified; resolve the duplicate before upgrading." /SD IDOK
      Abort
    ${EndIf}
  ${EndIf}
  ; Ownership verifiers are already staged above before all preflight checks.
  ; A persistent migration backup is removed only when its exact source bytes
  ; prove that it is a historical CartoRig launcher and Utility is already active.
  ${If} ${FileExists} "$R0\cartorig-dev.lua.migrated-060"
    ${If} ${FileExists} "$R0\cartorig-dev.lua"
      MessageBox MB_OK|MB_ICONSTOP "Conflicting Comp launcher and migration backup found. Update stopped." /SD IDOK
      Abort
    ${EndIf}
    ${IfNot} ${FileExists} "$R2\cartorig-dev.lua"
      MessageBox MB_OK|MB_ICONSTOP "Comp migration backup exists without an active Utility launcher. It was preserved; repair manually before upgrade." /SD IDOK
      Abort
    ${EndIf}
    ClearErrors
    ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\verify-managed-comp-launcher.ps1" -Path "$R0\cartorig-dev.lua.migrated-060"' $0
    ${If} $0 != 0
      MessageBox MB_OK|MB_ICONSTOP "Comp migration backup is unrecognized. It was preserved and the upgrade was stopped." /SD IDOK
      Abort
    ${EndIf}
    ClearErrors
    Delete "$R0\cartorig-dev.lua.migrated-060"
    IfErrors 0 +3
      MessageBox MB_OK|MB_ICONSTOP "Verified migration backup could not be removed. Upgrade stopped without changing it." /SD IDOK
      Abort
  ${EndIf}
  ; Refuse to overwrite external Fuse tools: only the CartoRig managed
  ; uninstaller may own these filenames.
  ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigScene.fuse"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig Scene Fuse exists without CartoRig ownership. No files changed." /SD IDOK
      Abort
    ${EndIf}
    ClearErrors
    ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\verify-managed-shared.ps1" -Path "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigScene.fuse" -Kind scene-fuse' $0
    ${If} $0 != 0
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig Scene Fuse was modified or is not a recognized CartoRig file. It was preserved and upgrade stopped." /SD IDOK
      Abort
    ${EndIf}
  ${EndIf}
  ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigWorldMap.fuse"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig WorldMap Fuse exists without CartoRig ownership. No files changed." /SD IDOK
      Abort
    ${EndIf}
    ClearErrors
    ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\verify-managed-shared.ps1" -Path "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigWorldMap.fuse" -Kind worldmap-fuse' $0
    ${If} $0 != 0
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig WorldMap Fuse was modified or is not a recognized CartoRig file. It was preserved and upgrade stopped." /SD IDOK
      Abort
    ${EndIf}
  ${EndIf}
  ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigCamera.fuse"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig Camera Fuse exists without CartoRig ownership. No files changed." /SD IDOK
      Abort
    ${EndIf}
    ClearErrors
    ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\verify-managed-shared.ps1" -Path "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigCamera.fuse" -Kind camera-fuse' $0
    ${If} $0 != 0
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig Camera Fuse was modified or is not a recognized CartoRig file. It was preserved and upgrade stopped." /SD IDOK
      Abort
    ${EndIf}
  ${EndIf}
  ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigRegion.fuse"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig Region Fuse exists without CartoRig ownership. No files changed." /SD IDOK
      Abort
    ${EndIf}
    ClearErrors
    ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\verify-managed-shared.ps1" -Path "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigRegion.fuse" -Kind region-fuse' $0
    ${If} $0 != 0
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig Region Fuse was modified or is not a recognized CartoRig file. It was preserved and upgrade stopped." /SD IDOK
      Abort
    ${EndIf}
  ${EndIf}
  ; Legacy Comp recovery is allowed only for an older managed installation.
  ; Verify active/backup/pending source bytes BEFORE any delete or rename.
  ${If} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
    ${IfNot} ${FileExists} "$R2\cartorig-dev.lua"
      ${If} ${FileExists} "$R0\cartorig-dev.lua"
        ClearErrors
        ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\verify-managed-comp-launcher.ps1" -Path "$R0\cartorig-dev.lua"' $0
        ${If} $0 != 0
          MessageBox MB_OK|MB_ICONSTOP "Comp\cartorig-dev.lua is not an exact recognized CartoRig 0.5.1/0.5.2 launcher. It was preserved and the upgrade was stopped." /SD IDOK
          Abort
        ${EndIf}
      ${EndIf}
      ${If} ${FileExists} "$R0\cartorig-dev.lua.backup"
        ClearErrors
        ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\verify-managed-comp-launcher.ps1" -Path "$R0\cartorig-dev.lua.backup"' $0
        ${If} $0 != 0
          MessageBox MB_OK|MB_ICONSTOP "Comp cartorig-dev.lua.backup is unrecognized. No legacy staging files were changed." /SD IDOK
          Abort
        ${EndIf}
      ${EndIf}
      ${If} ${FileExists} "$R0\cartorig-dev.lua.pending"
        ClearErrors
        ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\verify-managed-comp-launcher.ps1" -Path "$R0\cartorig-dev.lua.pending"' $0
        ${If} $0 != 0
          MessageBox MB_OK|MB_ICONSTOP "Comp cartorig-dev.lua.pending is unrecognized. No legacy staging files were changed." /SD IDOK
          Abort
        ${EndIf}
      ${EndIf}

      ${If} ${FileExists} "$R0\cartorig-dev.lua.backup"
        ${If} ${FileExists} "$R0\cartorig-dev.lua"
          ClearErrors
          Delete "$R0\cartorig-dev.lua.backup"
          IfErrors 0 +3
            MessageBox MB_OK|MB_ICONSTOP "Cannot clear verified stale backup; current legacy launcher preserved." /SD IDOK
            Abort
        ${Else}
          ClearErrors
          Rename "$R0\cartorig-dev.lua.backup" "$R0\cartorig-dev.lua"
          IfErrors 0 +3
            MessageBox MB_OK|MB_ICONSTOP "Could not restore verified interrupted update; backup preserved." /SD IDOK
            Abort
        ${EndIf}
      ${EndIf}
      ${If} ${FileExists} "$R0\cartorig-dev.lua.pending"
        ClearErrors
        Delete "$R0\cartorig-dev.lua.pending"
        IfErrors 0 +3
          MessageBox MB_OK|MB_ICONSTOP "Cannot clear verified staged file; active legacy launcher preserved." /SD IDOK
          Abort
      ${EndIf}
    ${EndIf}
  ${EndIf}
  ; Older diagnostics must not block activation of the current launcher.
  ; Their own uninstallers run only AFTER the new launcher is active.

  SetOutPath "$LOCALAPPDATA\CartoRig\App"
  File "/oname=graph_test.lua" "..\src\CartoRig\native_probe.lua"
  File "/oname=cleanup-verified-legacy.ps1" "..\support\cleanup-verified-legacy.ps1"
  File "/oname=verify-managed-shared.ps1" "..\support\verify-managed-shared.ps1"
  SetOutPath "$LOCALAPPDATA\CartoRig\App\lua"
  File "/oname=cartorig_scene_ui.lua" "..\host\cartorig-dev-scene.lua"
  SetOutPath "$LOCALAPPDATA\CartoRig\App"
  File "/oname=THIRD_PARTY_NOTICES.txt" "..\THIRD_PARTY_NOTICES"
  SetOutPath "$LOCALAPPDATA\CartoRig\App\lua\CartoRig"
  File "/oname=domain.lua" "..\src\CartoRig\domain.lua"
  File "/oname=geo.lua" "..\src\CartoRig\geo.lua"
  File "/oname=catalog.lua" "..\src\CartoRig\catalog.lua"
  File "/oname=blackmagic_api.lua" "..\src\CartoRig\blackmagic_api.lua"
  File "/oname=fusion_contract.lua" "..\src\CartoRig\fusion_contract.lua"
  File "/oname=node_factory.lua" "..\src\CartoRig\node_factory.lua"
  File "/oname=timeline_service.lua" "..\src\CartoRig\timeline_service.lua"
  SetOutPath "$LOCALAPPDATA\CartoRig\App\data"
  File "/oname=ne_50m_land.lua" "..\build\cartorig-data\ne_50m_land.lua"
  File "/oname=ne_50m_admin0_borders.lua" "..\build\cartorig-data\ne_50m_admin0_borders.lua"
  File "/oname=ne_catalog.tsv" "..\build\cartorig-data\ne_catalog.tsv"
  File "/oname=natural-earth-manifest.json" "..\build\cartorig-data\natural-earth-manifest.json"
  SetOutPath "$LOCALAPPDATA\CartoRig\App\data\regions"
  File /r "..\build\cartorig-data\regions\*"
  SetOutPath "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses"
  File "/oname=CartoRigScene.fuse" "..\fuses\CartoRigScene.fuse"
  File "/oname=CartoRigWorldMap.fuse" "..\fuses\CartoRigWorldMap.fuse"
  File "/oname=CartoRigCamera.fuse" "..\fuses\CartoRigCamera.fuse"
  File "/oname=CartoRigRegion.fuse" "..\fuses\CartoRigRegion.fuse"
  SetOutPath "$LOCALAPPDATA\CartoRig\App"
  File "/oname=README.txt" "..\docs\CARTORIG_PREVIEW_TEST.md"
  File "/oname=LICENSE.txt" "..\LICENSE"
  WriteUninstaller "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
  ; Files that the menu launcher requires must exist before any launcher rename.
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\lua\cartorig_scene_ui.lua"
    MessageBox MB_OK|MB_ICONSTOP "Scene UI missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\blackmagic_api.lua"
    MessageBox MB_OK|MB_ICONSTOP "Blackmagic API contract boundary missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\fusion_contract.lua"
    MessageBox MB_OK|MB_ICONSTOP "Fusion contract boundary missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\node_factory.lua"
    MessageBox MB_OK|MB_ICONSTOP "NodeFactory missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\data\ne_50m_land.lua"
    MessageBox MB_OK|MB_ICONSTOP "Offline map data missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\data\ne_50m_admin0_borders.lua"
    MessageBox MB_OK|MB_ICONSTOP "Offline map border data missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\data\ne_catalog.tsv"
    MessageBox MB_OK|MB_ICONSTOP "Offline geography catalog missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\data\natural-earth-manifest.json"
    MessageBox MB_OK|MB_ICONSTOP "Natural Earth manifest missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigScene.fuse"
    MessageBox MB_OK|MB_ICONSTOP "Scene Fuse missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigWorldMap.fuse"
    MessageBox MB_OK|MB_ICONSTOP "WorldMap Fuse missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigCamera.fuse"
    MessageBox MB_OK|MB_ICONSTOP "Camera Fuse missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigRegion.fuse"
    MessageBox MB_OK|MB_ICONSTOP "Region Fuse missing; the existing menu script was preserved." /SD IDOK
    Abort
  ${EndIf}

  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\timeline_service.lua"
    MessageBox MB_OK|MB_ICONSTOP "TimelineService missing; old entry preserved." /SD IDOK
    Abort
  ${EndIf}
  ; Activate the new Utility entry before retiring the previous Comp entry.
  ; This avoids disappearing from all menus during a failed migration.
  SetOutPath "$R2"
  ClearErrors
  File "/oname=cartorig-dev.lua.pending" "..\host\cartorig-dev-launcher.lua"
  IfErrors 0 +3
    MessageBox MB_OK|MB_ICONSTOP "Cannot stage Utility launcher; previous entry preserved." /SD IDOK
    Abort
  ${IfNot} ${FileExists} "$R2\cartorig-dev.lua.pending"
    MessageBox MB_OK|MB_ICONSTOP "Utility launcher staging failed; previous entry preserved." /SD IDOK
    Abort
  ${EndIf}
  ${If} ${FileExists} "$R2\cartorig-dev.lua"
    ClearErrors
    Rename "$R2\cartorig-dev.lua" "$R2\cartorig-dev.lua.backup"
    IfErrors 0 +3
      MessageBox MB_OK|MB_ICONSTOP "Cannot back up Utility launcher. Previous entry preserved." /SD IDOK
      Abort
  ${EndIf}
  ClearErrors
  Rename "$R2\cartorig-dev.lua.pending" "$R2\cartorig-dev.lua"
  IfErrors RestoreCartoRigUtility VerifyCartoRigUtility
RestoreCartoRigUtility:
  ${If} ${FileExists} "$R2\cartorig-dev.lua.backup"
    Rename "$R2\cartorig-dev.lua.backup" "$R2\cartorig-dev.lua"
  ${EndIf}
  MessageBox MB_OK|MB_ICONSTOP "Cannot activate Utility launcher; previous entry restored when possible." /SD IDOK
  Abort
VerifyCartoRigUtility:
  ${IfNot} ${FileExists} "$R2\cartorig-dev.lua"
    Goto RestoreCartoRigUtility
  ${EndIf}
  ; The Comp launcher is only retired once the Utility launcher is present.
  ${If} ${FileExists} "$R0\cartorig-dev.lua"
    ClearErrors
    Rename "$R0\cartorig-dev.lua" "$R0\cartorig-dev.lua.migrated-060"
    IfErrors MigrateCartoRigFailed MigrateCartoRigDone
MigrateCartoRigFailed:
    Delete "$R2\cartorig-dev.lua"
    Rename "$R2\cartorig-dev.lua.backup" "$R2\cartorig-dev.lua"
    MessageBox MB_OK|MB_ICONSTOP "Cannot retire old Comp entry. Utility installation rolled back." /SD IDOK
    Abort
MigrateCartoRigDone:
    ClearErrors
    Delete "$R0\cartorig-dev.lua.migrated-060"
    IfErrors 0 +3
      MessageBox MB_OK|MB_ICONSTOP "Verified legacy launcher migrated, but its temporary backup could not be removed." /SD IDOK
      Abort
  ${EndIf}
  Delete "$R2\cartorig-dev.lua.backup"
  ; Only remove historical diagnostic scripts when their exact SHA-256 matches
  ; an allowlisted CartoRig source file. Unknown content is never deleted.
  ClearErrors
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$LOCALAPPDATA\CartoRig\App\cleanup-verified-legacy.ps1" -CompPath "$R0" -Report "$LOCALAPPDATA\CartoRig\App\legacy-cleanup.txt"' $0
  ${If} $0 != 0
    StrCpy $R9 "Verified legacy cleanup returned error; launcher preserved, see legacy-cleanup.txt"
  ${Else}
    StrCpy $R9 "Verified legacy cleanup completed; see legacy-cleanup.txt"
  ${EndIf}
  SetOutPath "$LOCALAPPDATA\CartoRig\App"
  FileOpen $R1 "$LOCALAPPDATA\CartoRig\App\install-location.txt" w
  FileWrite $R1 "Launcher: $R2\cartorig-dev.lua$\r$\n"
  FileWrite $R1 "UI: $LOCALAPPDATA\CartoRig\App\lua\cartorig_scene_ui.lua$\r$\n"
  FileWrite $R1 "Version: 0.6.4$\r$\n"
  FileWrite $R1 "Build commit: ${BUILDSHA}$\r$\n"
  FileWrite $R1 "$R9$\r$\n"
  FileClose $R1
  FileOpen $R1 "$LOCALAPPDATA\CartoRig\App\build-info.txt" w
  FileWrite $R1 "version=0.6.4$\r$\n"
  FileWrite $R1 "commit=${BUILDSHA}$\r$\n"
  FileClose $R1
  ; Menu enumeration is NOT verified by this installer or the Windows Actions runner.
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "DisplayName" "cartorig-dev (Development Preview)"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "UninstallString" '"$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "DisplayVersion" "0.6.4"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "NoRepair" 1
SectionEnd

Section "Uninstall"
  ClearErrors
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -Command "if(Get-Process -Name Resolve -ErrorAction SilentlyContinue){exit 10}else{exit 0}"' $0
  ${If} $0 != 0
    MessageBox MB_OK|MB_ICONSTOP "DaVinci Resolve must be closed before uninstalling cartorig-dev. No files were removed." /SD IDOK
    Abort
  ${EndIf}
  StrCpy $INSTDIR "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts"
  ; Shared Resolve files are deleted only when their content is a known CartoRig
  ; version. A user-modified/replaced file is deliberately preserved.
  ${If} ${FileExists} "$LOCALAPPDATA\CartoRig\App\verify-managed-shared.ps1"
    ${If} ${FileExists} "$INSTDIR\Utility\cartorig-dev.lua"
      ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$LOCALAPPDATA\CartoRig\App\verify-managed-shared.ps1" -Path "$INSTDIR\Utility\cartorig-dev.lua" -Kind launcher' $0
      ${If} $0 == 0
        Delete "$INSTDIR\Utility\cartorig-dev.lua"
      ${EndIf}
    ${EndIf}
    ${If} ${FileExists} "$INSTDIR\Utility\cartorig-dev.lua.pending"
      ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$LOCALAPPDATA\CartoRig\App\verify-managed-shared.ps1" -Path "$INSTDIR\Utility\cartorig-dev.lua.pending" -Kind launcher' $0
      ${If} $0 == 0
        Delete "$INSTDIR\Utility\cartorig-dev.lua.pending"
      ${EndIf}
    ${EndIf}
    ${If} ${FileExists} "$INSTDIR\Utility\cartorig-dev.lua.backup"
      ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$LOCALAPPDATA\CartoRig\App\verify-managed-shared.ps1" -Path "$INSTDIR\Utility\cartorig-dev.lua.backup" -Kind launcher' $0
      ${If} $0 == 0
        Delete "$INSTDIR\Utility\cartorig-dev.lua.backup"
      ${EndIf}
    ${EndIf}
  ${EndIf}
  Delete "$LOCALAPPDATA\CartoRig\App\lua\cartorig_scene_ui.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\install-location.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\build-info.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\last-error.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\cleanup-verified-legacy.ps1"
  Delete "$LOCALAPPDATA\CartoRig\App\legacy-cleanup.txt"
  ${If} ${FileExists} "$LOCALAPPDATA\CartoRig\App\verify-managed-shared.ps1"
    ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigScene.fuse"
      ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$LOCALAPPDATA\CartoRig\App\verify-managed-shared.ps1" -Path "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigScene.fuse" -Kind scene-fuse' $0
      ${If} $0 == 0
        Delete "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigScene.fuse"
      ${EndIf}
    ${EndIf}
    ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigWorldMap.fuse"
      ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$LOCALAPPDATA\CartoRig\App\verify-managed-shared.ps1" -Path "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigWorldMap.fuse" -Kind worldmap-fuse' $0
      ${If} $0 == 0
        Delete "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigWorldMap.fuse"
      ${EndIf}
    ${EndIf}
    ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigCamera.fuse"
      ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$LOCALAPPDATA\CartoRig\App\verify-managed-shared.ps1" -Path "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigCamera.fuse" -Kind camera-fuse' $0
      ${If} $0 == 0
        Delete "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigCamera.fuse"
      ${EndIf}
    ${EndIf}
    ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigRegion.fuse"
      ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$LOCALAPPDATA\CartoRig\App\verify-managed-shared.ps1" -Path "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigRegion.fuse" -Kind region-fuse' $0
      ${If} $0 == 0
        Delete "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigRegion.fuse"
      ${EndIf}
    ${EndIf}
  ${EndIf}
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\domain.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\geo.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\catalog.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\blackmagic_api.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\fusion_contract.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\node_factory.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\timeline_service.lua"
  RMDir "$LOCALAPPDATA\CartoRig\App\lua\CartoRig"
  RMDir "$LOCALAPPDATA\CartoRig\App\lua"
  Delete "$LOCALAPPDATA\CartoRig\App\data\ne_50m_land.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\data\ne_50m_admin0_borders.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\data\ne_catalog.tsv"
  Delete "$LOCALAPPDATA\CartoRig\App\data\natural-earth-manifest.json"
  RMDir /r "$LOCALAPPDATA\CartoRig\App\data\regions"
  RMDir "$LOCALAPPDATA\CartoRig\App\data"
  Delete "$LOCALAPPDATA\CartoRig\App\THIRD_PARTY_NOTICES.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\graph_test.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\README.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\LICENSE.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\verify-managed-shared.ps1"
  Delete "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
  RMDir "$LOCALAPPDATA\CartoRig\App"
  RMDir "$LOCALAPPDATA\CartoRig"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev"
  ; Never delete shared Scripts folders or editor projects.
SectionEnd
