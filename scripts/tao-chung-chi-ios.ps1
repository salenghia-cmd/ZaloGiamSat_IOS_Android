<#
  tao-chung-chi-ios.ps1
  Chuan bi chu ky de CI (GitHub Actions) xuat .ipa:
    - Tao khoa rieng (ios.key) + yeu cau ky (ios.csr)
    - Sau khi ban tai .cer + .mobileprovision tu developer.apple.com ve -> gop thanh cert.p12
    - Ma hoa base64 + tong hop danh sach Secret de dan vao GitHub
  Chay lai nhieu lan cung duoc — script tu nhan biet dang o buoc nao.

  CACH CHAY: bam doi file  tao-chung-chi-ios.cmd  (cung thu muc),
             hoac chuot phai file .ps1 -> Run with PowerShell.
#>
[CmdletBinding()]
param(
  [string]$Email,
  [string]$Name,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
# Tranh MSYS (openssl cua Git for Windows) tu y doi "/CN=..." thanh duong dan.
$env:MSYS2_ARG_CONV_EXCL = '*'

function Find-OpenSSL {
  $c = Get-Command openssl -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  foreach ($p in @("C:\Program Files\Git\usr\bin\openssl.exe",
                   "C:\Program Files\Git\mingw64\bin\openssl.exe")) {
    if (Test-Path $p) { return $p }
  }
  return $null
}

$openssl = Find-OpenSSL
if (-not $openssl) {
  Write-Host "Khong tim thay OpenSSL." -ForegroundColor Red
  Write-Host "Cai 1 trong 2 cach roi chay lai:"
  Write-Host "  - winget install ShiningLight.OpenSSL.Light"
  Write-Host "  - Hoac cai Git for Windows (da kem openssl)."
  Read-Host "Enter de thoat"; exit 1
}

function RunSSL([string[]]$Args) {
  & $openssl @Args
  if ($LASTEXITCODE -ne 0) { throw "OpenSSL loi (exit $LASTEXITCODE): $($Args -join ' ')" }
}

$repo    = Split-Path $PSScriptRoot -Parent
$signing = Join-Path $repo 'signing'
New-Item -ItemType Directory -Force -Path $signing | Out-Null

$verLine = (& $openssl version) -join ''
$isV3    = $verLine -match 'OpenSSL\s+3'
Write-Host "OpenSSL : $verLine" -ForegroundColor DarkGray
Write-Host "Thu muc : $signing" -ForegroundColor DarkGray
Write-Host ""

$key  = Join-Path $signing 'ios.key'
$csr  = Join-Path $signing 'ios.csr'
$pem  = Join-Path $signing 'ios.pem'
$p12  = Join-Path $signing 'cert.p12'
$certPwd = $null

# ---------- BUOC 1: tao khoa + CSR ----------
if ((-not (Test-Path $key)) -or $Force) {
  if (-not $Email) { $Email = Read-Host "Email cua ban (ghi vao CSR)" }
  if (-not $Name)  { $Name  = Read-Host "Ten cua ban (CN, vd: Nguyen Van A)" }
  RunSSL @('genrsa','-out',$key,'2048')
  RunSSL @('req','-new','-key',$key,'-out',$csr,'-subj',"/emailAddress=$Email/CN=$Name/C=VN")
  Write-Host ""
  Write-Host "==> DA TAO: ios.key + ios.csr" -ForegroundColor Green
  Write-Host "BUOC TIEP THEO (tren trinh duyet, can tai khoan Apple Developer):" -ForegroundColor Yellow
  Write-Host "  1) https://developer.apple.com/account/resources/certificates  -> '+'"
  Write-Host "     -> Apple Distribution (hoac iOS App Development)"
  Write-Host "     -> Choose File: $csr"
  Write-Host "     -> tai chung chi .cer ve, luu vao thu muc: $signing"
  Write-Host "  2) Identifiers -> tao App ID dung bundle id cua ban (vd com.tencuaban.zalogiamsat)"
  Write-Host "  3) Devices     -> them UDID iPhone cua ban"
  Write-Host "  4) Profiles    -> tao Provisioning (Ad Hoc) gan cert + device"
  Write-Host "                 -> tai file .mobileprovision ve thu muc: $signing"
  Write-Host ""
  Write-Host "Lam xong 1-4, CHAY LAI script nay de gop .p12 + base64." -ForegroundColor Yellow
  Read-Host "Enter de thoat"; exit 0
}

# ---------- BUOC 2: gop .cer + khoa -> cert.p12 ----------
if ((-not (Test-Path $p12)) -or $Force) {
  $cer = Get-ChildItem $signing -Filter *.cer -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $cer) {
    Write-Host "Chua thay file .cer trong $signing" -ForegroundColor Red
    Write-Host "Tai chung chi .cer tu developer.apple.com ve day, roi chay lai script."
    Read-Host "Enter de thoat"; exit 0
  }
  $certPwd = Read-Host "Dat mat khau cho file .p12 (nho de dan vao Secret DIST_CERT_PASSWORD)"
  RunSSL @('x509','-in',$cer.FullName,'-inform','DER','-out',$pem,'-outform','PEM')
  $args = @('pkcs12','-export','-inkey',$key,'-in',$pem,'-out',$p12,'-passout',"pass:$certPwd")
  if ($isV3) { $args += '-legacy' }   # de macOS security import doc duoc
  RunSSL $args
  Write-Host "==> DA TAO: cert.p12" -ForegroundColor Green
}

# ---------- BUOC 3: base64 + tong hop Secret ----------
$prof = Get-ChildItem $signing -Filter *.mobileprovision -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $prof) {
  Write-Host "Chua thay file .mobileprovision trong $signing" -ForegroundColor Red
  Write-Host "Tai Provisioning Profile tu developer.apple.com ve day, roi chay lai script."
  Read-Host "Enter de thoat"; exit 0
}

$p12b64  = [Convert]::ToBase64String([IO.File]::ReadAllBytes($p12))
$profb64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($prof.FullName))
[IO.File]::WriteAllText((Join-Path $signing 'DIST_CERT_P12_BASE64.txt'),     $p12b64)
[IO.File]::WriteAllText((Join-Path $signing 'PROVISION_PROFILE_BASE64.txt'), $profb64)

if (-not $certPwd) { $certPwd = Read-Host "Nhac lai mat khau .p12 (DIST_CERT_PASSWORD)" }
$teamId   = Read-Host "APPLE_TEAM_ID (10 ky tu, xem o Apple Developer -> Membership)"
$bundle   = Read-Host "APP_BUNDLE_ID (vd com.tencuaban.zalogiamsat)"
$profName = Read-Host "PROVISION_PROFILE_NAME (ten Profile dung nhu tren portal)"

$summary = @"
========== DAN 6 SECRET NAY VAO GITHUB ==========
Repo -> Settings -> Secrets and variables -> Actions -> New repository secret

APPLE_TEAM_ID            = $teamId
APP_BUNDLE_ID            = $bundle
PROVISION_PROFILE_NAME   = $profName
DIST_CERT_PASSWORD       = $certPwd
DIST_CERT_P12_BASE64     = (mo file DIST_CERT_P12_BASE64.txt, Ctrl+A Ctrl+C, dan vao)
PROVISION_PROFILE_BASE64 = (mo file PROVISION_PROFILE_BASE64.txt, Ctrl+A Ctrl+C, dan vao)
=================================================
LUU Y: thu muc 'signing' chua KHOA RIENG + CHUNG CHI -> da bi .gitignore.
       TUYET DOI khong commit / khong gui cho ai (gom ca minh).
"@
[IO.File]::WriteAllText((Join-Path $signing 'SECRETS-de-dan.txt'), $summary)
Write-Host ""
Write-Host $summary -ForegroundColor Cyan
Write-Host "Da luu: $signing\SECRETS-de-dan.txt + 2 file .b64.txt" -ForegroundColor Green
try { Invoke-Item $signing } catch {}
Read-Host "Xong. Enter de dong"
