if not exist ./obj mkdir obj

ppcross8086 -Mtp -CX -XX -XP -WmHuge -Wtexe -FU./obj Deflecto.PAS
@if %ERRORLEVEL% GEQ 1 EXIT /B %ERRORLEVEL%

@rem launch this from MS-DOS, compatible/emulation/virtualization (DosBox, FreeDos, etc)