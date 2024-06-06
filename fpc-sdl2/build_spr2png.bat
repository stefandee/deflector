if not exist ./obj mkdir obj

fpc -Mobjfpc -S2 -Sg -Sc -Sh -XS -Xt -FU./obj -Fu"../SDL2-for-Pascal/units" SPR2PNG.PAS
@if %ERRORLEVEL% GEQ 1 EXIT /B %ERRORLEVEL%

SPR2PNG.EXE