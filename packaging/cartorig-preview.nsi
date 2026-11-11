!include "MUI2.nsh"
!include "LogicLib.nsh"
!ifndef OUTPUTFILE
  !define OUTPUTFILE "cartorig-dev-0.5.2-win64.exe"
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
  StrCpy $R9 "Managed legacy cleanup: no error"
  ; The only development entry must be installed by a CartoRig-managed installer.
  ${If} ${FileExists} "$R0\cartorig-dev.lua"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "Existing cartorig-dev.lua is unmanaged; no files replaced."
      Abort
    ${EndIf}
  ${EndIf}
  ; Refuse to overwrite external Fuse tools: only the CartoRig managed
  ; uninstaller may own these filenames.
  ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigScene.fuse"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig Fuse installation exists. No files changed."
      Abort
    ${EndIf}
  ${EndIf}
  ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigWorldMap.fuse"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig WorldMap Fuse found. No files changed."
      Abort
    ${EndIf}
  ${EndIf}
  ${If} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigCamera.fuse"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "External CartoRig Camera Fuse found. No files changed."
      Abort
    ${EndIf}
  ${EndIf}
  ; Recover the launcher from a previous interrupted update.
  ${If} ${FileExists} "$R0\cartorig-dev.lua.backup"
    ${If} ${FileExists} "$R0\cartorig-dev.lua"
      ClearErrors
      Delete "$R0\cartorig-dev.lua.backup"
      IfErrors 0 +3
        MessageBox MB_OK|MB_ICONSTOP "Cannot clear stale backup; current launcher preserved."
        Abort
    ${Else}
      ClearErrors
      Rename "$R0\cartorig-dev.lua.backup" "$R0\cartorig-dev.lua"
      IfErrors 0 +3
        MessageBox MB_OK|MB_ICONSTOP "Could not restore interrupted update; backup preserved."
        Abort
    ${EndIf}
  ${EndIf}
  ${If} ${FileExists} "$R0\cartorig-dev.lua.pending"
    ClearErrors
    Delete "$R0\cartorig-dev.lua.pending"
    IfErrors 0 +3
      MessageBox MB_OK|MB_ICONSTOP "Cannot clear previous staged file; active launcher preserved."
      Abort
  ${EndIf}
  ; Older diagnostics must not block activation of the current launcher.
  ; Their own uninstallers run only AFTER the new launcher is active.

  SetOutPath "$LOCALAPPDATA\CartoRig\App"
  File "/oname=graph_test.lua" "..\src\CartoRig\native_probe.lua"
  File "/oname=cleanup-verified-legacy.ps1" "..\support\cleanup-verified-legacy.ps1"
  SetOutPath "$LOCALAPPDATA\CartoRig\App\lua"
  File "/oname=cartorig_scene_ui.lua" "..\host\cartorig-dev-scene.lua"
  SetOutPath "$LOCALAPPDATA\CartoRig\App"
  File "/oname=THIRD_PARTY_NOTICES.txt" "..\THIRD_PARTY_NOTICES"
  SetOutPath "$LOCALAPPDATA\CartoRig\App\lua\CartoRig"
  File "/oname=domain.lua" "..\src\CartoRig\domain.lua"
  File "/oname=geo.lua" "..\src\CartoRig\geo.lua"
  File "/oname=catalog.lua" "..\src\CartoRig\catalog.lua"
  File "/oname=node_factory.lua" "..\src\CartoRig\node_factory.lua"
  SetOutPath "$LOCALAPPDATA\CartoRig\App\data"
  File "/oname=ne_50m_land.lua" "..\data\ne_50m_land.lua"
  SetOutPath "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses"
  File "/oname=CartoRigScene.fuse" "..\fuses\CartoRigScene.fuse"
  File "/oname=CartoRigWorldMap.fuse" "..\fuses\CartoRigWorldMap.fuse"
  File "/oname=CartoRigCamera.fuse" "..\fuses\CartoRigCamera.fuse"
  SetOutPath "$LOCALAPPDATA\CartoRig\App"
  File "/oname=README.txt" "..\docs\CARTORIG_PREVIEW_TEST.md"
  File "/oname=LICENSE.txt" "..\LICENSE"
  WriteUninstaller "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
  ; Files that the menu launcher requires must exist before any launcher rename.
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\lua\cartorig_scene_ui.lua"
    MessageBox MB_OK|MB_ICONSTOP "Scene UI missing; the existing menu script was preserved."
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\node_factory.lua"
    MessageBox MB_OK|MB_ICONSTOP "NodeFactory missing; the existing menu script was preserved."
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\data\ne_50m_land.lua"
    MessageBox MB_OK|MB_ICONSTOP "Offline map data missing; the existing menu script was preserved."
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigScene.fuse"
    MessageBox MB_OK|MB_ICONSTOP "Scene Fuse missing; the existing menu script was preserved."
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigWorldMap.fuse"
    MessageBox MB_OK|MB_ICONSTOP "WorldMap Fuse missing; the existing menu script was preserved."
    Abort
  ${EndIf}
  ${IfNot} ${FileExists} "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigCamera.fuse"
    MessageBox MB_OK|MB_ICONSTOP "Camera Fuse missing; the existing menu script was preserved."
    Abort
  ${EndIf}

  ; Stage, verify and promote without a pre-upgrade uninstall.
  SetOutPath "$R0"
  ClearErrors
  File "/oname=cartorig-dev.lua.pending" "..\host\cartorig-dev-launcher.lua"
  IfErrors 0 +3
    MessageBox MB_OK|MB_ICONSTOP "Cannot write staged launcher; previous launcher preserved."
    Abort
  ${IfNot} ${FileExists} "$R0\cartorig-dev.lua.pending"
    MessageBox MB_OK|MB_ICONSTOP "Staged launcher missing; previous launcher preserved."
    Abort
  ${EndIf}
  ${If} ${FileExists} "$R0\cartorig-dev.lua"
    ClearErrors
    Rename "$R0\cartorig-dev.lua" "$R0\cartorig-dev.lua.backup"
    IfErrors 0 +3
      MessageBox MB_OK|MB_ICONSTOP "Cannot back up current launcher; upgrade aborted."
      Abort
  ${EndIf}
  ClearErrors
  Rename "$R0\cartorig-dev.lua.pending" "$R0\cartorig-dev.lua"
  IfErrors RestoreCartoRigLauncher VerifyCartoRigLauncher
RestoreCartoRigLauncher:
  ${If} ${FileExists} "$R0\cartorig-dev.lua.backup"
    Rename "$R0\cartorig-dev.lua.backup" "$R0\cartorig-dev.lua"
  ${EndIf}
  MessageBox MB_OK|MB_ICONSTOP "Cannot activate launcher; previous version restored when possible."
  Abort
VerifyCartoRigLauncher:
  ${IfNot} ${FileExists} "$R0\cartorig-dev.lua"
    Goto RestoreCartoRigLauncher
  ${EndIf}
  Delete "$R0\cartorig-dev.lua.backup"

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
  FileWrite $R1 "Launcher: $R0\cartorig-dev.lua$\r$\n"
  FileWrite $R1 "UI: $LOCALAPPDATA\CartoRig\App\lua\cartorig_scene_ui.lua$\r$\n"
  FileWrite $R1 "Version: 0.5.2$\r$\n"
  FileWrite $R1 "$R9$\r$\n"
  FileClose $R1
  ; Menu enumeration is NOT verified by this installer or the Windows Actions runner.
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "DisplayName" "cartorig-dev (Development Preview)"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "UninstallString" '"$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "DisplayVersion" "0.5.2"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "NoRepair" 1
SectionEnd

Section "Uninstall"
  StrCpy $INSTDIR "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts"
  Delete "$INSTDIR\Comp\cartorig-dev.lua"
  Delete "$INSTDIR\Comp\cartorig-dev.lua.pending"
  Delete "$INSTDIR\Comp\cartorig-dev.lua.backup"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\cartorig_scene_ui.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\install-location.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\last-error.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\cleanup-verified-legacy.ps1"
  Delete "$LOCALAPPDATA\CartoRig\App\legacy-cleanup.txt"
  Delete "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigScene.fuse"
  Delete "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigWorldMap.fuse"
  Delete "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\CartoRigCamera.fuse"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\domain.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\geo.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\catalog.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\lua\CartoRig\node_factory.lua"
  RMDir "$LOCALAPPDATA\CartoRig\App\lua\CartoRig"
  RMDir "$LOCALAPPDATA\CartoRig\App\lua"
  Delete "$LOCALAPPDATA\CartoRig\App\data\ne_50m_land.lua"
  RMDir "$LOCALAPPDATA\CartoRig\App\data"
  Delete "$LOCALAPPDATA\CartoRig\App\THIRD_PARTY_NOTICES.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\graph_test.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\README.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\LICENSE.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
  RMDir "$LOCALAPPDATA\CartoRig\App"
  RMDir "$LOCALAPPDATA\CartoRig"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev"
  ; Never delete shared Scripts folders or editor projects.
SectionEnd
