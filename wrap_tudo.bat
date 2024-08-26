@echo off
set pasta_plb=z_plb
set filelog=wrap_tudo.log

echo .
echo Gerando PLBs (pasta : %pasta_plb%) .... 

echo %date% %time% > %filelog% 

rem  --------------------------------------------------------------------------------
rem                        WRAP dos Heads 
rem  --------------------------------------------------------------------------------
wrap iname=ctb/ctb_head.sql           oname=%pasta_plb%/ctb/ctb_head.plb         >> %filelog%     
wrap iname=agentc/agentc_head.sql     oname=%pasta_plb%/agentc/agentc_head.plb   >> %filelog%     

rem  --------------------------------------------------------------------------------
rem                        WRAP dos Bodys 
rem  --------------------------------------------------------------------------------
wrap iname=ctb/ctb.sql           oname=%pasta_plb%/ctb/ctb.plb                   >> %filelog%     
wrap iname=agentc/agentc.sql     oname=%pasta_plb%/agentc/agentc.plb             >> %filelog%     

del %filelog% >nul
echo OK

if %1X neq NX pause

