param(
  [string]$Root = 'C:\XT-Battle-City',
  [string]$GamePath = ''
)
$ErrorActionPreference = 'Stop'
if (-not $GamePath) { $GamePath = Join-Path $Root 'run\TANKS.COM' }
$exe = Join-Path $Root 'tools\dosbox-x\mingw-build\mingw-sdl2\dosbox-x.exe'
if (-not (Test-Path $exe) -or -not (Test-Path $GamePath)) { throw 'Emulator or game missing' }
$dir = Join-Path $Root ('audio-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID)
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item -Force $GamePath (Join-Path $dir 'TANKS.COM')
$batch = @'
@echo off
TANKS.COM /AUDIO
if errorlevel 1 goto speaker
echo OPL2>RESULT.OUT
goto done
:speaker
echo SPEAKER>RESULT.OUT
:done
exit
'@
[IO.File]::WriteAllText((Join-Path $dir 'AUDIO.BAT'),$batch.Replace("`n","`r`n"),[Text.Encoding]::ASCII)
foreach ($mode in @('none','opl2')) {
    $expected = 'SPEAKER';$sbtype='none'
    if ($mode -eq 'opl2') { $expected = 'OPL2'; $sbtype = 'sb16' }
    $resultFile = Join-Path $dir 'RESULT.OUT'
    Remove-Item $resultFile -ErrorAction SilentlyContinue
    $arguments = @(
       '-defaultconf','-noconsole','-nogui',
       '-set','"machine=cga"','-set','"cputype=8086"',
       '-set',('"oplmode=' + $mode + '"'),
       '-set',('"sbtype=' + $sbtype + '"'),
       '-c',('"mount c ' + $dir + '"'),'-c','"c:"','-c','"AUDIO.BAT"'
    )
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -PassThru -Wait -WindowStyle Hidden -RedirectStandardError (Join-Path $dir ('dosbox-'+$mode+'.log'))
    $got='MISSING';if(Test-Path $resultFile){$got=(Get-Content $resultFile -Raw).Trim()}
    Write-Output ('AUDIO_MODE=' + $mode + ' DETECT=' + $got + ' EXPECT=' + $expected)
    if($p.ExitCode -ne 0 -or $got -ne $expected){throw ('OPL2 test failed in mode '+$mode)}
}
Write-Output 'AUDIO_TEST=PASS'
