# Builds the Windows release and packs it into one setup .exe (no extra tools needed:
# it uses the .NET Framework compiler that ships with Windows).
#
# Usage (from the project root):
#   powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
# Add -Password <text> to skip the prompt.
# Add -CertPath <file.pfx> -CertPassword <text> to code-sign the app and the installer
# (needed so Windows Smart App Control / SmartScreen accept it; the certificate must come
# from a publicly trusted CA).
# Add -SkipBuild to reuse the existing build\windows\x64\runner\Release folder.
param(
    [switch]$SkipBuild,
    # Password the installer will ask for. Prompted when omitted.
    [string]$Password,
    [string]$CertPath,
    [string]$CertPassword
)
$ErrorActionPreference = 'Stop'
if (-not $Password) { $Password = Read-Host 'Installer password' }
if ($Password.Length -lt 6) { throw 'Use a password of at least 6 characters' }

function Sign-File($file) {
    if (-not $CertPath) { return }
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $CertPassword)
    $r = Set-AuthenticodeSignature -FilePath $file -Certificate $cert -HashAlgorithm SHA256 -TimestampServer 'http://timestamp.digicert.com'
    if ($r.Status -ne 'Valid') { throw "Signing $file failed: $($r.Status) $($r.StatusMessage)" }
    Write-Host "Signed $file"
}

$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$version = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*([\d\.]+)').Matches[0].Groups[1].Value)
$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$stage = Join-Path $root 'build\installer_stage'
$outDir = Join-Path $root 'release\windows'
$setupExe = Join-Path $outDir "CG_Biometric_Setup_$version.exe"
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "csc.exe not found at $csc" }

if (-not $SkipBuild) {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
}
if (-not (Test-Path (Join-Path $releaseDir 'cg_biometric.exe'))) { throw "Release build not found in $releaseDir" }

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage, $outDir -Force | Out-Null

# App payload = release output + the Visual C++ runtime (so no separate redistributable is needed).
$payload = Join-Path $stage 'payload'
Copy-Item $releaseDir $payload -Recurse
foreach ($dll in 'msvcp140.dll', 'msvcp140_1.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'concrt140.dll') {
    Copy-Item (Join-Path $env:WINDIR "System32\$dll") $payload -Force
}

Sign-File (Join-Path $payload 'cg_biometric.exe')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = Join-Path $stage 'app.zip'
[System.IO.Compression.ZipFile]::CreateFromDirectory($payload, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
Set-Content -Path (Join-Path $stage 'version.txt') -Value $version -Encoding ASCII

# Encrypt the payload: AES-256-CBC + HMAC-SHA256, keys from PBKDF2(password). Layout: salt|hmac|iv|data
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$salt = New-Object byte[] 16; $rng.GetBytes($salt)
$iv = New-Object byte[] 16; $rng.GetBytes($iv)
$kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $salt, 200000)
$keys = $kdf.GetBytes(64)
$encKey = [byte[]]$keys[0..31]; $macKey = [byte[]]$keys[32..63]
$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Key = $encKey; $aes.IV = $iv
$aes.Mode = 'CBC'; $aes.Padding = 'PKCS7'
$plain = [System.IO.File]::ReadAllBytes($zip)
$cipher = $aes.CreateEncryptor().TransformFinalBlock($plain, 0, $plain.Length)
$ivAndData = New-Object byte[] (16 + $cipher.Length)
[Array]::Copy($iv, 0, $ivAndData, 0, 16); [Array]::Copy($cipher, 0, $ivAndData, 16, $cipher.Length)
$hmac = New-Object System.Security.Cryptography.HMACSHA256(, $macKey)
$mac = $hmac.ComputeHash($ivAndData)
$enc = Join-Path $stage 'app.enc'
$out = New-Object byte[] (16 + 32 + $ivAndData.Length)
[Array]::Copy($salt, 0, $out, 0, 16); [Array]::Copy($mac, 0, $out, 16, 32)
[Array]::Copy($ivAndData, 0, $out, 48, $ivAndData.Length)
[System.IO.File]::WriteAllBytes($enc, $out)
Remove-Item $zip -Force

if (Test-Path $setupExe) { Remove-Item $setupExe -Force }
& $csc /nologo /target:winexe /optimize+ "/out:$setupExe" `
    "/win32icon:$root\windows\runner\resources\app_icon.ico" `
    "/resource:$enc,app.enc" "/resource:$stage\version.txt,version.txt" `
    /reference:System.Windows.Forms.dll /reference:System.Drawing.dll `
    /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll `
    /reference:Microsoft.CSharp.dll `
    "$PSScriptRoot\Setup.cs"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $setupExe)) { throw 'Compiling the installer failed' }

Sign-File $setupExe
$mb = [math]::Round((Get-Item $setupExe).Length / 1MB, 1)
Write-Host "Installer ready: $setupExe ($mb MB)"
