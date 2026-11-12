# Verify ownership of files installed into Resolve shared user directories.
# Hashing normalizes CRLF/CR to LF so source-control line endings do not affect ownership.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Path,
  [Parameter(Mandatory=$true)][ValidateSet('launcher','scene-fuse','worldmap-fuse','camera-fuse','region-fuse')][string]$Kind
)
$ErrorActionPreference='Stop'
$known=@{
  launcher=@(
    '6d1bd1fd52575bea31e73754f3408dbb0351d6089701690e6e82c95240a9b262', # 0.5.2-0.6.2
    'c088214364f1226508348ebe662ed310a253fd5606253ab211307d7c17a3672f'  # 0.6.3
  )
  'scene-fuse'=@(
    '17c28628c767353a7a558674f202371d325655bba5613e195b02fe603ab93759',
    '8925da789ac1d4775192fb93fcbebbca51f3b96c92a32ad2b8bf85a21e8c03a0'
  )
  'worldmap-fuse'=@(
    'e01a3e4c6823495612ccf11149a73f8f988e35ce1fa539028c8de1d06f6c9960',
    'bebdbb180e72781773c345c8d3a278cb64e48fbbb3ab3482e9fb161aa5ae4bdd',
    'cabdf542ebdf383559bb11ff381bc81a50a3272fbab3390d5a92763b193d1741',
    '4b0890527de45bc25d629ace405d3d50ecab1b72539827825daf1a6f340bcedf',
    '204e0aaf6e27bcf012b42428e6d2b0618f4417d75449f2a70fbf57702314a757' # Milestone A render geometry
  )
  'camera-fuse'=@(
    '617eaf8578fce3ac21f150eff6124c71070149995e3753cad082b2bde04f4cb3',
    '1c63278ea99b73e2dd1c97dcfdff713fdc9c39b8ad7966128d198955dd93799b' # Milestone A render geometry
  )
  'region-fuse'=@(
    '4fd67310e2dce94b36e47ad710b7bc8e82865b73dcc90ebb732f04c3d40951ed',
    'c726ddf7b6047e2ab4dda7b0914d2fce7b82f7723f035dbb613655b3fb4d913b',
    '254175b017de950354934412b5dd6cc9d79d850228f238232ab6440e629ca254' # Milestone A render geometry
  )
}
try {
  if(-not [IO.File]::Exists($Path)){ exit 3 }
  $text=[IO.File]::ReadAllText($Path)
  $normalized=$text.Replace("`r`n","`n").Replace("`r","`n")
  $bytes=[Text.UTF8Encoding]::new($false).GetBytes($normalized)
  $sha=[Security.Cryptography.SHA256]::Create()
  try { $hash=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
  if($known[$Kind] -contains $hash){ exit 0 }
  Write-Output ("UNRECOGNIZED_MANAGED_FILE kind="+$Kind+" sha256="+$hash+" path="+$Path)
  exit 2
} catch {
  Write-Output ("MANAGED_FILE_VERIFY_ERROR="+$_.Exception.Message)
  exit 4
}
