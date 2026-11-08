# XT Battle City /TEST integration for DOSBox-X (Windows PowerShell 5.1+).
# Uses the real DOS COM executable, never interprets emulator RC as game RC.
param(
    [string]$Root = 'C:\XT-Battle-City',
    [string]$DosboxPath = '',
    [string]$GamePath = ''
)
$ErrorActionPreference = 'Stop'
if (-not $DosboxPath) {
    $DosboxPath = Join-Path $Root 'tools\dosbox-x\mingw-build\mingw-sdl2\dosbox-x.exe'
}
if (-not $GamePath) {
    $GamePath = Join-Path $Root 'run\TANKS.COM'
}
if (-not (Test-Path $DosboxPath)) { throw "DOSBox-X missing: $DosboxPath" }
if (-not (Test-Path $GamePath)) { throw "DOS game missing: $GamePath" }
$dir = Join-Path $Root ('test-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $dir -Force | Out-Null
Copy-Item -Path $GamePath -Destination (Join-Path $dir 'TANKS.COM')
$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add('@echo off')
$lines.Add('TANKS.COM /TEST')
for ($n=40; $n -ge 1; $n--) { $lines.Add("if errorlevel $n goto fail$n") }
$lines.Add('echo PASS>RESULT.OUT')
$lines.Add('goto finished')
for ($n=40; $n -ge 1; $n--) {
    $lines.Add(":fail$n")
    $lines.Add("echo FAIL$n>RESULT.OUT")
    $lines.Add('goto finished')
}
$lines.Add(':finished')
$lines.Add('exit')
[IO.File]::WriteAllText((Join-Path $dir 'TEST.BAT'),
    ($lines -join "`r`n")+"`r`n", [Text.Encoding]::ASCII)
$dosDir = $dir.Replace('"','')
$cmds = @('-defaultconf','-noconsole','-nogui','-set','"machine=cga"',
          '-set','"cputype=8086"',
          '-c',('"mount c '+$dosDir+'"'),'-c','"c:"','-c','"TEST.BAT"')
$p = Start-Process -FilePath $DosboxPath -ArgumentList $cmds -Wait -PassThru -WindowStyle Hidden `
    -RedirectStandardError (Join-Path $dir 'DOSBOX.log')
$resultFile = Join-Path $dir 'RESULT.OUT'
if (-not (Test-Path $resultFile)) { throw "No DOS result sentinel; inspect $dir\DOSBOX.log" }
$result = (Get-Content $resultFile -Raw).Trim()
Write-Output "GAME_TEST=$result"
Write-Output "DOSBOX_RC=$($p.ExitCode)"
Write-Output "BINARY_SHA256=$((Get-FileHash (Join-Path $dir 'TANKS.COM') -Algorithm SHA256).Hash)"
Write-Output "TEST_DIR=$dir"
if ($result -ne 'PASS') { throw "Game returned $result" }
