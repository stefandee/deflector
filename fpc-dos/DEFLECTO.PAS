program Deflector;
//{$M 65520,0,250000}
uses Graphics, SbDsp, DefGame, Crt, Images, Dos, Timer, Keyboard, Events, GameDef;

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
	  MOD_FILE_NAME = 'NeonTech.mod';
	  KEYBOARD_NAVIGATION_DELAY = 150;

var 
    cx,cy : integer;
    dx,dy : integer;
    stepx,stepy : integer;
    i,j   : integer;
    spotx,spoty,sspotx : integer;
    hashtable : array[0..255,1..10] of byte;
    index:integer;
    ang : integer;
    option,whatmenu : byte;
    menus : array[1..15] of menu;
    slevel : string;
    temppal : paltype;
	
	event: TEvent;
	optionStr: string;
	keyNavTimeStamp: real;

var
    mix,stat,pro,loop : integer;

//{$L MOD-obj.OBJ} 	        { Link in Object file }
{$F+} 				{ force calls to be 'far'}
procedure modvolume(v1,v2,v3,v4:integer); begin end;
procedure moddevice(var device:integer); begin end;
procedure modsetup(var status:integer;device,mixspeed,pro,loop:integer;str:string); begin end;
procedure modstop; begin end;
procedure modinit; begin end;
{$F-}

procedure Lupa;
var i,j:integer;
	limitX: integer;
	limitY: integer;
	barX: integer;
	barY: integer;
	circleX: integer;
begin
	limitX := dx div 2;
	limitY := dy div 2;
	
	barX := -limitX * 2 + cx;
	
        for i:=-limitX to limitX do
		begin
			bary := -limitY + cy;
			circleX := (i*i) shl 2;
            for j:=-limitY to limitY do
			begin
                if circleX + ((j*j) shl 2) < 961 then
                begin
                    putpixel(spotx+i,spoty+j,hashtable[sprcolor(50,spotx+i,spoty+j),1],vaddr);					
                    FastBar(barX, barY, barX + 2, barY + 2, sprcolor(50,cx+i,cy+j), vaddr);
                end;
				barY := barY + 2;
			end;
			barx := barx + 2;
		end;

end;

procedure LupaOriginal;
var i,j:integer;
begin
        for i:=-dx div 2 to dx div 2 do
            for j:=-dy div 2 to dy div 2 do
                if (i*i) shl 2+(j*j) shl 2<961 then
                begin
                    bar(cx+i*2,cy+j*2,cx+i*2+2,cy+j*2+2,sprcolor(50,cx+i,cy+j),vaddr);
                    putpixel(spotx+i,spoty+j,hashtable[sprcolor(50,spotx+i,spoty+j),1],vaddr);
                end;

end;


procedure DrawBackground;
begin
	putspr(50,0,0,normalput,vaddr);
end;

procedure InitMenus;
begin
with menus[main] do
     begin
     id := main;
     texte[1]:='START GAME';texte[2]:='OPTIONS';texte[3]:='ABOUT';texte[4]:='QUIT';
     maxoption:=4;
     select[1]:=ostart;select[2]:=options;select[3]:=what;select[4]:=quit;
     color := 81;
     escape:=none;
     end;
with menus[what] do
     begin
     id := what;
     texte[1]:='A WOS Production';texte[2]:='December 1995';
     texte[3]:='Code/Design/Graphics: Stefan Dicu';
     texte[4]:='Title: Traian Pop';
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
loadsound(DataPath('sintro.raw'),10);
corection:=2;
pcxread(DataPath('iintro.pcx'),0,12937);
playsound(10);
delay(5000);
FadeOut(3);
cls(0,vga);
freesound(10);
end;


label exitgame;

begin

InitTimer(30);
InitKeyboard;
SetKeyboardParams(0, 0, true);

InitSoundBlaster;


vga256;
initvscreen;
cls(0,vga);

{WosIntro;}

loadspr(DataPath('mainfrm.spr'),50);
loadpal(DataPath('mainfrm.pal'));Setpal;

dx:=30;dy:=30;cx:=160;cy:=30;
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
  modsetup ( stat, dev, mix, pro, loop, MOD_FILE_NAME );

keyNavTimeStamp := -1;

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

while (PollEvent(event)) do
begin
	case event.eventType of
		EventType.KeyDown:
		begin
			case event.key of
				KEY_UP:
				begin
					if (keyNavTimeStamp = -1) then keyNavTimeStamp := GetTimeElapsed
					else if (GetTimeElapsed - keyNavTimeStamp >= KEYBOARD_NAVIGATION_DELAY) then
					begin
						keyNavTimeStamp := GetTimeElapsed;
						dec(option); 
						if option<1 then option:=menus[whatmenu].maxoption;
					end;
				end;
				
				KEY_DOWN:
				begin
					if (keyNavTimeStamp = -1) then keyNavTimeStamp := GetTimeElapsed
					else if (GetTimeElapsed - keyNavTimeStamp >= KEYBOARD_NAVIGATION_DELAY) then
					begin
						keyNavTimeStamp := GetTimeElapsed;
						inc(option); 
						if option>menus[whatmenu].maxoption then option:=1;
					end;
				end;
				
				KEY_ESC:
				begin
					{ ESC in main menu -> exit the game }
					if whatmenu = main then goto exitgame;
				
					if menus[whatmenu].escape<>0 then 
					begin 
						whatmenu:=menus[whatmenu].escape;
						option:=1;
					end;
				end;
				
				KEY_ENTER:
				begin
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
								modsetup ( stat, dev, mix, pro, loop, MOD_FILE_NAME );
								end;
								whatmenu:=options;
								option:=1;
								end;
					 ostart  :  begin
								 ClearEventQueue;
								 
								 Fadeout(4);
								 modstop;
								 cls(0,vga);cls(0,vaddr);
								 level:=0;
								 loadpal(DataPath('sprites.pal'));setpal;
								 temppal:=workpal;
								 score:=0;
								 repeat
								 str(level+1,slevel);
								 slevel:='Industrial level '+slevel;
								 outtext(160-length(slevel)*4,100,slevel,4,255,vga);
								 repeat until IsAnyKeyDown;
								 
								 ClearEventQueue;
								 
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
								 loadpal(DataPath('mainfrm.pal'));Setpal;
								 option:=1;whatmenu := main;
								 
								 if dev<>255 then
								 begin
									 mix := 5050;
									 pro := 0;
									 loop :=4;
									 modvolume (255,255,255,255);
									 modsetup ( stat, dev, mix, pro, loop, MOD_FILE_NAME );
								 end;

								 ClearEventQueue;
								 end;
					 end;				
				end;
			end;
		end;
	end;
end;

DrawBackground;

Lupa;

{ draw spotlight edge lines }
line(round(spotx+15*sin(ang*p)),round(spoty+15*cos(ang*p)),319,199,215,vaddr);
line(round(spotx+15*sin((ang+180)*p)),round(spoty+15*cos((ang+180)*p)),319,199,215,vaddr);

for i:=1 to menus[whatmenu].maxoption do
    outtext(160-length(menus[whatmenu].texte[i])*4,100+(i-1)*15,menus[whatmenu].texte[i],4,menus[whatmenu].color,vaddr);
if menus[whatmenu].select[1]<>0
   then outtext(160-length(menus[whatmenu].texte[option])*4,100+(option-1)*15,menus[whatmenu].texte[option],4,233,vaddr);
   
{ wait retrace, then... }
Flip;   

repeat
until TimerTick;
TimerTick := false;

until false;

exitgame:

StopTimer;
StopKeyboard;
ResetKeyboardParams;
modstop;
fadeout(4);
speakeroff;
donevga256;
donevscreen;
asm mov ax,$0c02
    int $21
end;
end.



