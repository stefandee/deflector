program get_sprites;

uses graph,crt,pcxr;
const xl=8;
      yl=8;
type buf=array[1..xl,1..yl] of byte;
     pbuf=^buf;
var  i,j,drv,drvm,x,y,size:integer;
     ch:char;
     f:file;
     p:pbuf;
     b:byte;
     adrx,adry,nr:word;
     xxl,yyl:word;
     strfile:string;

Begin

drv:=installuserdriver('vga256',nil);
initgraph(drv,drvm,'');
readpcx('dotty.pcx');
assign(f,'dotty.fnt');
rewrite(f,1);
new(p);
x:=100;
y:=100;
nr:=0;
setwritemode(xorput);
setcolor(255);
rectangle(x,y,x+xl,y+yl);
repeat
if keypressed then ch:=readkey
              else ch:=#0;

case ch of
#75 : begin
      rectangle(x,y,x+xl,y+yl);
      dec(x);
      rectangle(x,y,x+xl,y+yl);
      end;
#77 : begin
      rectangle(x,y,x+xl,y+yl);
      inc(x);
      rectangle(x,y,x+xl,y+yl);
      end;
#72 : begin
      rectangle(x,y,x+xl,y+yl);
      dec(y);
      rectangle(x,y,x+xl,y+yl);
      end;
#80 : begin
      rectangle(x,y,x+xl,y+yl);
      inc(y);
      rectangle(x,y,x+xl,y+yl);
      end;
#32 : begin
      for i:=y+1 to y+yl-1 do
          for j:=x+1 to x+xl-1 do
              begin
              b:=getpixel(j,i);
              blockwrite(f,b,1);
              end;
      end;
end;
until ch=#27;
close(f);
end.





