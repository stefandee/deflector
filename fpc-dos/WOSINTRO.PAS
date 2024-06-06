procedure WOSintro;
uses SbDSP;
begin
asm mov ax,$0c02
    int $21 end;
loadsound(soundpath+'aonoise.raw',10);
corection:=2;
pcxread(imgpath+'c_wings0.pcx',0,12937);
playsound(10);
repeat until keypressed;
FadeOut(3);
cls(0,vga);
freesound(10);
end;
