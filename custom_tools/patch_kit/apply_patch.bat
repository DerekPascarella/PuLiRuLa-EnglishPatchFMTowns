:: Pu-Li-Ru-La (FM Towns)
:: English Translation
::
:: Written by Derek Pascarella (ateam)

@echo off

setlocal DisableDelayedExpansion

:: Set terminal window size
mode con:cols=72 lines=39 >nul 2>&1
cls
title Pu-Li-Ru-La - English Translation

:: Welcome message
type tools\banner.txt
echo.
echo                        __________________________
echo                  __,--^| English Translation v1.0 ^|--,__
echo                    '--^|         FM Towns         ^|--'
echo                        ``````````````````````````
echo.
echo Initiating patching process...
echo.

:: Define paths.
set "original_folder=redump_original"
set "patched_folder_cue=disc_image_patched_cue_bin"
set "patched_folder_ccd=disc_image_patched_ccd_img_sub"
set "marty_folder_cue=disc_image_patched_marty_exp_ram_cue_bin"
set "marty_folder_ccd=disc_image_patched_marty_exp_ram_ccd_img_sub"
set "target_file=Pu-Li-Ru-La (Japan) (Track 01).bin"
set "patch_folder=xdelta"
set "patch_file=Pu-Li-Ru-La (English).xdelta"
set "marty_patch_file=Pu-Li-Ru-La (English + Marty Expanded RAM).xdelta"
set "tools_folder=tools"
set "xdelta_exe=xdelta.exe"

:: Perform sanity check.
echo Performing sanity check...
echo.

if not exist "%original_folder%" (
    echo Error: Folder "%original_folder%" does not exist.
    echo.
    goto End
)

if not exist "%original_folder%\%target_file%" (
    echo Error: File "%target_file%" does not exist in "%original_folder%" folder.
    echo.
    goto End
)

if not exist "%tools_folder%" (
    echo Error: Folder "%tools_folder%" does not exist.
    echo.
    goto End
)

if not exist "%tools_folder%\%xdelta_exe%" (
    echo Error: File "%xdelta_exe%" does not exist in "%tools_folder%" folder.
    echo.
    goto End
)

if not exist "%tools_folder%\cue-2-ccd.exe" (
    echo Error: File "cue-2-ccd.exe" does not exist in "%tools_folder%" folder.
    echo.
    goto End
)

if not exist "%patch_folder%\%patch_file%" (
    echo Error: File "%patch_file%" does not exist in "%patch_folder%" folder.
    echo.
    goto End
)

if not exist "%patch_folder%\%marty_patch_file%" (
    echo Error: File "%marty_patch_file%" does not exist in "%patch_folder%" folder.
    echo.
    goto End
)

:: Build regular version.
echo -- English Translation --
echo.
call :BuildImage "%patched_folder_cue%" "%patched_folder_ccd%" "%patch_file%"
if errorlevel 1 goto End

:: Build Marty expanded RAM version.
echo -- English Translation + Marty Expanded RAM --
echo.
call :BuildImage "%marty_folder_cue%" "%marty_folder_ccd%" "%marty_patch_file%"
if errorlevel 1 goto End

:: Completion message
echo Patching process completed successfully.
echo.
goto End

:BuildImage
set "patched_folder=%~1"
set "ccd_folder=%~2"
set "current_patch=%~3"

:: Clean up old files.
echo Cleaning up old files....
echo.
del /q "%patched_folder%\*" > nul 2>&1
del /q "%ccd_folder%\*" > nul 2>&1

:: Copy original disc image to patched folder.
echo Copying all files from "%original_folder%" to
echo "%patched_folder%"...
echo.

xcopy "%original_folder%\*" "%patched_folder%\" /S /I /Y > nul 2>&1
if errorlevel 1 (
	echo Error: Failed to copy files to "%patched_folder%" folder.
	echo.
	exit /b 1
)

echo Files copied successfully.
echo.

:: Apply XDelta patch.
echo Applying patch...
echo.

"%tools_folder%\%xdelta_exe%" -f -d -s "%original_folder%\%target_file%" "%patch_folder%\%current_patch%" "%patched_folder%\%target_file%" > nul 2>&1
if errorlevel 1 (
	echo Error: Failed to apply the XDelta patch.
	echo.
	exit /b 1
)

echo Patch applied successfully.
echo.

:: CUE/BIN completion message.
echo Patched CUE/BIN disc image is located in the
echo "%patched_folder%" folder.
echo.

:: Generate CCD/IMG/SUB formatted disc image
echo Creating CCD/IMG/SUB version of patched disc image...
echo.

:: Create output folder
if not exist "%ccd_folder%" (
    mkdir "%ccd_folder%"
)

:: Run cue-2-ccd.exe on the patched disc image.
for %%F in ("%patched_folder%\*.cue") do (
    "%tools_folder%\cue-2-ccd.exe" "%%~fF" "%ccd_folder%" >nul
    if errorlevel 1 (
        echo ERROR: Failed to generate CCD/IMG/SUB disc image from %%F
        exit /b 1
    )
)

echo Patched CCD/IMG/SUB disc image is located in the
echo "%ccd_folder%" folder.
echo.
exit /b 0

:End
echo Press any key to close this window...
pause > nul

endlocal
