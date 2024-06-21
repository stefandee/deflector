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
	OBJID_WALL = 9;
	OBJID_CORNER = 8;
	
	AUTO_MIRROR_ROTATION_PERIOD = 50; { mili-seconds }
	MINE_HEAT_PERIOD = 50; { mili-seconds }
	HEAVY_MINE_HEAT_PERIOD = 50; { mili-seconds }
	COOL_DOWN_PERIOD = 50; { mili-seconds }
	
	MINE_WARNING_PERIOD = 500; { mili-seconds }
	HEAVY_MINE_WARNING_PERIOD = 300; { mili-seconds }
	
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
	LevelCountInternal: longint;
	mineWarningTimestamp: longint;

procedure ClearDiskLevel(var diskLevel: Diskgamearr); forward;
procedure InitTemplateDiskLevel(var diskLevel: Diskgamearr); forward;

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
	
	cf, editorLevel: integer;
	txt: string;
	rot: boolean;
	editorSelection: field;

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

procedure MineWarning(period: longint);
begin
	if SDL_GetTicks - mineWarningTimestamp >= period then
	begin
		mineWarningTimestamp := SDL_GetTicks;
		PlayAudioOneShot(SFX_GAME_TEMP_INCREASE_LOW);
	end;
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
							  PlayAudioOneShot(SFX_GAME_BUBBLE_POP);
                              end;
							  
              5: if not IsSprPixelTransparent(17,expr3,expr4)
                    then begin
						 if (SDL_GetTicks - cr_lev[expr2+1,expr1+1].timestamp >= MINE_HEAT_PERIOD) then
						 begin
							cr_lev[expr2+1,expr1+1].timestamp := SDL_GetTicks;
							temperature := temperature + MINE_HEAT_DELTA;

							MineWarning(MINE_WARNING_PERIOD);
						 end;
						 
                         goto ends;
                         end;
              11: if not IsSprPixelTransparent(35,expr3,expr4)
                    then begin
						 if (SDL_GetTicks - cr_lev[expr2+1,expr1+1].timestamp >= HEAVY_MINE_HEAT_PERIOD) then
						 begin
							cr_lev[expr2+1,expr1+1].timestamp := SDL_GetTicks;
							temperature := temperature + HEAVY_MINE_HEAT_DELTA;
							
							MineWarning(HEAVY_MINE_WARNING_PERIOD);
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

	PlayAudioOneShot(SFX_MELTDOWN);

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

procedure AnimateField(var f: field; x, y: integer);
begin
        with f do
        case id of
        2 : begin
			if (SDL_GetTicks - timestamp >= AUTO_MIRROR_ROTATION_PERIOD) then
			begin
				timestamp := SDL_GetTicks;
				inc(crt_move);
				if crt_move>8 then crt_move:=1;
			end;
			putspr(crt_move,x,y,SDL_BLENDMODE_NONE,nil);
            end;
        3 : begin
            putspr(crt_move,x,y,SDL_BLENDMODE_NONE,nil);
            end;
        5 : begin
            inc(crt_move);
            if crt_move>4 then crt_move:=1;
            putspr(12+crt_move,x,y,SDL_BLENDMODE_NONE,nil);
            end;
        11 : begin
             inc(crt_move);
             if crt_move>5 then crt_move:=1;
             putspr(34+crt_move,x,y,SDL_BLENDMODE_NONE,nil);
             end;

        6 : begin
            putspr(32,x,y,SDL_BLENDMODE_NONE,nil);
            end;
        7 : begin
            putspr(17,x,y,SDL_BLENDMODE_NONE,nil);
            inc(balls_left);
            end;
        8 : begin
            putspr(crt_move+27,x,y,SDL_BLENDMODE_NONE,nil);
            end;
        9 : begin
            putspr(crt_move+8,x,y,SDL_BLENDMODE_NONE,nil);
            end;
        1 : begin
            inc(crt_move);
            if crt_move>10 then id:=0
                           else putspr(17+crt_move,x,y,SDL_BLENDMODE_NONE,nil);
            end;
       10 : putspr(33,x,y,SDL_BLENDMODE_NONE,nil);
       end;
end;

procedure Animate;
var i,j : integer;
begin
for i:=0 to 14 do
    for j:=0 to 31 do
		AnimateField(cr_lev[i+1,j+1], j*dx, i*dy);
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
			PlayAudioOneShot(SFX_GAME_ROTATE_MIRROR);
		end;
end;

procedure EditAction(var target: field);
begin
	with target do
		case cf of
		1..8 : begin
			if rot then begin id:=2;crt_move:=cf; end
				   else begin id:=3;crt_move:=cf; end;
			txt:='mirror';
			end;
		9    : begin id:=0;txt:='none'; end;
		10   : begin id:=5;crt_move:=1; txt:='mine';end;
		12   : begin id:=7;crt_move:=1; txt:='ball';end;
		13..16 : begin id:=8;crt_move:=cf-12;txt:='corner';end;
		17..20 : begin id:=9;crt_move:=cf-16;txt:='wall';end;
		21   : begin id:=11;crt_move:=1;txt:='heavy mine';end;
		end;
end;

procedure SaveLevel;
var
	diskLevel: Diskgamearr;
	i, j: integer;
	f: file of Diskgamearr;
begin
	{ convert to disk level }
	for i:=1 to 15 do 
		for j:=1 to 32 do 
		begin
			diskLevel[i, j].id := cr_lev[i, j].id;
			diskLevel[i, j].crt_move := cr_lev[i, j].crt_move;
			
			if diskLevel[i, j].id <> 0 then
				Log.LogStatus(Format('id: %d, move: %d', [diskLevel[i, j].id, diskLevel[i, j].crt_move]), 'SaveLevel');
		end;

	{ keep the internal level list updated, so we don't load again }
	levels[editorLevel] := diskLevel;

  try
	assign(f, GameDataPath('levels.dat'));
	reset(f);

	seek(f, editorLevel - 1);
	write(f, levels[editorLevel]);
	
	close(f);	
	
  except
    // If there was an error the reason can be found here
    on E: EInOutError do
      Log.LogStatus(Format('File handling error occurred. Details: %s %s', [E.ClassName, E.Message]), 'SaveLevel');
  end;
end;

function ChangeEditorLevel(newEditorLevel: longint): longint;
begin
	newEditorLevel := Clamp(newEditorLevel, 1, MAX_LEVELS);
	
	disk_cr_lev := levels[newEditorLevel];
	Find_lgx_lgy;
	
	ChangeEditorLevel := newEditorLevel;
end;

begin
Find_lgx_lgy;
teta:=1;exitcode:=TExitCode.Nothing;cx:=1;cy:=1;

temperature := MIN_TEMPERATURE;
coolDownTimestamp := SDL_GetTicks;
mineWarningTimestamp := SDL_GetTicks;

commandTurnLaserCW := false;
commandTurnLaserCCW := false;

controllerDX := 0;
controllerDY := 0;

gameMode := _gameMode;

{ editor initialization }
cf:=1;
rot:=false;
editorLevel := level;
EditAction(editorSelection);

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
					if gameMode = TGameMode.Play then Action
					else EditAction(cr_lev[cy,cx]);
					
				{$IFOPT D+}
				SDLK_Q:
					exitcode := TExitCode.GameComplete;
					
				SDLK_W:
					exitcode := TExitCode.LevelComplete;
					
				SDLK_E:
					exitcode := TExitCode.LevelFailed;
					
				SDLK_PAGEUP : begin
					 if cf<21 then inc(cf)
					 else cf := 1;
					 
					 EditAction(editorSelection);
					 end;
					 
				SDLK_PAGEDOWN: begin
					 if cf>1 then dec(cf)
					 else cf := 21;
					 
					 EditAction(editorSelection);
					 end;
					 
				SDLK_HOME: begin cr_lev[lgy,lgx].id:=0;lgx:=cx;lgy:=cy;cr_lev[lgy,lgx].id:=6;end;
				
				SDLK_END : rot:=not rot;
				
				SDLK_DELETE : cr_lev[cy,cx].id:=0;
				
				SDLK_S:
					SaveLevel;
					
				SDLK_C:
				begin
					ClearDiskLevel(disk_cr_lev);
					InitTemplateDiskLevel(disk_cr_lev);
					Find_lgx_lgy;
				end;
					
				SDLK_PLUS, SDLK_KP_PLUS:
					editorLevel := ChangeEditorLevel(editorLevel + 1);
					
				SDLK_MINUS, SDLK_KP_MINUS:
					editorLevel := ChangeEditorLevel(editorLevel - 1);
					
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
			
			{if temperature = MIN_TEMPERATURE then
				PlayAudioOneShot(SFX_GAME_TEMP_NORMAL);}
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
		outintxy(LOGICAL_SCREEN_WIDTH div 2,187, level,FontGameUI, COLOR_WHITE, HCENTER,nil);

		outtextxy(5 * LOGICAL_SCREEN_WIDTH div 6, 175, 'Score', FontGameUI, COLOR_WHITE, HCENTER, nil);
		outintxy(5 * LOGICAL_SCREEN_WIDTH div 6,187,score,FontGameUI, COLOR_WHITE, HCENTER,nil);
	end;
	
	TGameMode.Edit:
	begin
		{ draw the level }
		Animate;
		
		{ draw the cursor }
		putspr(SPRID_GAME_CURSOR,(cx-1)*dx,(cy-1)*dy,SDL_BLENDMODE_BLEND,nil);

		putspr(SPRID_INGAME_LOGO, 0, 147, SDL_BLENDMODE_BLEND, nil);

		{ editor related hud }
		outtextxy(LOGICAL_SCREEN_WIDTH div 6, 175, txt, FontGameUI, COLOR_WHITE, HCENTER, nil);
		AnimateField(editorSelection, LOGICAL_SCREEN_WIDTH div 6 - 5, 187);
		
		outtextxy(LOGICAL_SCREEN_WIDTH div 2, 175, 'Level', FontGameUI, COLOR_WHITE, HCENTER, nil);
		outintxy(LOGICAL_SCREEN_WIDTH div 2,187, editorLevel, FontGameUI, COLOR_WHITE, HCENTER,nil);
		
		outtextxy(5 * LOGICAL_SCREEN_WIDTH div 6, 175, 'Rotate', FontGameUI, COLOR_WHITE, HCENTER, nil);		
		if rot then outtextxy(5 * LOGICAL_SCREEN_WIDTH div 6,187, 'On',FontGameUI, COLOR_WHITE, HCENTER,nil)
		else outtextxy(5 * LOGICAL_SCREEN_WIDTH div 6,187, 'Off',FontGameUI, COLOR_WHITE, HCENTER,nil);
	end;
end;	

flip;
until exitcode <> TExitCode.Nothing;

if exitcode=TExitCode.LevelFailed then meltdown;
end;

procedure ClearDiskLevel(var diskLevel: Diskgamearr);
var
	i, j: integer;
begin
	for i:=1 to 15 do 
		for j:=1 to 32 do 
		begin
			diskLevel[i, j]. id := OBJID_EMPTY;
			diskLevel[i,j].crt_move := 0;
		end;
end;

{ initializes a level with a template - basically the margins and corners }
procedure InitTemplateDiskLevel(var diskLevel: Diskgamearr);
var
	i, j: integer;
begin
		{13..16 : begin id:=8;crt_move:=cf-12;txt:='corner';end;
		17..20 : begin id:=9;crt_move:=cf-16;txt:='wall';end;}
		
	for i:=1 to 15 do 
	begin
		diskLevel[i, 1].id := OBJID_WALL;
		diskLevel[i, 1].crt_move := 3;
		
		diskLevel[i, 32].id := OBJID_WALL;
		diskLevel[i, 32].crt_move := 1;
	end;
		
	for j:=1 to 32 do 
	begin
		diskLevel[1, j].id := OBJID_WALL;
		diskLevel[1, j].crt_move := 2;
		
		diskLevel[15, j].id := OBJID_WALL;
		diskLevel[15, j].crt_move := 4;
	end;
	
	diskLevel[1, 32].id := OBJID_CORNER;
	diskLevel[1, 32].crt_move := 1;
	
	diskLevel[1, 1].id := OBJID_CORNER;
	diskLevel[1, 1].crt_move := 2;
	
	diskLevel[15, 32].id := OBJID_CORNER;
	diskLevel[15, 32].crt_move := 3;
	
	diskLevel[15, 1].id := OBJID_CORNER;
	diskLevel[15, 1].crt_move := 4;
	
	diskLevel[7, 16].id := OBJID_LASER_GENERATOR;
	diskLevel[7, 16].crt_move := 0;
		
	{for i:=1 to 15 do 
		for j:=1 to 32 do 
		begin
			diskLevel[i, j]. id := OBJID_EMPTY;
			diskLevel[i,j].crt_move := 0;
		end;}
end;

procedure LoadGameData;
var
	f : file of Diskgamearr;
	i: integer;
	sprfname: string;
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
	
	LevelCountInternal := FileSize(f);
	
	Log.LogStatus(Format('Found %d levels', [LevelCountInternal]), 'LoadGameData');
	
	for i := 1 to LevelCountInternal do
		read(f, levels[i]);
		
	close(f);
	
	{ initialize with empty levels everything that is past what we found on disk }
	if LevelCountInternal + 1 < MAX_LEVELS then
		for i := LevelCountInternal + 1 to MAX_LEVELS do
		begin
			ClearDiskLevel(levels[i]);
			InitTemplateDiskLevel(levels[i]);
		end;
		
	{ load sfx }
	LoadSound(SFX_MELTDOWN_FILE_NAME, SFX_MELTDOWN);
	LoadSound(SFX_GAME_ROTATE_MIRROR_FILE_NAME, SFX_GAME_ROTATE_MIRROR);
	LoadSound(SFX_GAME_BUBBLE_POP_FILE_NAME, SFX_GAME_BUBBLE_POP);
	LoadSound(SFX_GAME_TEMP_NORMAL_FILE_NAME, SFX_GAME_TEMP_NORMAL);
	LoadSound(SFX_GAME_TEMP_INCREASE_LOW_FILE_NAME, SFX_GAME_TEMP_INCREASE_LOW);
end;

function LevelCount: longint;
begin
	LevelCount := LevelCountInternal;
end;

begin
	gameDataLoaded := false;
end.