!include "MUI2.nsh"
!include "LogicLib.nsh"
!ifndef OUTPUTFILE
  !define OUTPUTFILE "cartorig-dev-0.5-win64.exe"
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
  ; Only replace CartoRig.lua if a managed CartoRig uninstaller exists.
  ${If} ${FileExists} "$INSTDIR\Comp\CartoRig.lua"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "CartoRig.lua exists but is not a managed installation. No files were changed."
      Abort
    ${EndIf}
  ${EndIf}
  ; The development entry must belong to our managed installation.
  ${If} ${FileExists} "$INSTDIR\Comp\cartorig-dev.lua"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "cartorig-dev.lua belongs to another installation. Nothing was changed."
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
  ; Upgrade the same program in place without multiplying Scripts entries.
  ${If} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
    ExecWait '"$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe" /S _?=$LOCALAPPDATA\CartoRig\App' $0
    ${If} $0 != 0
      MessageBox MB_OK|MB_ICONSTOP "Existing CartoRig uninstall failed (exit $0). Upgrade stopped."
      Abort
    ${EndIf}
  ${EndIf}
  ; One-time automatic migration: use the original installers' own uninstallers.
  ${If} ${FileExists} "$LOCALAPPDATA\CartoRig\HostProbe\Uninstall-HostProbe.exe"
    ExecWait '"$LOCALAPPDATA\CartoRig\HostProbe\Uninstall-HostProbe.exe" /S _?=$LOCALAPPDATA\CartoRig\HostProbe' $0
    ${If} $0 != 0
      MessageBox MB_OK|MB_ICONSTOP "Older CartoRig Host Probe uninstall failed. Upgrade stopped."
      Abort
    ${EndIf}
  ${EndIf}
  ${If} ${FileExists} "$LOCALAPPDATA\CartoRig\NativeIntegrationProbe\Uninstall-NativeIntegration.exe"
    ExecWait '"$LOCALAPPDATA\CartoRig\NativeIntegrationProbe\Uninstall-NativeIntegration.exe" /S _?=$LOCALAPPDATA\CartoRig\NativeIntegrationProbe' $0
    ${If} $0 != 0
      MessageBox MB_OK|MB_ICONSTOP "Older CartoRig Integration Probe uninstall failed. Upgrade stopped."
      Abort
    ${EndIf}
  ${EndIf}
  ; Unexpected leftover files are preserved rather than blindly removed.
  ${If} ${FileExists} "$INSTDIR\Comp\CartoRig Host Probe.lua"
    MessageBox MB_OK|MB_ICONSTOP "An unmanaged old CartoRig script remains. Upgrade stopped."
    Abort
  ${EndIf}
  ${If} ${FileExists} "$INSTDIR\Comp\CartoRig Native Integration Probe.lua"
    MessageBox MB_OK|MB_ICONSTOP "An unmanaged old CartoRig script remains. Upgrade stopped."
    Abort
  ${EndIf}
  ${If} ${FileExists} "$INSTDIR\Comp\CartoRigProbe\native_probe.lua"
    MessageBox MB_OK|MB_ICONSTOP "An unmanaged old CartoRig library remains. Upgrade stopped."
    Abort
  ${EndIf}

  SetOutPath "$LOCALAPPDATA\CartoRig\App"
  File "/oname=graph_test.lua" "..\src\CartoRig\native_probe.lua"
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
  SetOutPath "$INSTDIR\Comp"
  File "/oname=cartorig-dev.lua" "..\host\cartorig-dev-scene.lua"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "DisplayName" "cartorig-dev (Development Preview)"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "UninstallString" '"$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "DisplayVersion" "0.5.0"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev" "NoRepair" 1
SectionEnd

Section "Uninstall"
  StrCpy $INSTDIR "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts"
  Delete "$INSTDIR\Comp\cartorig-dev.lua"
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
