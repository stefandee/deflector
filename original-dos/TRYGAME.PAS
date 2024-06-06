uses graphics,editgame,crt;
var s : string;
{$R-}
begin
vga256;
initvscreen;
level:=0;
loadpal('sprites.pal');setpal;

repeat
str(level+1,s);
s:='Industrial level '+s;
outtext(160-length(s)*4,100,s,4,255,vga);
repeat until readkey=#13;
fadeout(4);
cls(0,vga);
loadpal('sprites.pal');setpal;
inc(level);
loadlevel(level);
startgame;
until exitcode<>2;{end level}
end.