# Only removes exact, verified CartoRig diagnostic scripts from historical builds.
# It never removes files merely because a name starts with CartoRig.
# Runs after the current cartorig-dev.lua has already been activated.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$CompPath,
  [Parameter(Mandatory=$true)][string]$Report
)
$ErrorActionPreference="Stop"
$known=@(
  @{Name="CartoRig Host Probe.lua"; Hashes=@(
    "7b0c6e8bb42676bd4d371eca208841b590b4bb7bb4002e124d6b94607a56c6c6",
    "ad76afb6e21dca644737dc78c4e575b50d08c861891f3c2254a10f749b8cd8fd"
  )},
  @{Name="CartoRig Native Integration Probe.lua"; Hashes=@(
    "a2974f5bcdd069e7005b3a441bec5b4848755d91bfc30bc969a6c65e35c49c56",
    "5c36e801842aeb29ca21c81b708dd9df812747908621ffb291495a477c0d9e8d"
  )},
  @{Name="CartoRig.lua"; Hashes=@(
    "cd7019a1a9476903bc1a1b19ae7ebb6015ca95c2e6c0ea2cbd9acf9c484e54ce",
    "4993ce6a589c5b763e5a0470975eac2431c7ad68ba10df3e7a427419df21fd5a"
  )},
  @{Name="CartoRigProbe\native_probe.lua"; Hashes=@(
    "612d8b0d53201d3ef7688771d8cc1a35d2bae5258077943b67d7ba1154900cae",
    "26858bf3fb0af3c3eff86b852902f13fa363"
  )}
)
$lines=New-Object System.Collections.Generic.List[string]
$lines.Add("CartoRig historical script cleanup (exact SHA-256 allowlist)")
$lines.Add("Only predefined previous script contents may be removed.")
$lines.Add("Active cartorig-dev.lua is NEVER eligible for deletion.")
$deleted=0
$unrecognized=0
$errors=0
foreach($item in $known){
  $path=Join-Path $CompPath $item.Name
  if(-not [IO.File]::Exists($path)){
    $lines.Add("NOT_PRESENT: "+$item.Name)
    continue
  }
  try{
    # NSIS is 32-bit and can launch PowerShell without the Get-FileHash cmdlet.
    # Compute via the .NET runtime present on supported Windows.
    $stream=[IO.File]::OpenRead($path)
    try {
      $hasher=[Security.Cryptography.SHA256]::Create()
      try {
        $sha=([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','').ToLowerInvariant()
      } finally { $hasher.Dispose() }
    } finally { $stream.Dispose() }
    if($item.Hashes -contains $sha){
      Remove-Item -LiteralPath $path -Force -ErrorAction Stop
      if([IO.File]::Exists($path)){
        throw "Delete did not remove the approved file"
      }
      $deleted++
      $lines.Add("REMOVED_VERIFIED: "+$item.Name)
    }else{
      $unrecognized++
      $lines.Add("PRESERVED_UNKNOWN: "+$item.Name+";SHA256="+$sha)
    }
  }catch{
    $errors++
    $lines.Add("CLEANUP_ERROR_PRESERVED: "+$item.Name+";ERROR="+$_.Exception.Message)
  }
}
$lines.Add("TOTAL_VERIFIED_REMOVED: $deleted")
$lines.Add("TOTAL_UNRECOGNIZED_PRESERVED: $unrecognized")
$lines.Add("TOTAL_CLEANUP_ERRORS: $errors")
$lines.Add("RESOLVE_MENU: NOT_RUN")
$dir=Split-Path -Parent $Report
if($dir -and -not (Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Force -Path $dir | Out-Null}
[IO.File]::WriteAllLines($Report,$lines,[Text.UTF8Encoding]::new($false))
if($errors -gt 0){exit 1}else{exit 0}
