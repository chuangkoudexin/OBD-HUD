@echo off
rem 一键推送到 GitHub (需要在能访问 github.com 的电脑上运行)
cd /d D:\核对1\obd_hud
"C:\flutter\bin\mingit\cmd\git.exe" push -u origin master
echo exit code = %ERRORLEVEL%
pause
