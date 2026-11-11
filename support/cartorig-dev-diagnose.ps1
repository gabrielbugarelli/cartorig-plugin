# CartoRig diagnostic: read-only inspection in the Windows user running Resolve.
# Does NOT change Resolve or its files. Menu visibility still requires host validation.
[CmdletBinding()]
param(
  [string]$RoamingRoot=$env:APPDATA,
  [string]$LocalRoot=$env:LOCALAPPDATA,
  [string]$SharedRoot=$env:PROGRAMDATA,
  [string]$OutputPath=$(Join-Path $env:TEMP "cartorig-dev-install-check.txt"),
  [switch]$SkipProcessCheck
)
$ErrorActionPreference="Stop"
foreach($dir in @($RoamingRoot,$LocalRoot,$SharedRoot)){
  if([string]::IsNullOrWhiteSpace($dir)){throw "Missing Windows application directory"}
}
function Status($label,$path){
  $exists=[IO.File]::Exists($path)
  $size="N/A";$sha="N/A"
  if($exists){
    $size=[string]([IO.FileInfo]::new($path)).Length
    $sha=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  $display=$path.Replace($env:USERPROFILE,"%USERPROFILE%")
  return [pscustomobject]@{Name=$label;Present=$exists;Description="$label : $(if($exists){'PRESENT'}else{'MISSING'}); SIZE=$size; SHA256=$sha; PATH=$display"}
}
$userComp=Join-Path $RoamingRoot 'Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\cartorig-dev.lua'
$userUtility=Join-Path $RoamingRoot 'Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\cartorig-dev.lua'
$sharedComp=Join-Path $SharedRoot 'Blackmagic Design\DaVinci Resolve\Fusion\Scripts\Comp\cartorig-dev.lua'
$sharedUtility=Join-Path $SharedRoot 'Blackmagic Design\DaVinci Resolve\Fusion\Scripts\Utility\cartorig-dev.lua'
$app=Join-Path $LocalRoot 'CartoRig\App'
$files=@(
  (Status "USER_COMP" $userComp),
  (Status "USER_UTILITY" $userUtility),
  (Status "SHARED_COMP" $sharedComp),
  (Status "SHARED_UTILITY" $sharedUtility),
  (Status "SCENE_UI" (Join-Path $app 'lua\cartorig_scene_ui.lua')),
  (Status "NODE_FACTORY" (Join-Path $app 'lua\CartoRig\node_factory.lua')),
  (Status "UNINSTALLER" (Join-Path $app 'Uninstall-CartoRig.exe')),
  (Status "INSTALL_RECORD" (Join-Path $app 'install-location.txt')),
  (Status "STARTUP_ERROR" (Join-Path $app 'last-error.txt')),
  (Status "LEGACY_CARTORIG_SCRIPT" (Join-Path $RoamingRoot 'Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\CartoRig.lua')),
  (Status "LEGACY_HOST_PROBE" (Join-Path $RoamingRoot 'Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\CartoRig Host Probe.lua')),
  (Status "LEGACY_NATIVE_PROBE" (Join-Path $RoamingRoot 'Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\CartoRig Native Integration Probe.lua')),
  (Status "LEGACY_NATIVE_LIBRARY" (Join-Path $RoamingRoot 'Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\CartoRigProbe\native_probe.lua')),
  (Status "LAUNCHER_PENDING" (Join-Path $RoamingRoot 'Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\cartorig-dev.lua.pending')),
  (Status "LAUNCHER_BACKUP" (Join-Path $RoamingRoot 'Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\cartorig-dev.lua.backup'))
)
$primary=$files[0].Present;$ui=$files[4].Present
$other=$files[1].Present -or $files[2].Present -or $files[3].Present
$classification="FILES_PRESENT_MENU_VISIBILITY_NOT_VERIFIED"
if(!$primary){
  $classification=if($other){"OTHER_DEFAULT_SCRIPTS_LOCATION"}else{"SCRIPT_MISSING_IN_DEFAULT_DIRECTORIES"}
}elseif(!$ui){
  $classification="LAUNCHER_PRESENT_UI_MISSING"
}
$legacy=@($files | Where-Object { $_.Name -like 'LEGACY_*' -and $_.Present })
$staged=@($files | Where-Object { $_.Name -like 'LAUNCHER_*' -and $_.Present })
if (!$primary -and $legacy.Count -gt 0) {
  $classification="MISSING_LAUNCHER_LEGACY_FILES_CAN_BLOCK_INSTALLER"
} elseif (!$primary -and $staged.Count -gt 0) {
  $classification="MISSING_LAUNCHER_STAGING_RESIDUE"
}
$processStatus="NOT_CHECKED"
if(!$SkipProcessCheck){
  try{
    $running=@(Get-CimInstance Win32_Process -Filter "Name='Resolve.exe'" -ErrorAction Stop)
    if($running.Count -eq 0){$processStatus="RESOLVE_NOT_RUNNING"}
    else{
      $same=0;$otherUser=0;$unknown=0
      foreach($process in $running){
        try{
          $owner=Invoke-CimMethod -InputObject $process -MethodName GetOwner -ErrorAction Stop
          if($owner.ReturnValue -ne 0){$unknown++}
          elseif($owner.User -ieq $env:USERNAME){$same++}
          else{$otherUser++}
        }catch{$unknown++}
      }
      $processStatus="RUNNING=$($running.Count);SAME_USER=$same;DIFFERENT_USER=$otherUser;UNKNOWN=$unknown"
      if($otherUser -gt 0){$classification="RESOLVE_DIFFERENT_WINDOWS_USER"}
    }
  }catch{$processStatus="RESOLVE_PROCESS_INSPECTION_UNAVAILABLE"}
}
$registryStatus="MISSING"
try{
  $key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\CartoRigDev"
  if(Test-Path -LiteralPath $key){
    $v=Get-ItemProperty -LiteralPath $key -Name DisplayVersion -ErrorAction SilentlyContinue
    $registryStatus=if($v){"PRESENT;VERSION=$($v.DisplayVersion)"}else{"PRESENT"}
  }
}catch{$registryStatus="UNAVAILABLE"}
$lines=@(
  "cartorig-dev install visibility check (read-only)",
  "TIME_UTC: $([datetime]::UtcNow.ToString('s'))Z",
  "DIAGNOSIS: $classification",
  "RESOLVE_PROCESS: $processStatus",
  "REGISTRY_CURRENT_USER: $registryStatus",
  "APPDATA: $($RoamingRoot.Replace($env:USERPROFILE,'%USERPROFILE%'))",
  "LOCALAPPDATA: $($LocalRoot.Replace($env:USERPROFILE,'%USERPROFILE%'))"
)
foreach($f in $files){$lines+= $f.Description}
$lines+="LIVE_RESOLVE_MENU: NOT_RUN"
$lines+="FILES_CHANGED: NONE (except this report in Windows TEMP)"
$folder=Split-Path -Parent $OutputPath
if($folder -and !(Test-Path -LiteralPath $folder)){New-Item -ItemType Directory -Force -Path $folder | Out-Null}
[IO.File]::WriteAllLines($OutputPath,$lines,[Text.UTF8Encoding]::new($false))
Write-Output "Report: $OutputPath"
Write-Output "Diagnosis: $classification"
