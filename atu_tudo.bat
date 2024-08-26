@echo off
start /wait /b cmd /c  wrap_tudo.bat N        
start /wait /b cmd /c  atu_pkg.bat %1 %2 %3 N 
pause