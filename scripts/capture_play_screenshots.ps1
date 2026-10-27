# Capture MetaStrip Play Store screenshots from a USB-connected Android phone.
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File scripts\capture_play_screenshots.ps1
# Output: %USERPROFILE%\Documents\metastrip-play-assets\raw\01-viewer.png ... 08-theme.png
param(
  [string]$OutDir = "$env:USERPROFILE\Documents\metastrip-play-assets\raw",
  [string]$Adb = "adb"
)
$ErrorActionPreference = "Stop"

if (-not (Get-Command $Adb -ErrorAction SilentlyContinue)) {
  $sdk = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
  if (Test-Path $sdk) { $Adb = $sdk } else { throw "adb tidak ditemukan. Install Android platform-tools atau isi -Adb <path>." }
}

$devices = & $Adb devices | Select-String "\tdevice$"
if ($devices.Count -ne 1) { & $Adb devices; throw "Harus ada tepat 1 device berstatus 'device' (cek kabel & izin USB debugging)." }
Write-Host "Device:" ($devices[0].ToString().Split("`t")[0]) (& $Adb shell getprop ro.product.model)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Simpan setting lama supaya bisa dipulihkan
$oldTouches = (& $Adb shell settings get system show_touches).Trim()
$oldPointer = (& $Adb shell settings get system pointer_location).Trim()

function Set-Demo {
  & $Adb shell settings put system show_touches 0 | Out-Null
  & $Adb shell settings put system pointer_location 0 | Out-Null
  & $Adb shell settings put global sysui_demo_allowed 1 | Out-Null
  $b = "am broadcast -a com.android.systemui.demo -e command"
  & $Adb shell "$b enter" | Out-Null
  & $Adb shell "$b clock -e hhmm 1000" | Out-Null
  & $Adb shell "$b battery -e level 100 -e plugged false" | Out-Null
  & $Adb shell "$b network -e wifi show -e level 4 -e mobile show -e datatype none -e level 4" | Out-Null
  & $Adb shell "$b notifications -e visible false" | Out-Null
  & $Adb shell "$b status -e volume hide -e bluetooth hide -e location hide -e alarm hide -e sync hide -e mute hide -e speakerphone hide" | Out-Null
}
function Restore {
  & $Adb shell am broadcast -a com.android.systemui.demo -e command exit | Out-Null
  if ($oldTouches -match '^\d+$') { & $Adb shell settings put system show_touches $oldTouches | Out-Null }
  if ($oldPointer -match '^\d+$') { & $Adb shell settings put system pointer_location $oldPointer | Out-Null }
}

$shots = @(
  @("01-viewer",     "Viewer berisi 4-6 file campuran (JPG, PDF, MP3, DOCX, PNG, ZIP)"),
  @("02-detail",     "Metadata Detail foto JPG dengan EXIF kamera + GPS"),
  @("03-selective",  "Metadata Detail dengan beberapa field DITANDAI (selective removal)"),
  @("04-remover",    "Remover: antrean file / FINAL CONFIRMATION"),
  @("05-processing", "Processing: STRIPPING METADATA saat progress berjalan"),
  @("06-result",     "Result: COPIES CREATED + daftar output _clean"),
  @("07-privacy",    "Onboarding: slide PRIVACY FIRST"),
  @("08-theme",      "Color Theme / Custom Theme Builder")
)

# Push file contoh (EXIF+GPS Tugu Pahlawan, PDF DocInfo, DOCX, MP3 ID3, PNG tEXt, ZIP) ke Download/MetaStrip-demo
$demo = Join-Path $PSScriptRoot "..\build\play-demo-files"
if (Test-Path $demo) {
  & $Adb shell mkdir -p /sdcard/Download/MetaStrip-demo | Out-Null
  Get-ChildItem $demo -File | ForEach-Object {
    & $Adb push $_.FullName "/sdcard/Download/MetaStrip-demo/$($_.Name)" | Out-Null
    & $Adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file:///sdcard/Download/MetaStrip-demo/$($_.Name)" | Out-Null
  }
  Write-Host "File contoh sudah ada di HP: Download/MetaStrip-demo (pilih dari sini saat Add Files)."
}

try {
  Set-Demo
  & $Adb shell monkey -p com.bariskode.metastrip -c android.intent.category.LAUNCHER 1 | Out-Null
  Write-Host "`nStatus bar sudah demo mode (10:00, baterai 100%), show taps dimatikan.`n"
  foreach ($s in $shots) {
    $name = $s[0]; $hint = $s[1]
    $ans = Read-Host "[$name] Buka layar: $hint`n  Enter = ambil, s = lewati, q = selesai"
    if ($ans -eq "q") { break }
    if ($ans -eq "s") { continue }
    Set-Demo   # pastikan demo mode tetap aktif
    Start-Sleep -Milliseconds 600
    & $Adb shell screencap -p /sdcard/__ms_shot.png
    & $Adb pull /sdcard/__ms_shot.png (Join-Path $OutDir "$name.png") | Out-Null
    & $Adb shell rm /sdcard/__ms_shot.png
    Write-Host "  -> tersimpan $OutDir\$name.png`n"
  }
} finally {
  Restore
  Write-Host "Demo mode dimatikan, setting show taps dipulihkan. Folder: $OutDir"
}
