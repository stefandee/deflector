{ this is the game editor }

uses graphics,editgame,crt,keyboard,timer,GameDef;
var s : string;
{$R-}
begin
InitTimer(41);
InitKeyboard;
vga256;
initvscreen;
level:=0;
loadpal(DataPath('sprites.pal'));setpal;

repeat
str(level+1,s);
s:='Industrial level '+s;
outtext(160-length(s)*4,100,s,4,255,vga);
repeat until readkey=#13;
fadeout(4);
cls(0,vga);
loadpal(DataPath('sprites.pal'));setpal;
inc(level);
loadlevel(level);
startgame;
until exitcode<>2;{end level}

StopTimer;
StopKeyboard;
donevga256;
donevscreen;

end.