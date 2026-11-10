!include "MUI2.nsh"
!ifndef OUTPUTFILE
  !define OUTPUTFILE "CartoRig-NativeIntegration-0.2-win64.exe"
!endif
Unicode true
Name "CartoRig Native Integration Probe 0.2 (diagnostic)"
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

Section "Install native API diagnostic (not product)"
  IfFileExists "$INSTDIR\Comp\CartoRig Native Integration Probe.lua" 0 +3
  MessageBox MB_OK|MB_ICONSTOP "Native Integration Probe already installed. Uninstall it first; no files overwritten."
  Abort
  IfFileExists "$INSTDIR\Comp\CartoRigProbe\native_probe.lua" 0 +3
  MessageBox MB_OK|MB_ICONSTOP "Native probe library already installed. Uninstall it first."
  Abort
  SetOutPath "$INSTDIR\Comp"
  File "/oname=CartoRig Native Integration Probe.lua" "..\host\CartoRig Native Integration Probe.lua"
  SetOutPath "$INSTDIR\Comp\CartoRigProbe"
  File "/oname=native_probe.lua" "..\src\CartoRig\native_probe.lua"
  SetOutPath "$LOCALAPPDATA\CartoRig\NativeIntegrationProbe"
  File "/oname=README.txt" "..\docs\NATIVE_INTEGRATION_TEST.md"
  File "/oname=LICENSE.txt" "..\LICENSE"
  WriteUninstaller "$LOCALAPPDATA\CartoRig\NativeIntegrationProbe\Uninstall-NativeIntegration.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigNativeIntegrationProbe" "DisplayName" "CartoRig Native Integration Probe 0.2"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigNativeIntegrationProbe" "UninstallString" '"$LOCALAPPDATA\CartoRig\NativeIntegrationProbe\Uninstall-NativeIntegration.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigNativeIntegrationProbe" "DisplayVersion" "0.2.0"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigNativeIntegrationProbe" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigNativeIntegrationProbe" "NoRepair" 1
SectionEnd

Section "Uninstall"
  StrCpy $INSTDIR "$APPDATA\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts"
  Delete "$INSTDIR\Comp\CartoRig Native Integration Probe.lua"
  Delete "$INSTDIR\Comp\CartoRigProbe\native_probe.lua"
  RMDir "$INSTDIR\Comp\CartoRigProbe"
  Delete "$LOCALAPPDATA\CartoRig\NativeIntegrationProbe\README.txt"
  Delete "$LOCALAPPDATA\CartoRig\NativeIntegrationProbe\LICENSE.txt"
  Delete "$LOCALAPPDATA\CartoRig\NativeIntegrationProbe\Uninstall-NativeIntegration.exe"
  RMDir "$LOCALAPPDATA\CartoRig\NativeIntegrationProbe"
  RMDir "$LOCALAPPDATA\CartoRig"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigNativeIntegrationProbe"
  ; Preserve all unrelated Resolve files and folders.
SectionEnd
