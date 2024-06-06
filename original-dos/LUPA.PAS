program Deflector;
{$M 32767,0,150000}
uses Graphics, Crt;

const step=4;
      raza=30;
      p=pi/180;

var f     : file;
    cx,cy : integer;
    dx,dy : integer;
    x,y   : word;
    stepx,stepy : integer;
    i,j   : integer;
    gt    : integer;
    spotx,spoty,sspotx : integer;
    hashtable : array[0..255,1..10] of byte;
    index:integer;
    ang : integer;

var
    dev,mix,stat,pro,loop : integer;
    md : string;

{$L MOD-obj.OBJ} 	        { Link in Object file }
{$F+} 				{ force calls to be 'far'}
procedure modvolume(v1,v2,v3,v4:integer); external ; {Can do while playing}
procedure moddevice(var device:integer); external ;
procedure modsetup(var status:integer;device,mixspeed,pro,loop:integer;var str:string); external ;
procedure modstop; external ;
procedure modinit; external;
{$F-}


function SprColor(nr:byte;x,y:word):byte;
var s,o:word;
begin
with spr[nr] do
     begin
     s:=seg(pspr^);
     o:=ofs(pspr^);
     sprcolor:=mem[s:o+y*xl+x];
     end;
end;

procedure Lupa;
var i,j,k:integer;
    c : byte;
begin
        putspr(1,0,0,normalput,vaddr);
        for i:=-dx div 2 to dx div 2 do
            for j:=-dy div 2 to dy div 2 do
                if (i*i) shl 2+(j*j) shl 2<961 then
                begin
                    bar(cx+i*2,cy+j*2,cx+i*2+2,cy+j*2+2,sprcolor(1,cx+i,cy+j),vaddr);
                    putpixel(spotx+i,spoty+j,hashtable[sprcolor(1,spotx+i,spoty+j),1],vaddr);
                end;

end;

begin

vga256;
initvscreen;
cls(0,vga);

loadspr('mainfrm.spr',1);
loadpal('mainfrm.pal');Setpal;

dx:=30;dy:=30;cx:=160;cy:=30;gt:=90;
spotx:=160;spoty:=50;sspotx:=2;
ang:=0;
for i:=0 to 255 do
    begin
    index:=1;
    for j:=i to 255 do
        if (workpal[j,1] in [workpal[i,1]+3..workpal[i,1]+10]) and
           (workpal[j,2] in [workpal[i,2]+3..workpal[i,2]+10]) and
           (workpal[j,3] in [workpal[i,3]+3..workpal[i,3]+10]) then
           begin
           hashtable[i,index]:=j;
           inc(index);
           break;
           end;
   if index=1 then hashtable[i,1]:=i;
   end;

stepx:=-3;stepy:=2;
randomize;

  modinit;
  mix := 7000;   {use 5050 for fast gaming }
  pro := 0; {Leave at 0}
  loop :=4; {0 means mod will play anD stop}
  dev:=7;
  modvolume (255,255,255,255);    { Full volume }
  md:='jarre.mod';
  loop:=4;
  modsetup ( stat, dev, mix, pro, loop, md );


repeat
cy:=cy+stepy;cx:=cx+stepx;
if cx+raza>=319 then begin stepx:=-random(6)+2;stepy:=-random(6); end;
if cy+raza>=199 then begin stepx:=random(6)+2;stepy:=-random(6); end;
if cy-raza<=0 then begin stepx:=-random(6)+2;stepy:=random(6); end;
if cx-raza<=0 then begin stepx:=random(6)+2;stepy:=random(6); end;
spotx:=spotx+sspotx;
case sspotx of
-2 : if spotx<80 then sspotx:=2;
2 : if spotx>240 then sspotx:=-2;
end;
inc(ang,6);if ang>360 then ang:=0;
Lupa;
line(round(spotx+15*sin(ang*p)),round(spoty+15*cos(ang*p)),319,199,215,vaddr);
line(round(spotx+15*sin((ang+180)*p)),round(spoty+15*cos((ang+180)*p)),319,199,215,vaddr);

Flip;
until keypressed;
modstop;
donevga256;
donevscreen;

end.



