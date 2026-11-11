!include "MUI2.nsh"
!include "LogicLib.nsh"
!ifndef OUTPUTFILE
  !define OUTPUTFILE "CartoRig-Preview-0.3-win64.exe"
!endif
Unicode true
Name "CartoRig"
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

Section "Install CartoRig preview"
  ; Only replace CartoRig.lua if a managed CartoRig uninstaller exists.
  ${If} ${FileExists} "$INSTDIR\Comp\CartoRig.lua"
    ${IfNot} ${FileExists} "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
      MessageBox MB_OK|MB_ICONSTOP "CartoRig.lua exists but is not a managed installation. No files were changed."
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
  File "/oname=README.txt" "..\docs\CARTORIG_PREVIEW_TEST.md"
  File "/oname=LICENSE.txt" "..\LICENSE"
  WriteUninstaller "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
  SetOutPath "$INSTDIR\Comp"
  File "/oname=CartoRig.lua" "..\host\CartoRig.lua"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRig" "DisplayName" "CartoRig (Development Preview)"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRig" "UninstallString" '"$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRig" "DisplayVersion" "0.3.0"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRig" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRig" "NoRepair" 1
SectionEnd

Section "Uninstall"
  StrCpy $INSTDIR "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts"
  Delete "$INSTDIR\Comp\CartoRig.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\graph_test.lua"
  Delete "$LOCALAPPDATA\CartoRig\App\README.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\LICENSE.txt"
  Delete "$LOCALAPPDATA\CartoRig\App\Uninstall-CartoRig.exe"
  RMDir "$LOCALAPPDATA\CartoRig\App"
  RMDir "$LOCALAPPDATA\CartoRig"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRig"
  ; Never delete shared Scripts folders or editor projects.
SectionEnd
