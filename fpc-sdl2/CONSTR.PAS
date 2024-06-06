{ text level editor - obsolete }

program constr;
uses defgame,crt;
const editlevel = 2;
var f : file of gamearr;
    x,y : integer;
    edit : gamearr;
    key : char;
    cod,mov : byte;
    i,j : integer;

procedure afisare;
var i,j:integer;
begin
textcolor(15);
for i:=1 to 15 do for j:=1 to 32 do begin gotoxy(j*2,i);write(edit[i,j].id);end;
textcolor(4);
gotoxy(2*x,y);write(edit[y,x].id);
end;

begin
x:=10;y:=10;
assign(f,'levels.dat');reset(f);
seek(f,editlevel-1);read(f,edit);
{for i:=1 to 15 do for j:=1 to 32 do if edit[i,j].id=0 then edit[i,j].id:=7;}
for i:=1 to 15 do
    begin
         with edit[i,1] do
              begin
              id:=9;
              crt_move:=3;
              end;
         with edit[i,32] do
              begin
              id:=9;
              crt_move:=1;
              end;
    end;
for i:=1 to 32 do
    begin
         with edit[1,i] do
              begin
              id:=9;
              crt_move:=2;
              end;
         with edit[15,i] do
              begin
              id:=9;
              crt_move:=4;
              end;
    end;
with edit[1,1] do
     begin
     id:=8;
     crt_move:=2;
     end;
with edit[1,32] do
     begin
     id:=8;
     crt_move:=1;
     end;
with edit[15,32] do
     begin
     id:=8;
     crt_move:=3;
     end;
with edit[15,1] do
     begin
     id:=8;
     crt_move:=4;
     end;

clrscr;
repeAT

if keypressed then key:=readkey
              else key:=#0;
case key of
'o' : begin
     if x>1 then dec(x);
     afisare;
     end;
'p' : begin
     if x<32 then inc(x);
     afisare;
     end;
'q' : begin
     if y>1 then dec(y);
     afisare;
     end;
'z' : begin
     if y<15 then inc(y);
     afisare;
     end;
'2','a','s','d','f','g',
'h','j','k','5','6',
'w','e','r','t','y','u','i','x','9': begin
     case key of
     '2' :  begin cod:=2;mov:=random(7)+1;afisare;end;
     'a' : begin cod:=3;mov:=11; afisare;end;
     's' : begin cod:=3;mov:=12; afisare;end;
     'd' : begin cod:=3;mov:=13; afisare;end;
     'f' : begin cod:=3;mov:=14; afisare;end;
     'g' : begin cod:=3;mov:=15; afisare;end;
     'h' : begin cod:=3;mov:=16; afisare;end;
     'j' : begin cod:=3;mov:=17; afisare;end;
     'k' : begin cod:=3;mov:=18; afisare;end;{also base sprite frame}
     '5'  : begin cod:=5;mov:=random(4)+1;afisare;end;
     '6'  : begin cod:=6;mov:=1;afisare;end;
     {clturi}
     'w' : begin cod:=8;mov:=1;afisare;end;
     'e' : begin cod:=8;mov:=2;afisare;end;
     'r' : begin cod:=8;mov:=3;afisare;end;
     't' : begin cod:=8;mov:=4;afisare;end;
     {ziduri}
     'y' : begin cod:=9;mov:=1;afisare;end;
     'u' : begin cod:=9;mov:=2;afisare;end;
     'i' : begin cod:=9;mov:=3;afisare;end;
     'x' : begin cod:=9;mov:=4;afisare;end;
     '9' : begin cod:=10;mov:=1;afisare;end;

     end;
     edit[y,x].id:=cod;edit[y,x].crt_move:=mov;
     end;
end;
until key=#27;
seek(f,editlevel-1);
write(f,edit);close(f);
end.

