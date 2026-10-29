param(
    [string]$GodotPath = $env:GODOT_BIN,
    [switch]$WithGraphics
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($godotCommand) { $GodotPath = $godotCommand.Source }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Supply -GodotPath with the installed Godot 4.7.2 Standard console executable, or set GODOT_BIN.'
}
$logDirectory = Join-Path $projectRoot '.local'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$version = (& $GodotPath --version | Out-String).Trim()
if ($version -notmatch '^4\.7\.2\.stable') { throw "Expected Godot 4.7.2 Stable. Found: $version" }
Write-Output "Engine: $version"

function Invoke-ProjectCheck {
    param([string]$Name, [string[]]$EngineArguments, [string]$SuccessMarker = '')
    $logPath = Join-Path $logDirectory ($Name + '.log')
    $arguments = @('--path', $projectRoot, '--log-file', $logPath) + $EngineArguments
    $output = & $GodotPath @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | Set-Content -LiteralPath (Join-Path $logDirectory ($Name + '-console.log')) -Encoding utf8
    $log = Get-Content -Raw -LiteralPath $logPath
    # Godot can exit 0 after script errors, including errors inside awaited functions.
    if ($exitCode -ne 0 -or $log -match '(SCRIPT ERROR|SHADER ERROR|ERROR:|FAIL:)') {
        $output | Write-Output
        throw "$Name failed (exit $exitCode). See .local/$Name.log"
    }
    if ($SuccessMarker -and $log -notmatch [regex]::Escape($SuccessMarker)) {
        throw "$Name did not reach its completion marker. See .local/$Name.log"
    }
    Write-Output "PASSED: $Name (exit $exitCode)"
    $output | Select-String 'RIFTERMATH_.*RESULT|VISUAL_RENDERER|VISUAL_HITS|DRAWING_WITH_DASH|OS_MOUSE_CAPTURED' | ForEach-Object { $_.Line }
}

Invoke-ProjectCheck -Name 'import-final' -EngineArguments @('--headless', '--editor', '--quit')
Invoke-ProjectCheck -Name 'smoke-final' -EngineArguments @('--headless', '--quit-after', '120')
Invoke-ProjectCheck -Name 'integration-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/integration.gd') -SuccessMarker 'failures'
Invoke-ProjectCheck -Name 'expansion-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/expansion.gd') -SuccessMarker 'RIFTERMATH_EXPANSION_RESULT'
Invoke-ProjectCheck -Name 'battle-smoke' -EngineArguments @('--headless', '--fixed-fps', '120', 'res://scenes/battle.tscn', '--quit-after', '1200')
Invoke-ProjectCheck -Name 'live-combat-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/live_combat.gd') -SuccessMarker 'RIFTERMATH_LIVE_RESULT'
Invoke-ProjectCheck -Name 'advanced-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/advanced_rifts.gd') -SuccessMarker 'RIFTERMATH_ADVANCED_RESULT'
Invoke-ProjectCheck -Name 'atmosphere-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/atmosphere.gd') -SuccessMarker 'RIFTERMATH_ATMOSPHERE_RESULT'
Invoke-ProjectCheck -Name 'tactical-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/tactical_combat.gd') -SuccessMarker 'RIFTERMATH_TACTICAL_RESULT'
Invoke-ProjectCheck -Name 'archetypes-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/archetypes.gd') -SuccessMarker 'RIFTERMATH_ARCHETYPES_RESULT'
Invoke-ProjectCheck -Name 'vertical-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/verticality.gd') -SuccessMarker 'RIFTERMATH_VERTICAL_RESULT'
Invoke-ProjectCheck -Name 'celestial-audio-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/celestial_audio.gd') -SuccessMarker 'RIFTERMATH_CELESTIAL_AUDIO_RESULT'
Invoke-ProjectCheck -Name 'expedition-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/expedition.gd') -SuccessMarker 'RIFTERMATH_EXPEDITION_RESULT'
Invoke-ProjectCheck -Name 'pocket-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/spatial_pocket.gd') -SuccessMarker 'RIFTERMATH_POCKET_RESULT'
Invoke-ProjectCheck -Name 'save-library-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/save_library.gd') -SuccessMarker 'RIFTERMATH_SAVE_LIBRARY_RESULT'
Invoke-ProjectCheck -Name 'cartography-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/cartography.gd') -SuccessMarker 'RIFTERMATH_CARTOGRAPHY_RESULT'
Invoke-ProjectCheck -Name 'echo-contract-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/echo_contract.gd') -SuccessMarker 'RIFTERMATH_ECHO_CONTRACT_RESULT'
Invoke-ProjectCheck -Name 'perception-final' -EngineArguments @('--headless', '--fixed-fps', '120', '--script', 'res://tests/perception.gd') -SuccessMarker 'RIFTERMATH_PERCEPTION_RESULT'
# input_guard.gd is a Node helper loaded by visual tests, not a standalone SceneTree test.
if ($WithGraphics) {
    Invoke-ProjectCheck -Name 'visual-final' -EngineArguments @('--fixed-fps', '60', '--script', 'res://tests/visual_probe.gd') -SuccessMarker 'RIFTERMATH_VISUAL_RESULT'
    Invoke-ProjectCheck -Name 'expansion-visual-final' -EngineArguments @('--fixed-fps', '60', '--script', 'res://tests/expansion_visual.gd') -SuccessMarker 'RIFTERMATH_EXPANSION_VISUAL_RESULT'
    Invoke-ProjectCheck -Name 'live-visual-final' -EngineArguments @('--fixed-fps', '60', '--script', 'res://tests/live_visual.gd') -SuccessMarker 'RIFTERMATH_LIVE_VISUAL_RESULT'
    Invoke-ProjectCheck -Name 'advanced-visual-final' -EngineArguments @('--fixed-fps', '60', '--script', 'res://tests/advanced_visual.gd') -SuccessMarker 'RIFTERMATH_ADVANCED_VISUAL_RESULT'
    Invoke-ProjectCheck -Name 'atmosphere-visual-final' -EngineArguments @('--fixed-fps', '60', '--script', 'res://tests/atmosphere_visual.gd') -SuccessMarker 'RIFTERMATH_ATMOSPHERE_VISUAL_RESULT'
    Invoke-ProjectCheck -Name 'tactical-visual-final' -EngineArguments @('--fixed-fps', '60', '--script', 'res://tests/tactical_visual.gd') -SuccessMarker 'RIFTERMATH_TACTICAL_VISUAL_RESULT'
    Invoke-ProjectCheck -Name 'style-visual-final' -EngineArguments @('--fixed-fps', '60', '--script', 'res://tests/style_visual.gd') -SuccessMarker 'RIFTERMATH_STYLE_VISUAL_RESULT'
    Invoke-ProjectCheck -Name 'vertical-sky-visual-final' -EngineArguments @('--fixed-fps', '60', '--script', 'res://tests/vertical_sky_visual.gd') -SuccessMarker 'RIFTERMATH_VERTICAL_SKY_VISUAL_RESULT'
    Invoke-ProjectCheck -Name 'expedition-visual-final' -EngineArguments @('--fixed-fps', '60', '--script', 'res://tests/expedition_visual.gd') -SuccessMarker 'RIFTERMATH_EXPEDITION_VISUAL_RESULT'
    Invoke-ProjectCheck -Name 'pocket-visual-final' -EngineArguments @('--fixed-fps', '60', '--script', 'res://tests/pocket_visual.gd') -SuccessMarker 'RIFTERMATH_POCKET_VISUAL_RESULT'
}
