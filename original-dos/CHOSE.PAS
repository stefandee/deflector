uses graphics;
var i:integer;
    sprfname : string;
begin
vga256;
loadpal('sprites.pal');setpal;
for i:=0 to 7 do
    begin
    str(i,sprfname);
    loadspr('spr'+sprfname+'.spr',i+1);
    putspr(i+1,i*10,10,normalput,vga);
    end;
readln;
end.

