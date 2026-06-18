<#
  day-len-github.ps1
  Tu dong: kiem tra Git + GitHub CLI (gh) -> dang nhap GitHub -> tao repo -> push code.
  Khi push xong, GitHub Actions se tu build (job "iOS Build").

  Ban CHI can hoan tat man dang nhap GitHub hien ra (mo trinh duyet / nhap ma).
  CACH CHAY: bam doi  day-len-github.cmd  (cung thu muc).
#>
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

function Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# --- Git (bat buoc) ---
if (-not (Have git)) {
  Write-Host "Chua co Git. Cai Git for Windows (https://git-scm.com) roi chay lai." -ForegroundColor Red
  Read-Host "Enter de thoat"; exit 1
}

# --- GitHub CLI (gh) ---
if (-not (Have gh)) {
  Write-Host "Chua co GitHub CLI (gh)." -ForegroundColor Yellow
  if (Have winget) {
    $a = Read-Host "Cai gh bang winget bay gio? (Y/N)"
    if ($a -match '^[Yy]') {
      winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
      Write-Host ""
      Write-Host "==> Cai xong. HAY DONG cua so nay va CHAY LAI day-len-github.cmd" -ForegroundColor Green
      Write-Host "    (de Windows cap nhat duong dan tới gh)." -ForegroundColor Green
    }
  } else {
    Write-Host "Khong co winget. Tai gh tai: https://cli.github.com  roi chay lai."
  }
  Read-Host "Enter de thoat"; exit 0
}

# --- Dang nhap GitHub ---
gh auth status 1>$null 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Chua dang nhap GitHub. Lam theo huong dan dang nhap hien ra..." -ForegroundColor Yellow
  gh auth login
  gh auth status 1>$null 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Dang nhap chua hoan tat. Chay lai script sau khi dang nhap xong." -ForegroundColor Red
    Read-Host "Enter de thoat"; exit 1
  }
}
$who = (gh api user --jq .login 2>$null)
Write-Host "Da dang nhap GitHub: $who" -ForegroundColor Green
Write-Host ""

# --- Thong tin repo ---
$name = Read-Host "Ten repo (Enter = zalo-giam-sat-ios)"
if ([string]::IsNullOrWhiteSpace($name)) { $name = "zalo-giam-sat-ios" }

Write-Host ""
Write-Host "PUBLIC  : ai cung xem duoc code, NHUNG macOS CI MIEN PHI khong gioi han."  -ForegroundColor Gray
Write-Host "PRIVATE : code rieng tu, build macOS an vao quota mien phi (~200 phut/thang)." -ForegroundColor Gray
$vis = Read-Host "Chon public hay private? (Enter = public)"
if ($vis -match '^[Pp]') { $visFlag = '--private' } else { $visFlag = '--public' }  # go 'p...' = private

# Neu da tro origin tu lan truoc -> go ra de tao moi cho sach
$hasOrigin = (git -C "$repo" remote) -split "`n" | Where-Object { $_ -eq 'origin' }
if ($hasOrigin) { git -C "$repo" remote remove origin }

Write-Host ""
Write-Host "Tao repo '$name' ($visFlag) + push code..." -ForegroundColor Cyan
gh repo create $name $visFlag --source "$repo" --remote origin --push
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "Khong tao/push duoc (co the ten repo da ton tai)." -ForegroundColor Red
  Write-Host "Thu lai voi ten khac, hoac neu repo da co thi chay 2 lenh:" -ForegroundColor Yellow
  Write-Host "  git -C `"$repo`" remote add origin https://github.com/$who/$name.git"
  Write-Host "  git -C `"$repo`" push -u origin main"
  Read-Host "Enter de thoat"; exit 1
}

Write-Host ""
Write-Host "==> XONG! Code da len GitHub. Mo tab Actions de xem build:" -ForegroundColor Green
$url = "https://github.com/$who/$name/actions"
Write-Host "    $url"
try { Start-Process $url } catch {}
Read-Host "Enter de dong"
