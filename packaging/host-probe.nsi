!include "MUI2.nsh"
!ifndef OUTPUTFILE
  !define OUTPUTFILE "CartoRig-HostProbe-0.1-win64.exe"
!endif

Unicode true
Name "CartoRig Milestone A Host Probe"
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

Section "Install Read-Only Host Probe"
  IfFileExists "$INSTDIR\Comp\CartoRig Host Probe.lua" 0 +3
  MessageBox MB_OK|MB_ICONSTOP "CartoRig Host Probe is already installed. Uninstall the previous probe before reinstalling. No files were overwritten."
  Abort
  SetOutPath "$INSTDIR\Comp"
  File "host\CartoRig Host Probe.lua"
  SetOutPath "$LOCALAPPDATA\CartoRig\HostProbe"
  File "/oname=README.txt" "docs\HOST_PROBE.md"
  File "/oname=LICENSE.txt" "..\\LICENSE"
  WriteUninstaller "$LOCALAPPDATA\CartoRig\HostProbe\Uninstall-HostProbe.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigHostProbe" "DisplayName" "CartoRig Host Probe (not product)"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigHostProbe" "UninstallString" '"$LOCALAPPDATA\CartoRig\HostProbe\Uninstall-HostProbe.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigHostProbe" "Publisher" "CartoRig open-source project"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigHostProbe" "DisplayVersion" "0.1.0"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigHostProbe" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigHostProbe" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\Comp\CartoRig Host Probe.lua"
  Delete "$LOCALAPPDATA\CartoRig\HostProbe\README.txt"
  Delete "$LOCALAPPDATA\CartoRig\HostProbe\LICENSE.txt"
  Delete "$LOCALAPPDATA\CartoRig\HostProbe\Uninstall-HostProbe.exe"
  RMDir "$LOCALAPPDATA\CartoRig\HostProbe"
  RMDir "$LOCALAPPDATA\CartoRig"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigHostProbe"
  ; Never remove shared Fusion\Scripts or Comp directories.
SectionEnd
