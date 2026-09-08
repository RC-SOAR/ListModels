@echo off
setlocal
echo:  

:: ====== S E T T I N G S =======

:: ================= TX SELECTION
:: set "tx=tx15"
set "tx=gx15"
:: set "tx=tx16s"
:: set "tx=tx16smk3"
:: set "tx=x10"
:: set "tx=nv14"
:: set "tx=x9d"

:: ================= O/S selection


:: ===========  OS abd VERSION 
set "os=edgetx"        REM EdgeTX
:: set "version=2.10"
:: set "version=2.11"
set "version=2.12"
:: set "version=3.0" 

:: "os=opentx"       REM OpenTX
:: set "version=2.3" 
:: "version=2.2"


:: ================= FOLDER PATHS
set "src=D:\MikeDocuments\_GitProjects\ETX_OTX projects\ListModels\src" REM set the source folder for the widget files
set "dest=SCRIPTS\TOOLS" REM set the destination folder on the SD card for the widget files


:: ====== S E T T I N G S  E N D =======

if %tx% == tx15 set "res=c480x320"
if %tx% == gx15 set "res=c480x320"
if %tx% == tx16s set "res=c480x272"
if %tx% == x10 set "res=c480x272"
if %tx% == nv14 set "res=c320x480"
if %tx% == tx16smk3 set "res=c800x480"
if %tx% == x9d set "res=bw212x64"

:: set the folder path for the sim executable based on the version

echo: ___%os%___

if %os% == edgetx (
    set "simfile=C:\Program Files\EdgeTX\Companion %version%\simulator.exe"
    if %version% == 2.12 set "simfile=C:\Program Files (x86)\EdgeTX\Companion %version%\bin\simulator.exe"
    if %version% == 3.0 set "simfile=C:\Program Files\EdgeTX\Companion %version%\bin\simulator.exe"
) else (
    set "simfile=C:\Program Files (x86)\OpenTX\Companion %version%\simulator.exe"
)


if not exist "%simfile%" (
    echo Simulator executable not found: "%simfile%"
    pause
    exit /b 1
)

:: set the SD card path
if %os% == opentx (
    set "sdcard_path=D:\OneDrive\RC\__OpenTX\%version%\SDCard\%res%"
) else (
    set "sdcard_path=D:\OneDrive\RC\__EdgeTX\%version%\SDCard\%res%"
)

if not exist "%sdcard_path%" (
    echo SD card path does not exist: "%sdcard_path%"
    pause
    exit /b 1
)


:: copy widget files to the sim SD card
xcopy "%src%\" "%sdcard_path%\%dest%" /s /i /y
if errorlevel 1 (
    echo XCOPY failed!
    exit /b 1
) else (
    echo XCOPY succeeded.
)

if /i "%1"=="/c" goto done

set "radio=%os%-%tx%"
echo Sim executable: "%simfile%"
echo SD card path: "%sdcard_path%"
echo Starting %os% %version% sim with %radio% radio...
START "" "%simfile%" -r %radio% -w sd -s "%sdcard_path%"

:done