param(
  [string]$Root = 'C:\XT-Battle-City',
  [string]$GamePath = '',
  [string]$OplMode = 'auto'
)
$ErrorActionPreference = 'Stop'
if (-not $GamePath) { $GamePath = Join-Path $Root 'run\TANKS.COM' }
$exe = Join-Path $Root 'tools\dosbox-x\mingw-build\mingw-sdl2\dosbox-x.exe'
if (-not (Test-Path $exe)) { throw 'DOSBox-X missing' }
if (-not (Test-Path $GamePath)) { throw 'TANKS.COM missing' }
$dir = Join-Path $Root ('test-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID)
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item -Force $GamePath (Join-Path $dir 'TANKS.COM')
$batch = @'
@echo off
TANKS.COM /TEST
if errorlevel 1 goto fail
echo PASS>RESULT.OUT
goto end
:fail
echo FAIL>RESULT.OUT
:end
exit
'@
[IO.File]::WriteAllText((Join-Path $dir 'TEST.BAT'), $batch.Replace("`n", "`r`n"), [Text.Encoding]::ASCII)
$arguments = @(
  '-defaultconf','-noconsole','-nogui',
  '-set','"machine=cga"','-set','"cputype=8086"',
  '-set',('"' + 'oplmode=' + $OplMode + '"'),
  '-c',('"' + 'mount c ' + $dir + '"'),
  '-c','"c:"','-c','"TEST.BAT"'
)
$p = Start-Process -FilePath $exe -ArgumentList $arguments -PassThru -Wait -WindowStyle Hidden -RedirectStandardError (Join-Path $dir 'dosbox.log')
$resultFile = Join-Path $dir 'RESULT.OUT'
$result = 'MISSING'
if (Test-Path $resultFile) { $result = (Get-Content $resultFile -Raw).Trim() }
Write-Output ('GAME_TEST=' + $result)
Write-Output ('DOSBOX_RC=' + $p.ExitCode)
Write-Output ('BINARY_SHA256=' + (Get-FileHash -Algorithm SHA256 $GamePath).Hash)
Write-Output ('TEST_DIR=' + $dir)
if ($p.ExitCode -ne 0 -or $result -ne 'PASS') { throw 'DOSBox-X game smoke test failed' }
