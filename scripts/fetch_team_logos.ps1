# Descarga los escudos de los equipos desde Weball, los achica a 96x96 PNG
# y los guarda en assets/logos/. Genera lib/utils/team_logos.g.dart con el índice.
#
# Por qué assets locales: cdn.weball.me no envía cabeceras CORS, así que
# Flutter web (CanvasKit) no puede dibujar esas imágenes con Image.network.
#
# Uso (desde la raíz del repo, en Windows):
#   powershell -ExecutionPolicy Bypass -File scripts/fetch_team_logos.ps1 [-PhaseId 1392] [-GroupId 2145]
# Volver a correr al cambiar de fase o cuando entren equipos nuevos.

param(
  [int]$PhaseId = 1392,
  [int]$GroupId = 2145,
  [int]$Size    = 96
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$base = 'https://api.weball.me/public-v2/tournament/566'
$uuid = '2d260df1-7986-49fd-95a2-fcb046e7a4fb'
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'assets\logos'
New-Item -ItemType Directory -Force $outDir | Out-Null

# Misma normalización que teamLogoKey() en Dart: mayúsculas, sin acentos, solo [A-Z0-9_]
function Get-LogoKey([string]$name) {
  $n = $name.Trim().ToUpperInvariant().Normalize([Text.NormalizationForm]::FormD)
  $n = -join ($n.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
  return (($n -replace '[^A-Z0-9]+', '_').Trim('_'))
}

# Recolectar club -> logo desde el fixture y la tabla
$clubs = @{}
$viz = Invoke-RestMethod "$base/phase/$PhaseId/visualizer?instanceUUID=$uuid"
foreach ($c in $viz.children) {
  foreach ($m in $c.matchesPlanning) {
    foreach ($ci in @($m.clubHome.clubInscription, $m.clubAway.clubInscription)) {
      if ($ci -and $ci.tableName -and $ci.logo) { $clubs[(Get-LogoKey $ci.tableName)] = $ci.logo }
    }
  }
}
$tables = Invoke-RestMethod "$base/phase/$PhaseId/group/$GroupId/clasification?instanceUUID=$uuid"
foreach ($t in $tables) {
  foreach ($p in $t.positions) {
    $ci = $p.club.clubInscription
    if ($ci -and $ci.tableName -and $ci.logo) { $clubs[(Get-LogoKey $ci.tableName)] = $ci.logo }
  }
}

$keys = @()
foreach ($key in ($clubs.Keys | Sort-Object)) {
  $tmp = [IO.Path]::GetTempFileName()
  try {
    Invoke-WebRequest -UseBasicParsing $clubs[$key] -OutFile $tmp
    $src = [Drawing.Image]::FromFile($tmp)
    # Encajar (contain) centrado sobre fondo transparente
    $scale = [Math]::Min($Size / $src.Width, $Size / $src.Height)
    $w = [int][Math]::Round($src.Width * $scale); $h = [int][Math]::Round($src.Height * $scale)
    $bmp = New-Object Drawing.Bitmap $Size, $Size
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([Drawing.Color]::Transparent)
    $g.DrawImage($src, [int](($Size - $w) / 2), [int](($Size - $h) / 2), $w, $h)
    $bmp.Save((Join-Path $outDir "$key.png"), [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $src.Dispose()
    $keys += $key
    Write-Host "  ok  $key"
  } catch {
    Write-Warning "  sin logo para $key : $($_.Exception.Message)"
  } finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
  }
}

# Índice Dart
$list = ($keys | ForEach-Object { "  '$_'," }) -join "`n"
$dart = @"
// GENERADO por scripts/fetch_team_logos.ps1 - no editar a mano.
// Escudos disponibles en assets/logos/<key>.png

const teamLogoKeys = <String>{
$list
};
"@
[IO.File]::WriteAllText((Join-Path $root 'lib\utils\team_logos.g.dart'), $dart + "`n", (New-Object Text.UTF8Encoding $false))
Write-Host "Listo: $($keys.Count) escudos en assets/logos/"
