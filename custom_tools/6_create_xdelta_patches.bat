@echo off
cd /d "%~dp0"

for %%F in ("input\fmt_redump\*(Track 01).bin") do set "original=%%F"
set "track=Pu-Li-Ru-La (Japan) (Track 01).bin"

if exist "output\patch" rd /s /q "output\patch"
xcopy "patch_kit" "output\patch\" /S /I /Y > nul
mkdir "output\patch\xdelta"
mkdir "output\patch\redump_original"
mkdir "output\patch\disc_image_patched_cue_bin"
mkdir "output\patch\disc_image_patched_ccd_img_sub"
mkdir "output\patch\disc_image_patched_marty_exp_ram_cue_bin"
mkdir "output\patch\disc_image_patched_marty_exp_ram_ccd_img_sub"
copy /Y "tools\xdelta.exe" "output\patch\tools\" > nul

tools\xdelta.exe -f -A -e -s "%original%" "output\disc_image_patched\%track%" "output\patch\xdelta\Pu-Li-Ru-La (English).xdelta"
tools\xdelta.exe -f -A -e -s "%original%" "output\disc_image_patched_marty_exp_ram\%track%" "output\patch\xdelta\Pu-Li-Ru-La (English + Marty Expanded RAM).xdelta"

echo.
echo Patch kit written to "output\patch".
echo.
pause
