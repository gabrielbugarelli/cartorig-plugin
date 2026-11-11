# Verify ownership of a legacy Comp\cartorig-dev.lua before migration.
# Only exact historical CartoRig launcher source is accepted. Unknown/modified
# files are never renamed or deleted by the current installer.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Path)
$ErrorActionPreference='Stop'
$known=@(
  '997bd170c2b2a1ea921119c61ce53a5cee53bc1324ee715446c84cd96248ea4a', # 0.5.1 normalized LF
  '6d1bd1fd52575bea31e73754f3408dbb0351d6089701690e6e82c95240a9b262'  # 0.5.2 normalized LF
)
try {
  if(-not [IO.File]::Exists($Path)){ exit 3 }
  $text=[IO.File]::ReadAllText($Path)
  $normalized=$text.Replace("`r`n","`n").Replace("`r","`n")
  $bytes=[Text.UTF8Encoding]::new($false).GetBytes($normalized)
  $sha256=[Security.Cryptography.SHA256]::Create()
  try {
    $hash=([BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
  } finally { $sha256.Dispose() }
  if($known -contains $hash){ exit 0 }
  Write-Output ("UNRECOGNIZED_LEGACY_COMP_SHA256="+$hash)
  exit 2
} catch {
  Write-Output ("LEGACY_COMP_VERIFY_ERROR="+$_.Exception.Message)
  exit 4
}
