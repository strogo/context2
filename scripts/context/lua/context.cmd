@echo off
setlocal
set ownpath=%~dp0%
texlua "%ownpath%mtxrun.lua" --script context %*
endlocal
