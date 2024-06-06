unit defgame;

interface

uses
	SDL2,
	Crt,
	SDLWrapper,
	graphics,
	Audio,
	AudioResource,
	ResourceDef,
	ColorDef,
	Logger,
	SprDef,
	SysUtils,
	Math,
	MathEX;

type
	TExitCode = (Nothing = 0, LevelFailed = 1, LevelComplete = 2, QuitGame = 3, GameComplete = 4);
	TGameMode = (Play, Edit);

const dx = 10;
      dy = 10;

var 
    exitcode    : TExitCode;
    score       : longint;
    temperature : real;
    level       : integer; { 1 based, indexes into levels array }

procedure LoadLevel(whatlevel : word);
procedure StartGame(_gameMode: TGameMode = TGameMode.Play);
procedure LoadGameData;
function LevelCount: longint;

implementation

type 
	tabela = array[0..359,1..2] of word;

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
			 
		   { current animation }
           crt_move : byte;
		   
		   { used for animation }
		   timestamp: longword;
           end;

     Diskgamearr = array[1..15,1..32] of DiskField;
     gamearr = array[1..15,1..32] of field;


const
	OBJID_EMPTY = 0;
	OBJID_EXPLOSION = 1;
	OBJID_ROTATING_MIRROR = 2;
	OBJID_MIRROR = 3;
	OBJID_DEFLECTION_GLASS = 4;
	OBJID_MINE = 5;
	OBJID_HEAVY_MINE = 11;
	OBJID_LASER_GENERATOR = 6;
	OBJID_COLLECTABLE = 7; { the balls }
	OBJID_WALL1 = 8;
	OBJID_WALL2 = 9;
	
	AUTO_MIRROR_ROTATION_PERIOD = 50; { mili-seconds }
	MINE_HEAT_PERIOD = 50; { mili-seconds }
	HEAVY_MINE_HEAT_PERIOD = 50; { mili-seconds }
	COOL_DOWN_PERIOD = 50; { mili-seconds }
	
	COOL_DOWN_DELTA = 0.25;
	MINE_HEAT_DELTA = 0.5;
	HEAVY_MINE_HEAT_DELTA = 0.75;
	
	MIN_TEMPERATURE = 10;
	MAX_TEMPERATURE = 100;
	
	TURN_LASER_PERIOD = 60;
	CONTROLLER_NAVIGATION_PERIOD = 60;
	
	MAX_LEVELS = 100;

var 
	cr_lev      : gamearr;
	disk_cr_lev : Diskgamearr;
	gameDataLoaded: boolean;
	event: TSDL_Event;
	levels: array[1..MAX_LEVELS] of Diskgamearr;

procedure LoadLevel(whatlevel : word);
begin
	disk_cr_lev := levels[whatlevel];
end;

procedure StartGame(_gameMode: TGameMode = TGameMode.Play);

var 
	lgx , lgy : integer;{gamearr coord of laser generator}
    cx,cy     : integer;
    teta      : integer;
    balls_left : integer;
	coolDownTimestamp: longword;
	commandTurnLaserCW, commandTurnLaserCCW: boolean;
	turnLaserTimestamp: longword;
	controllerDX, controllerDY: longint;
	controllerNavigationTimestamp: longword;
	gameMode: TGameMode;

{ initializes the level from the disk level; also finds the laser start point and initializes the timestamps }
procedure Find_lgx_lgy;
var i,j : integer;
begin
for i:=1 to 15 do 
	for j:=1 to 32 do 
		begin
		cr_lev[i, j]. id := disk_cr_lev[i, j].id;
		cr_lev[i,j].crt_move := disk_cr_lev[i, j].crt_move;
		
		cr_lev[i,j].timestamp := SDL_GetTicks;
		
		if cr_lev[i,j].id=6
                                    then begin
                                         lgx:=j;lgy:=i;
                                         end;
							
		{ change rotating mirrors to normal mirrors, for testing purposes }
		{ if cr_lev[i,j].id=2 then cr_lev[i,j].id := 3; }
		end;
end;

function Return_dirV(olddir : TVector; whatmov : byte) : TVector;
var
	r, n: TVector;
	dot: real;
begin
	Log.LogStatus(Format('whatmov: %d', [whatmov]), 'dir');
		
	{ get the normals depending on the orientation of the mirrors }
	case whatmov of	
	2: 
	begin
		n.x := 0;
		n.y := 1;
	end;
	
	6: 
	begin
		n.x := 0;
		n.y := -1;
	end;
	
	4: 
	begin
		n.x := 1;
		n.y := 0;
	end;
	
	8: 
	begin
		n.x := -1;
		n.y := 0;
	end;


	3:
	begin
		n.x := Cos(Pi / 4);
		n.y := Sin(Pi / 4);
	end;

	7: 
	begin
		n.x := Cos(Pi / 4 + PI);
		n.y := Sin(Pi / 4 + PI);
	end;
	
	
	1: 
	begin
		n.x := Sin(3 * PI / 4);
		n.y := Cos(3 * PI / 4);
	end;
		
	5: 
	begin
		n.x := Sin(3 * PI / 4 + PI);
		n.y := Cos(3 * PI / 4 + PI);
	end;
	
	end;
	
	Normalize(n);
	
	{ computing reflection using the following formula, where n is the mirror normal and d is olddir }
	{ r = d - 2 (d . n) n }
	
	dot := olddir.x * n.x + olddir.y * n.y;
	r.x := olddir.x - 2 * dot * n.x;
	r.y := olddir.y - 2 * dot * n.y;
	
	Normalize(r);
	
	Return_dirV := r;
end;

procedure Draw_Rays;

type ray = record
         xs,ys : integer;
         dir   : integer;
		 dirV  : TVector;
         end;

var maxrays,crt_ray : integer;
    whatmov,whatid : byte;
    raza : longint;
    expr1,expr2,expr3,expr4 : integer;
    r : array[1..200] of ray;
	rayColor: byte;
	nx, ny: integer;
	dirRadians: real;
label ends;

begin
crt_ray:=1;maxrays:=1;

with r[1] do 
begin 
	xs:=(lgx-1)*dx+dx div 2;
	ys:=(lgy-1)*dy+dy div 2; 
	dir :=teta;
	
    dirRadians := Pi * dir / 180;
	dirV.x := Cos(dirRadians);
	dirV.y := Sin(dirRadians);
end;

repeat
{do the stuff}
{30 years later, a more relevant comment: logic to raycast/draw and interact will objects in the scene}
with r[crt_ray] do
     begin
     for raza:=1 to 400 do
         begin
			  nx := Round(xs + raza * dirV.x);
			  ny := Round(ys + raza * dirv.y);
			  
              expr1:= nx div dx;
			  expr1 := Max(0, Min(expr1, 32 - 1));
			  
              expr2:= ny div dy;
			  expr2 := Max(0, Min(expr2, 15 - 1));
			  
              expr3:=nx mod dx;
              expr4:=ny mod dy;
			  
			  raycolor := ((255 * (raza mod 23 + 33) div 45) and $FF);
              putpixel(nx, ny, $FFFFFF00 or rayColor, nil);
			  
              whatid:=cr_lev[expr2+1,expr1+1].id;
              whatmov:=cr_lev[expr2+1,expr1+1].crt_move;
              case whatid of
              8: if not IsSprPixelTransparent(27+whatmov,expr3,expr4) then goto ends;
              9: if not IsSprPixelTransparent(8+whatmov,expr3,expr4) then goto ends;
              3, 2: if not IsSprPixelTransparent(whatmov,expr3,expr4)
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
                                       {dir:=return_dir(r[crt_ray].dir,whatmov);}
                                       dirV:=return_dirV(r[crt_ray].dirV,whatmov);
                                       end;
                                  goto ends;
                                  end;

                          end;
              7: if not IsSprPixelTransparent(17,expr3,expr4)
                    then with cr_lev[expr2+1,expr1+1] do
                              begin
                              id:=1;
                              crt_move:=0;
                              score:=score+5*crt_ray;
                              end;
							  
              5: if not IsSprPixelTransparent(17,expr3,expr4)
                    then begin
						 if (SDL_GetTicks - cr_lev[expr2+1,expr1+1].timestamp >= MINE_HEAT_PERIOD) then
						 begin
							cr_lev[expr2+1,expr1+1].timestamp := SDL_GetTicks;
							temperature := temperature + MINE_HEAT_DELTA;
						 end;
						 
                         goto ends;
                         end;
              11: if not IsSprPixelTransparent(35,expr3,expr4)
                    then begin
						 if (SDL_GetTicks - cr_lev[expr2+1,expr1+1].timestamp >= HEAVY_MINE_HEAT_PERIOD) then
						 begin
							cr_lev[expr2+1,expr1+1].timestamp := SDL_GetTicks;
							temperature := temperature + HEAVY_MINE_HEAT_DELTA;
						 end;
						 
                         goto ends;
                         end;
              end;
         end;
     ends:
     end;
inc(crt_ray);
until crt_ray>maxrays;
end;

procedure MeltDown;
const 
	grain = 1;
	MELT_TABLE_WIDTH = LOGICAL_SCREEN_WIDTH div grain;
	
var 
	melt_table : array[1..MELT_TABLE_WIDTH,1..2] of real;
    i,j : integer;
	texture: PSDL_Texture;
	surface: PSDL_Surface;
	renderer: PSDL_Renderer;
	renderW, renderH: longint;
	srcRect, dstRect: TSDL_RECT;
	deltaTime: real;
	scaleFactor: real;
begin
	renderer := SDLRenderer;
	
	SDL_GetRendererOutputSize(renderer, @renderW, @renderH);
	Log.LogStatus(Format('Meltdown output size %d x %d', [renderW, renderH]), 'Meltdown');
	
	surface := SDL_CreateRGBSurfaceWithFormat(0, renderW, renderH, 32, SDL_PIXELFORMAT_ARGB8888);
	
	if surface = nil then
	begin
		Log.LogStatus(Format('SDL_CreateRGBSurfaceWithFormat failed with error %s', [SDL_GetError]), 'Fadeout');
		exit;
	end;
	
	SDL_RenderReadPixels(renderer, nil, surface^.format^.format, surface^.pixels, surface^.pitch);
	
	texture := SDL_CreateTextureFromSurface(renderer, surface);
	
	if texture = nil then
	begin
		Log.LogStatus(Format('SDL_CreateTextureFromSurface failed with error %s', [SDL_GetError]), 'Fadeout');
		
		SDL_FreeSurface(surface);
		exit;
	end;	


	for i:=1 to MELT_TABLE_WIDTH do
    begin
		melt_table[i,1]:=0;
		{melt_table[i,2]:=round(10 * sin(10 * i * PI / 180)) + 20;}
		melt_table[i,2]:=abs(round((5 + random(5)) * sin(i / 2.0))) + 5 + random(5);
    end;
	
	deltaTime := 0.16667;

	for i:=1 to 50 do
    begin
    
	cls(COLOR_BLACK);
	
	{ TODO Reimplement this }	
	for j := 1 to MELT_TABLE_WIDTH do
        if melt_table[j, 2] + melt_table[j, 1] * deltaTime < LOGICAL_SCREEN_HEIGHT then 
		begin
			scaleFactor := renderW / LOGICAL_SCREEN_WIDTH;
			srcRect.x := Trunc((j - 1) * grain * scaleFactor);
			srcRect.y := 0;
			srcRect.w := Trunc(grain * scaleFactor);
			srcRect.h := renderH;
			
			dstRect.x := (j - 1) * grain;
			dstRect.y := Trunc(melt_table[j,1]);
			dstRect.w := grain;
			dstRect.h := LOGICAL_SCREEN_HEIGHT;
			
			SDL_RenderCopy(renderer, texture, @srcRect, @dstRect);
			
			melt_table[j,1] := melt_table[j,1] + melt_table[j,2] * deltaTime;
        end;
	
    Flip;
	end;
	
outtextxy(160,40,'METAL MELTDOWN!', FontMenu, COLOR_WHITE, HCENTER, nil);
outtextxy(160,55,'GAME OVER',FontMenu, COLOR_WHITE, HCENTER, nil);
Flip;

WaitForAnyKeyDown;

SDL_FreeSurface(surface);
SDL_DestroyTexture(texture);

end;


procedure Animate;
var i,j : integer;
begin
for i:=0 to 14 do
    for j:=0 to 31 do
        with cr_lev[i+1,j+1] do
        case id of
        2 : begin
			if (SDL_GetTicks - timestamp >= AUTO_MIRROR_ROTATION_PERIOD) then
			begin
				timestamp := SDL_GetTicks;
				inc(crt_move);
				if crt_move>8 then crt_move:=1;
			end;
			putspr(crt_move,j*dx,i*dy,SDL_BLENDMODE_NONE,nil);
            end;
        3 : begin
            putspr(crt_move,j*dx,i*dy,SDL_BLENDMODE_NONE,nil);
            end;
        5 : begin
            inc(crt_move);
            if crt_move>4 then crt_move:=1;
            putspr(12+crt_move,j*dx,i*dy,SDL_BLENDMODE_NONE,nil);
            end;
        11 : begin
             inc(crt_move);
             if crt_move>5 then crt_move:=1;
             putspr(34+crt_move,j*dx,i*dy,SDL_BLENDMODE_NONE,nil);
             end;

        6 : begin
            putspr(32,j*dx,i*dy,SDL_BLENDMODE_NONE,nil);
            end;
        7 : begin
            putspr(17,j*dx,i*dy,SDL_BLENDMODE_NONE,nil);
            inc(balls_left);
            end;
        8 : begin
            putspr(crt_move+27,j*dx,i*dy,SDL_BLENDMODE_NONE,nil);
            end;
        9 : begin
            putspr(crt_move+8,j*dx,i*dy,SDL_BLENDMODE_NONE,nil);
            end;
        1 : begin
            inc(crt_move);
            if crt_move>10 then id:=0
                           else putspr(17+crt_move,j*dx,i*dy,SDL_BLENDMODE_NONE,nil);
            end;
       10 : putspr(33,j*dx,i*dy,SDL_BLENDMODE_NONE,nil);
       end;
end;

procedure TurnLaserCW;
begin
	inc(teta);
	if teta>359 then teta:=0;
end;

procedure TurnLaserCCW;
begin
	dec(teta);
	if teta<0 then teta:=359;
end;

procedure NavigateCursor(dx, dy: integer);
begin
	if dx <> 0 then cx := Clamp(cx + dx, 1, 32);		
	if dy <> 0 then cy := Clamp(cy + dy, 1, 15);		
end;

procedure Action;
begin
	{ turn a mirror }
	with cr_lev[cy,cx] do
		if id=3 then 
		begin
			inc(crt_move);
			if crt_move>8 then crt_move:=1;
		end;
end;

begin
Find_lgx_lgy;
teta:=1;exitcode:=TExitCode.Nothing;cx:=1;cy:=1;

temperature := MIN_TEMPERATURE;
coolDownTimestamp := SDL_GetTicks;

commandTurnLaserCW := false;
commandTurnLaserCCW := false;

controllerDX := 0;
controllerDY := 0;

gameMode := _gameMode;

repeat
cls(COLOR_BLACK,nil);

while SDL_PollEvent(@event) = 1 do
begin
	case event.type_ of
		SDL_KEYDOWN:
		begin
			case event.key.keysym.sym of
				SDLK_P:
					TurnLaserCW;
					 
				SDLK_O: 
					TurnLaserCCW;
					 
				SDLK_ESCAPE: 
					exitcode:=TExitCode.QuitGame;
				
				SDLK_UP:
					NavigateCursor(0, -1);  
					
				SDLK_DOWN:
					NavigateCursor(0, 1); 
					
				SDLK_LEFT:
					NavigateCursor(-1, 0); 
					
				SDLK_RIGHT:
					NavigateCursor(1, 0);
				
				SDLK_RETURN: 
					Action;
					
				{$IFOPT D+}
				SDLK_Q:
					exitcode := TExitCode.GameComplete;
					
				SDLK_W:
					exitcode := TExitCode.LevelComplete;
					
				SDLK_E:
					exitcode := TExitCode.LevelFailed;
				{$ENDIF}
			end;
		end;
		
		SDL_CONTROLLERBUTTONDOWN:
		begin
			case event.cbutton.button of
				SDL_CONTROLLER_BUTTON_LEFTSHOULDER:
				begin
					turnLaserTimestamp := SDL_GetTicks;
					commandTurnLaserCCW := true;
					TurnLaserCCW;
				end;
					
				SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:
				begin
					turnLaserTimestamp := SDL_GetTicks;
					commandTurnLaserCW := true;
					TurnLaserCW;
				end;
				
				SDL_CONTROLLER_BUTTON_A:
					Action;
				
				SDL_CONTROLLER_BUTTON_BACK:
					exitcode := TExitCode.QuitGame;
									
				SDL_CONTROLLER_BUTTON_DPAD_UP: 
				begin
					controllerDX := 0;
					controllerDY := -1;
					NavigateCursor(controllerDX, controllerDY);
					controllerNavigationTimestamp := SDL_GetTicks;
				end;
				
				SDL_CONTROLLER_BUTTON_DPAD_DOWN: 
				begin
					controllerDX := 0;
					controllerDY := 1;
					NavigateCursor(controllerDX, controllerDY);
					controllerNavigationTimestamp := SDL_GetTicks;
				end;
					
				SDL_CONTROLLER_BUTTON_DPAD_LEFT: 
				begin
					controllerDX := -1;
					controllerDY := 0;
					NavigateCursor(controllerDX, controllerDY);
					controllerNavigationTimestamp := SDL_GetTicks;
				end;
					
				SDL_CONTROLLER_BUTTON_DPAD_RIGHT: 
				begin
					controllerDX := 1;
					controllerDY := 0;
					NavigateCursor(controllerDX, controllerDY);
					controllerNavigationTimestamp := SDL_GetTicks;
				end;
			end;
		end;
		
		SDL_CONTROLLERBUTTONUP:
		begin
			case event.cbutton.button of
				SDL_CONTROLLER_BUTTON_LEFTSHOULDER:
					commandTurnLaserCCW := false;
					
				SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:
					commandTurnLaserCW := false;
					
				SDL_CONTROLLER_BUTTON_DPAD_UP, SDL_CONTROLLER_BUTTON_DPAD_DOWN, SDL_CONTROLLER_BUTTON_DPAD_LEFT, SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
				begin
					controllerDX := 0;
					controllerDY := 0;
				end;					
			end;
		end;
		
	end;	
end;

if SDL_GetTicks - turnLaserTimestamp >= TURN_LASER_PERIOD then
begin
	turnLaserTimestamp := SDL_GetTicks;	
	
	if commandTurnLaserCW then TurnLaserCW;
	if commandTurnLaserCCW then TurnLaserCCW;
end;

if ((controllerDX <> 0) or (controllerDY <> 0)) and (SDL_GetTicks - controllerNavigationTimestamp >= CONTROLLER_NAVIGATION_PERIOD) then
begin
	controllerNavigationTimestamp := SDL_GetTicks;
	NavigateCursor(controllerDX, controllerDY);
end;

case gameMode of
	TGameMode.Play:
	begin
		if (temperature > MIN_TEMPERATURE) and (SDL_GetTicks - coolDownTimestamp >= COOL_DOWN_PERIOD) then 
		begin
			coolDownTimestamp := SDL_GetTicks;
			temperature := Max(temperature - COOL_DOWN_DELTA, MIN_TEMPERATURE);	
		end;

		if temperature > MAX_TEMPERATURE then exitcode:=TExitCode.LevelFailed; {meltdown}

		balls_left:=0;
		{ this also counts how many balls are left in the level }
		Animate;

		Draw_Rays;

		{cursor}
		putspr(SPRID_GAME_CURSOR,(cx-1)*dx,(cy-1)*dy,SDL_BLENDMODE_BLEND,nil);

		if balls_left=0 then exitcode:=TExitCode.LevelComplete;
		putspr(SPRID_INGAME_LOGO,0,147,SDL_BLENDMODE_BLEND,nil);

		outtextxy(LOGICAL_SCREEN_WIDTH div 6, 175, 'Temperature', FontGameUI, COLOR_WHITE, HCENTER, nil);
		outintxy(LOGICAL_SCREEN_WIDTH div 6,187,Trunc(temperature),FontGameUI, COLOR_WHITE, HCENTER,nil);

		outtextxy(LOGICAL_SCREEN_WIDTH div 2, 175, 'Level', FontGameUI, COLOR_WHITE, HCENTER, nil);
		outintxy(LOGICAL_SCREEN_WIDTH div 2,187, level + 1,FontGameUI, COLOR_WHITE, HCENTER,nil);

		outtextxy(5 * LOGICAL_SCREEN_WIDTH div 6, 175, 'Score', FontGameUI, COLOR_WHITE, HCENTER, nil);
		outintxy(5 * LOGICAL_SCREEN_WIDTH div 6,187,score,FontGameUI, COLOR_WHITE, HCENTER,nil);
	end;
	
	TGameMode.Edit:
	begin
		{ draw the level }
		Animate;
		
		{ draw the cursor }
		putspr(SPRID_GAME_CURSOR,(cx-1)*dx,(cy-1)*dy,SDL_BLENDMODE_BLEND,nil);
	end;
end;	

flip;
until exitcode <> TExitCode.Nothing;

if exitcode=TExitCode.LevelFailed then meltdown;
end;

procedure LoadGameData;
var
	f : file of Diskgamearr;
	i: integer;
	sprfname: string;
	levelCount: longint;
begin
	if gameDataLoaded then exit;

	{ load the game play related sprites }
	for i:=0 to 39 do 
	begin 
		str(i,sprfname);
		loadspr('spr'+sprfname+'.png',i+1,nil);
	end;
	
	{ preload all levels }
	assign(f,GameDataPath('levels.dat'));
	reset(f);
	
	levelCount := FileSize(f);
	
	for i := 1 to levelCount do
		read(f, levels[i]);
		
	close(f);
end;

function LevelCount: longint;
begin
	LevelCount := length(levels);
end;

begin
	gameDataLoaded := false;
end.