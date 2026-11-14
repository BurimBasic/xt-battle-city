@echo off
if not exist TANKS.COM goto missing
TANKS.COM
goto end
:missing
echo TANKS.COM not found. Check the run directory.
:end
echo.
echo DOSBox-X remains open for inspection. Type EXIT to close.
