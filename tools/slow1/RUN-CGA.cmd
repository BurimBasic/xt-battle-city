@echo off
setlocal
set "ROOT=%~dp0"
set "EMU=%ROOT%tools\dosbox-x\mingw-build\mingw-sdl2\dosbox-x.exe"
set "GAME=%ROOT%run"
if not exist "%EMU%" (
 echo ERROR: DOSBox-X not found: "%EMU%"
 pause
 exit /b 1
)
if not exist "%GAME%\TANKS.COM" (
 echo ERROR: TANKS.COM not found in run folder.
 pause
 exit /b 1
)
echo TANKS v0.33 - CGA 320x200 - Intel 8086 - AdLib/OPL2
echo Starting from "%GAME%"
echo ESC exits game, M mutes sounds.
"%EMU%" -defaultconf -set "machine=cga" -set "cputype=8086" -set "cycles=fixed 1000" -set "sbtype=sb16" -set "oplmode=opl2" -set "output=surface" -set "captures=%ROOT%captures" -c "mount c %GAME%" -c "c:" -c "GO.BAT"
endlocal
