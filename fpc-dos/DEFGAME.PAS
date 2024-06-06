unit defgame;

interface

uses graphics,sbdsp,crt,timer,keyboard,GameDef,Events;

const dx = 10;
      dy = 10;

type
    DiskField = record
           id : byte;
           { 0 - nothing;1 - explosion;2-rotating mirror;
             3 - mirror ;4 - deflection glass; 5 - mines;
             6 - my laser generator }
           crt_move : byte;
           end;
		   
    field = record
           id : byte;
           { 0 - nothing;1 - explosion;2-rotating mirror;
             3 - mirror ;4 - deflection glass; 5 - mines;
             6 - my laser generator }
           crt_move : byte;
		   timestamp: real;
           end;

     Diskgamearr = array[1..15,1..32] of DiskField;
     gamearr = array[1..15,1..32] of field;

var cr_lev      : gamearr;
	disk_cr_lev : Diskgamearr;
    exitcode    : byte;
    score       : longint;
    temperature : real;
    level       : integer;

procedure LoadLevel(whatlevel : word);
procedure StartGame;

implementation

type tabela = array[0..359,1..2] of integer;

const
	AUTO_MIRROR_ROTATION_PERIOD = 50; { mili-seconds }
	MINE_HEAT_PERIOD = 50; { mili-seconds }
	HEAVY_MINE_HEAT_PERIOD = 50; { mili-seconds }
	COOL_DOWN_PERIOD = 50; { mili-seconds }
	
	COOL_DOWN_DELTA = 0.3;
	MINE_HEAT_DELTA = 0.35;
	HEAVY_MINE_HEAT_DELTA = 0.75;

var f : file of tabela;
    sc: tabela;
	event: TEvent;

procedure LoadLevel;
var f : file of Diskgamearr;
begin
assign(f,DataPath('levels.dat'));reset(f);seek(f,whatlevel-1);read(f,disk_cr_lev);close(f);
end;

procedure StartGame;

var lgx , lgy : integer;{gamearr coord of laser generator}
    cx,cy     : integer;
    teta      : integer;
    i         : integer;
    sprfname  : string;
    balls_left : integer;
	coolDownTimestamp: real;

{ initializes the level from the disk level; also finds the laser start point and initializes the timestamps }
procedure Find_lgx_lgy;
var i,j : integer;
begin
for i:=1 to 15 do 
	for j:=1 to 32 do 
		begin
		cr_lev[i, j]. id := disk_cr_lev[i, j].id;
		cr_lev[i,j].crt_move := disk_cr_lev[i, j].crt_move;
		
		cr_lev[i,j].timestamp := -1;
		
		if cr_lev[i,j].id=6
                                    then begin
                                         lgx:=j;lgy:=i;
                                         end;
		end;
end;

function Return_dir(olddir : integer;whatmov : byte) : integer;
var ret_expr : integer;
begin
case whatmov of
1 : ret_expr:=(abs(180+135-olddir)) mod 360;
2 : ret_expr:=(abs(180+180-olddir)) mod 360;
3 : ret_expr:=(abs(180+225-olddir)) mod 360;
4 : ret_expr:=(abs(180+270-olddir)) mod 360;
5 : ret_expr:=(abs(180+315-olddir)) mod 360;
6 : ret_expr:=(abs(180+360-olddir)) mod 360;
7 : ret_expr:=(abs(180+45-olddir))  mod 360;
8 : ret_expr:=(abs(180+90-olddir))  mod 360;
end;
Return_dir:=ret_expr;
end;

procedure Draw_Rays;

type ray = record
         xs,ys : integer;
         dir   : integer;
         end;

var maxrays,crt_ray : integer;
    whatmov,whatid : byte;
    raza : longint;
    expr1,expr2,expr3,expr4 : integer;
    r : array[1..200] of ray;

label ends;

begin
crt_ray:=1;maxrays:=1;
with r[1] do begin xs:=(lgx-1)*dx+dx div 2;ys:=(lgy-1)*dy+dy div 2; dir :=teta end;

repeat
{do the stuff}
with r[crt_ray] do
     begin
     for raza:=1 to 400 do
         begin
              expr1:=(xs+(raza*sc[dir mod 360,2]) div 256) div dx;
              expr2:=(ys+(raza*sc[dir mod 360,1]) div 256) div dy;
              expr3:=(xs+(raza*sc[dir mod 360,2]) div 256) mod dx;
              expr4:=(ys+(raza*sc[dir mod 360,1]) div 256) mod dy;
              putpixel(xs+(raza*sc[dir mod 360,2]) div 256,ys+(raza*sc[dir mod 360,1]) div 256,raza mod 23+33,vaddr);
              whatid:=cr_lev[expr2+1,expr1+1].id;
              whatmov:=cr_lev[expr2+1,expr1+1].crt_move;
              case whatid of
              8: if sprcolor(27+whatmov,expr3,expr4)<>0 then goto ends;
              9: if sprcolor(8+whatmov,expr3,expr4)<>0 then goto ends;
              3,2: if sprcolor(whatmov,expr3,expr4)<>0
                     then begin
                          if (expr1<>r[crt_ray].xs div dx) or
                             (expr2<>r[crt_ray].ys div dy)
                             then begin
                                  if maxrays<199 then inc(maxrays)
                                                 else goto ends;
                                  with r[maxrays] do
                                       begin
                                       xs:=expr1*dx+expr3;
                                       ys:=expr2*dy+expr4;
                                       dir:=return_dir(r[crt_ray].dir,whatmov);
                                       end;
                                  goto ends;
                                  end;

                          end;
              7: if sprcolor(17,expr3,expr4)<>0
                    then with cr_lev[expr2+1,expr1+1] do
                              begin
                              id:=1;
                              crt_move:=0;
                              score:=score+5*crt_ray;
                              end;
              5: if sprcolor(17,expr3,expr4)<>0
                    then begin
						 if (GetTimeElapsed - cr_lev[expr2+1,expr1+1].timestamp >= MINE_HEAT_PERIOD) then
						 begin
							cr_lev[expr2+1,expr1+1].timestamp := GetTimeElapsed;
							temperature := temperature + MINE_HEAT_DELTA;
						 end;
						 
                         goto ends;
                         end;
              11: if sprcolor(35,expr3,expr4)<>0
                    then begin
						 if (GetTimeElapsed - cr_lev[expr2+1,expr1+1].timestamp >= HEAVY_MINE_HEAT_PERIOD) then
						 begin
							cr_lev[expr2+1,expr1+1].timestamp := GetTimeElapsed;
							temperature := temperature + HEAVY_MINE_HEAT_DELTA;
						 end;
						 
                         goto ends;
                         end;

              end;
         end;
     ends:
{     outint(280,170,raza,3,100,vaddr);
     outint(220,170,expr2+1,3,100,vaddr);
     outint(240,170,expr1+1,3,100,vaddr);
     outint(200,170,whatid,3,100,vaddr);
     outint(0,180,score,3,100,vaddr);
     outint(50,180,temperature,3,100,vaddr);
     outint(260,170,teta,3,100,vaddr);
{     line(xs,ys,xs+(raza*sc[dir mod 360,2]) div 256,ys+(raza*sc[dir mod 360,1]) div 256,255,vaddr);}
     end;
inc(crt_ray);
until crt_ray>maxrays;
end;

procedure MeltDown;
const grain = 2;
var melt_table : array[1..320 div grain,1..2] of integer;
    i,j : integer;
    txt,txt1 : string;
begin
for i:=1 to 320 div grain do
    begin
    melt_table[i,1]:=0;
    melt_table[i,2]:=abs(round(10*sin(i)))+10;
    end;
txt:='METAL MELTDOWN';
txt1:='GAME OVER';
for i:=1 to 9 do
    begin
    for j:=1 to 320 div grain do
        if melt_table[j,2]+melt_table[j,1]<199
           then begin
                getimage(2,(j-1)*grain,melt_table[j,1],grain,199-melt_table[j,1],vaddr);
                bar((j-1)*grain,0,j*grain,200,0,vaddr);
                melt_table[j,1]:=melt_table[j,1]+melt_table[j,2];
                spr[2].yl:=spr[2].yl-melt_table[j,2];
                putspr(2,(j-1)*grain,melt_table[j,1],normalput,vaddr);
                spr[2].yl:=spr[2].yl+melt_table[j,2];
				
				{ this is very very slow, preserve it and remove it at the end }
                donespr(2);
                end;
    flip;
    end;
outtext(160-length(txt)*4,40,txt,4,255,vga);
outtext(160-length(txt1)*4,55,txt1,4,255,vga);

repeat until IsAnyKeyDown;
end;


procedure Animate;
var i,j : integer;
begin
for i:=0 to 14 do
    for j:=0 to 31 do
        with cr_lev[i+1,j+1] do
        case id of
        2 : begin
			if (timestamp = -1) then timestamp := GetTimeElapsed
			else if (GetTimeElapsed - timestamp >= AUTO_MIRROR_ROTATION_PERIOD) then
			begin
				timestamp := GetTimeElapsed;
				inc(crt_move);
				if crt_move>8 then crt_move:=1;
			end;
			putspr(crt_move,j*dx,i*dy,normalput,vaddr);
            end;
        3 : begin
            putspr(crt_move,j*dx,i*dy,normalput,vaddr);
            end;
        5 : begin
            inc(crt_move);
            if crt_move>4 then crt_move:=1;
            putspr(12+crt_move,j*dx,i*dy,normalput,vaddr);
            end;
        11 : begin
             inc(crt_move);
             if crt_move>5 then crt_move:=1;
             putspr(34+crt_move,j*dx,i*dy,normalput,vaddr);
             end;

        6 : begin
            putspr(32,j*dx,i*dy,normalput,vaddr);
            end;
        7 : begin
            putspr(17,j*dx,i*dy,normalput,vaddr);
            inc(balls_left);
            end;
        8 : begin
            putspr(crt_move+27,j*dx,i*dy,normalput,vaddr);
            end;
        9 : begin
            putspr(crt_move+8,j*dx,i*dy,normalput,vaddr);
            end;
        1 : begin
            inc(crt_move);
            if crt_move>10 then id:=0
                           else putspr(17+crt_move,j*dx,i*dy,normalput,vaddr);
            end;
       10 : putspr(33,j*dx,i*dy,normalput,vaddr);
       end;
end;

begin
Find_lgx_lgy;
{loading sprites}
for i:=0 to 39 do begin str(i,sprfname);loadspr(DataPath('spr'+sprfname+'.spr'),i+1);end;
teta:=1;exitcode:=0;cx:=1;cy:=1;
temperature:=10;
coolDownTimestamp := GetTimeElapsed;

repeat
cls(0,vaddr);

while (PollEvent(event)) do
begin
	case event.eventType of
		EventType.KeyDown:
		begin
			case event.key of
				KEY_P : begin
					 inc(teta);if teta>359 then teta:=0;
					 end;
					 
				KEY_O : begin
					 dec(teta);if teta<0 then teta:=359;
					 end;
					 
				KEY_ESC  : exitcode:=3;
				
				KEY_UP : if cy>1 then dec(cy);
				KEY_DOWN : if cy<15 then inc(cy);
				KEY_LEFT: if cx>1 then dec(cx);
				KEY_RIGHT : if cx<32 then inc(cx);
				KEY_ENTER : with cr_lev[cy,cx] do
					 if id=3
						then begin
							 inc(crt_move);
							 if crt_move>8 then crt_move:=1;
							 end;
			end;
		end;
	end;
end;		

if (temperature > 10) and (GetTimeElapsed - coolDownTimestamp >= COOL_DOWN_PERIOD) then 
begin
	coolDownTimestamp := GetTimeElapsed;
	temperature := temperature - COOL_DOWN_DELTA;
	if temperature < 10 then temperature := 10;
end;

if temperature>100 then exitcode:=1;{meltdown}
balls_left:=0;
Animate;
Draw_Rays;
putspr(40,(cx-1)*dx,(cy-1)*dy,copyput,vaddr);

if balls_left=0 then exitcode:=2;
putspr(34,0,150,normalput,vaddr);
outtext(16,180,'Temperature      Level         Score',3,255,vaddr);
outint(50,190,Trunc(temperature),3,143,vaddr);
outint(168,190,level,3,143,vaddr);
outint(268,190,score,3,143,vaddr);
repeat
until TimerTick;
TimerTick := false;
{waitretrace;}
flip;
until exitcode<>0;

for i:=0 to 39 do donespr(i+1);

ClearEventQueue;
if exitcode=1 then meltdown;
end;

begin
assign(f,DataPath('speedtab.sc'));reset(f);read(f,sc);close(f);
end.