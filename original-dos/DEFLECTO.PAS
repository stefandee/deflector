program Deflector;
{$M 65520,0,250000}
uses Graphics, SbDsp, DefGame, Crt, Images, Dos;

type menu = record
          texte : array[1..10] of string;
          maxoption : byte;
          select    : array[1..10] of byte;
          id : byte;
          escape : byte;
          color : byte;
          end;

const step=4;
      raza=30;
      p=pi/180;
      main = 1;options = 3;quit = 4;what = 2;none = 0;
      ostart = 5;
      ckeys = 6 ; csound = 7;cvolume = 8;setvolume = 9;
      setsound = 10;

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
    clr : byte;
    option,whatmenu : byte;
    key : byte;
    menus : array[1..15] of menu;
    left , right : byte;
    volcnt : byte;
    slevel : string;
    temppal : paltype;


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

var
  Int1CSave : Pointer;
{$F+,S-,W-}
procedure TimerHandler; interrupt;
  begin
    { Timer ISR }
    {*** Refer to DDK and DPMI Specs for creating ISR's ***}
    DrawAllowed := true;
  end;
{$F-,S+}

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
        putspr(50,0,0,normalput,vaddr);
        for i:=-dx div 2 to dx div 2 do
            for j:=-dy div 2 to dy div 2 do
                if (i*i) shl 2+(j*j) shl 2<961 then
                begin
                    bar(cx+i*2,cy+j*2,cx+i*2+2,cy+j*2+2,sprcolor(50,cx+i,cy+j),vaddr);
                    putpixel(spotx+i,spoty+j,hashtable[sprcolor(50,spotx+i,spoty+j),1],vaddr);
                end;

end;

procedure InitMenus;
begin
with menus[main] do
     begin
     id := main;
     texte[1]:='START GAME';texte[2]:='OPTIONS';texte[3]:='QUIT';texte[4]:='?';
     maxoption:=4;
     select[1]:=ostart;select[2]:=options;select[3]:=quit;select[4]:=what;
     color := 81;
     escape:=none;
     end;
with menus[what] do
     begin
     id := what;
     texte[1]:='A WOS Production';texte[2]:='December 1995';
     texte[3]:='Coder\Music\Design\Graphics : Karg';
     texte[4]:='Title  : Traian Pop';
     maxoption:=4;
     color := 240;
     escape:=main;
     end;
with menus[csound] do
     begin
     texte[1]:='Sound Blaster';
     texte[2]:='PC Speaker';
     texte[3]:='DAC on LPT 1';
     texte[4]:='DAC on LPT 2';
     texte[5]:='Silence speaker';
     maxoption:=5;
     for i:=1 to maxoption do select[i]:=setsound;
     
     color:=81;
     escape:=options;
     end;
with menus[cvolume] do
     begin
     texte[1]:='Very high';
     texte[2]:='High';
     texte[3]:='Medium';
     texte[4]:='Low';
     texte[5]:='Off';
     maxoption:=5;
     for i:=1 to maxoption do select[i]:=setvolume;
     color:=81;
     escape:=options;
     end;

with menus[ckeys] do
     begin
     id:=ckeys;
     texte[1]:='Use keys';
     texte[2]:='Rotate left/right : O/P';
     texte[3]:='Move cursor : Arrows';
     texte[4]:='Change mirror : Enter';
     maxoption:=4;
     color:=240;
     escape:=options;
     end;

with menus[options] do
     begin
     id := options;
     texte[1]:='Keys';texte[2]:='Select sound';texte[3]:='Select volume(SB only)';
     select[1]:=ckeys;select[2]:=csound;select[3]:=cvolume;
     maxoption:=3;
     color:=81;
     escape:=main;
     end;

end;

procedure WOSintro;
begin
asm mov ax,$0c02
    int $21 end;
loadsound('sintro.1st',10);
corection:=2;
pcxread('iintro.1st',0,12937);
playsound(10);
delay(5000);
FadeOut(3);
cls(0,vga);
freesound(10);
end;


label exitgame;

begin

base:=0;volcnt:=2;
blast_env:=getenv('BLASTER');
if blast_env='' then begin
                     writeln('No SoundBlaster environment string found.');
                     writeln('Searching manually for SB...');
                     writeln('Possibly you have one hidden in your computer.');
                     for i:=1 to 9 do if resetdsp(i)
                         then begin
                              base:=2*256+i*16+0;
                              dev:=7;
                              break;
                              end;
                     if base=0
                        then begin
                             writeln('I really can''t find a blaster');
                             writeln('I will run quitely.');
                             dev:=255;
                             end;
                    end
               else begin
                    sb_digit:=byte(blast_env[3])-48;
                    resetdsp(sb_digit);
                    dev:=7;
                    base:=2*256+sb_digit*16;
                    speakeron;
                    setmixerreg(0,0);
                    volume:=voltable[volcnt*2];
                    setmixerreg($04,volume);
                    setmixerreg($22,volume);
                    end;

vga256;
initvscreen;
cls(0,vga);
WosIntro;

loadspr('mainfrm.spr',50);
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
option:=1;whatmenu := main;
initmenus;
randomize;

  modinit;
  mix := 5050;   {use 5050 for fast gaming }
  pro := 0; {Leave at 0}
  loop :=4; {0 means mod will play anD stop}
  modvolume (255,255,255,255);    { Full volume }
  md:='jarre.mod';
  modsetup ( stat, dev, mix, pro, loop, md );

  GetIntVec($1C,Int1CSave);
  SetIntVec($1C,Addr(TimerHandler));

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
key:=port[$60];
case key of
80 : begin inc(option); if option>menus[whatmenu].maxoption then option:=1; end;
72 : begin dec(option); if option<1 then option:=menus[whatmenu].maxoption; end;
1  : begin
     if menus[whatmenu].escape<>0 then whatmenu:=menus[whatmenu].escape;
     option:=1;
     end;
28 : begin
     case menus[whatmenu].select[option] of
     quit    : goto exitgame;
     what,options,ckeys,csound : begin
                                 whatmenu:=menus[whatmenu].select[option];
                                 option:=1;
                                 end;
     cvolume : begin
               whatmenu:=menus[whatmenu].select[option];
               option:=5-volcnt;
               end;
     setvolume : if dev=7
                 then begin
                      volcnt:=5-option;
                      volume:=voltable[volcnt*2];
                      setmixerreg($04,volume);
                      setmixerreg($22,volume);
                      whatmenu:=options;
                      option:=1;
                      end;
     setsound : begin
                case option of
                1 : dev:=7;
                2 : dev:=0;
                3 : dev:=1;
                4 : dev:=2;
                5 : dev:=255;
                end;
                modstop;
                if dev<>255 then
                begin
                mix := 5050;   {use 5050 for fast gaming }
                pro := 0; {Leave at 0}
                loop :=4; {0 means mod will play anD stop}
                modvolume (255,255,255,255);    { Full volume }
                md:='jarre.mod';
                modsetup ( stat, dev, mix, pro, loop, md );
                end;
                whatmenu:=options;
                option:=1;
                end;
     ostart  :  begin
                 Fadeout(4);
                 modstop;
                 cls(0,vga);cls(0,vaddr);
                 level:=0;
                 loadpal('sprites.pal');setpal;
                 temppal:=workpal;
                 score:=0;
                 repeat
                 str(level+1,slevel);
                 slevel:='Industrial level '+slevel;
                 outtext(160-length(slevel)*4,100,slevel,4,255,vga);
                 repeat until readkey=#13;
                 fadeout(4);
                 cls(0,vga);
                 workpal:=temppal;setpal;
                 inc(level);
                 loadlevel(level);
                 startgame;
                 fadeout(4);
                 cls(0,vga);
                 workpal:=temppal;setpal;
                 until exitcode<>2;
                 loadpal('mainfrm.pal');Setpal;
                 option:=1;whatmenu := main;
                 if dev<>255 then
                 begin
                 mix := 5050;
                 pro := 0;
                 loop :=4;
                 modvolume (255,255,255,255);
                 md:='jarre.mod';
                 modsetup ( stat, dev, mix, pro, loop, md );
                 end;
                 end;
     end;
     end;
end;
Lupa;
line(round(spotx+15*sin(ang*p)),round(spoty+15*cos(ang*p)),319,199,215,vaddr);
line(round(spotx+15*sin((ang+180)*p)),round(spoty+15*cos((ang+180)*p)),319,199,215,vaddr);
for i:=1 to menus[whatmenu].maxoption do
    outtext(160-length(menus[whatmenu].texte[i])*4,100+(i-1)*15,menus[whatmenu].texte[i],4,menus[whatmenu].color,vaddr);
if menus[whatmenu].select[1]<>0
   then outtext(160-length(menus[whatmenu].texte[option])*4,100+(option-1)*15,menus[whatmenu].texte[option],4,233,vaddr);
repeat
until DrawAllowed;
DrawAllowed := false;
Flip;
asm mov ax,$0c02
    int $21
end;

until false;
exitgame :
SetIntVec($01C,Int1CSave);
modstop;
fadeout(4);
speakeroff;
donevga256;
donevscreen;
asm mov ax,$0c02
    int $21
end;
end.



