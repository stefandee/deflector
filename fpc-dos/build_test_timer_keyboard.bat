if not exist ./obj mkdir obj

ppcross8086 -Mtp -CX -XX -XP -WmHuge -Wtexe -FU./obj TestTimerKeyboard.PAS
@if %ERRORLEVEL% GEQ 1 EXIT /B %ERRORLEVEL%

@rem launch this from MS-DOS, compatible or emulation (DosBox, FreeDos, etc)