program get_a_screen;

uses images,graphics;
var     f :file;
        b:byte absolute $a000:0;
        p :pointer;
        xl,yl:word;

procedure celload(fname:string);
var f:file;
    b:byte absolute $a000:0;
begin
assign(f,fname);
reset(f,1);
seek(f,32);
blockread(f,workpal,768);
setpal;
blockread(f,b,64000);
close(f);
end;

begin

vga256;
celload(DataPath('mainfrm.cel'));
{corection:=0;
pcxread('defsg.pcx',0,6052);}
assign(f,DataPath('mainfrm.pal'));
rewrite(f,1);
blockwrite(f,workpal,768);
close(f);

assign(f,DataPath('mainfrm.spr'));
rewrite(f,1);
xl:=320;
yl:=200;
blockwrite(f,xl,2);
blockwrite(f,yl,2);
blockwrite(f,b,64000);
close(f);
readln;

donevga256;
end.


