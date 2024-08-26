@echo off
set pasta_plb=z_plb/

echo . 
echo Atualizando packages ....     usuario[%1], banco[%2], pasta[%3] 

cd %pasta_plb% 
sqlplus %1/%2@%3  @atu_pkg_banco.sql %1 %3 > atu_pkg_banco.log
find /I "erro" atu_pkg_banco.log >nul
if %errorlevel% equ 1 goto semerros
type atu_pkg_banco.log
echo.
echo ERRO compilando packages 
goto fim

:semerros
	echo OK
	goto fim 
  
:fim
del atu_pkg_banco.log >nul
if %4X neq NX pause
