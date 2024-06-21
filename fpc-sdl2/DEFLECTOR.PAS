program Deflector;

{$APPTYPE GUI}

{ fix crash after returning from game to menu, then exiting the game }
{ editor }

uses 
    Graphics, 
    DefGame, 
    Crt, 
    Dos, 
    SprDef,
    SdlWrapper,
    Audio,
    AudioResource,
    ResourceDef,
    SDL2,
    ColorDef,
    Logger,
    SDL2_image,
    SDL2_mixer,
    SDL2_ttf,
    SysUtils,
    Settings,
    MathEx,
	Math;

type menu = record
          texte : array[1..10] of string;
          maxoption : byte;
          select    : array[1..10] of byte;
          id : byte;
          escape : byte;
          color : LongWord;
          end;

const 
    step=4;
    p=pi/180;
	LENS_SIZE = 80;
	HALF_LENS_SIZE = LENS_SIZE div 2;
	LENS_ZOOM = 20;
    
	{ menu select (actions) }
    main = 1;
	options = 3;
	quit = 4;
	what = 2;
	none = 0;
    ostart = 5;
    ckeys = 6 ; 
	ccontroller = 7; 
	sfxvolume = 8; 
	musicvolume = 9;
    setmusicvolume = 10;
    setsfxvolume = 11;
	editor = 12;
      
    KEYBOARD_NAVIGATION_DELAY = 75;
    
    VOLUME_TABLE : array[0..4] of byte=(0,25,50,75,100);
	
var 
    cx,cy : integer;
    stepx,stepy : integer;
    i: integer;
    spotx,spoty,sspotx : integer;
    ang : integer;
    option,whatmenu : byte;
    menus : array[1..15] of menu;
    slevel : string;
    
    event: TSDL_Event;
    keyNavTimeStamp: real;
    
    mixMusic: PMix_Music;
    volume: longint;
    volumeInTable: longint;

	{ precomputed offsets used to render the actual lens }
	lens: array [0..LENS_SIZE - 1, 0..LENS_SIZE - 1] of longint;

	requestGameExit: boolean;

procedure ComputeLensOffsets;
var
	r, sqrR, sqrX, sqrY, sqrD, d, x, y, ix, iy, offset, bpp: longint;
	shift: real;
	surface: PSDL_Surface;
begin
    surface := spr[SPRID_MENU_BKG].surface;
    bpp := surface^.format^.BytesPerPixel;

    r := HALF_LENS_SIZE;
	sqrR := r * r;
    d := LENS_ZOOM;
	sqrD := d * d;
	
    for y := 0 to HALF_LENS_SIZE - 1 do
	begin
		sqrY := y * y;
        for x := 0 to HALF_LENS_SIZE - 1 do
		begin
			sqrX := x * x;

            if ((sqrX + sqrY) < sqrR) then
			begin
                shift := d / sqrt(sqrD - (sqrX + sqrY - sqrR));
                ix := Trunc(x * shift - x);
                iy := Trunc(y * shift - y);
            end 
			else
			begin
                ix := 0;
                iy := 0;
            end;
			
            offset := (iy * surface^.pitch + ix * bpp);
            lens[HALF_LENS_SIZE - y][HALF_LENS_SIZE - x] := -offset;
            lens[HALF_LENS_SIZE + y][HALF_LENS_SIZE + x] := offset;
			
            offset := (-iy * surface^.pitch + ix * bpp);
            lens[HALF_LENS_SIZE + y][HALF_LENS_SIZE - x] := -offset;
            lens[HALF_LENS_SIZE - y][HALF_LENS_SIZE + x] := offset;
        end;
    end;
end;

procedure LensFx;
var
	x, y, temp, pos, bpp: longint;
	surface: PSDL_Surface;
	pixelsUInt8: PUInt8;
	pixelData: UInt32;	
	color: TSDL_Color;
begin
	surface := spr[SPRID_MENU_BKG].surface;
	bpp := surface^.format^.BytesPerPixel;

	SDL_LockSurface(surface);

	for y := 0 to LENS_SIZE - 1 do
	begin
		temp := (y + cy) * surface^.pitch + cx * bpp;
		
		for x := 0 to LENS_SIZE - 1 do
		begin
			pos := temp + x * bpp;
			  
			pixelsUInt8 := PUint8(surface^.pixels) + pos + lens[y, x];
			pixelData := PUInt32(pixelsUInt8)^;
			  
			SDL_GetRGBA(pixelData, surface^.format, @color.r, @color.g, @color.b, @color.a);
			
			SDL_SetRenderDrawColor(SDLRenderer, color.r, color.g, color.b, color.a);
			SDL_RenderDrawPoint(SDLRenderer, cx + x, cy + y);
		end;
	end;

	SDL_UnlockSurface(surface);  

	{ debug rectangle }
	{ Rectangle(cx, cy, cx + LENS_SIZE, cy + LENS_SIZE, COLOR_RED, nil); }
end;

procedure DrawBackground;
begin
    putspr(SPRID_MENU_BKG,0,0,SDL_BLENDMODE_NONE,nil);
end;

procedure InitMenus;
begin
with menus[main] do
begin
	id := main;

	texte[1]:='START GAME';
	texte[2]:='OPTIONS';
	texte[3]:='ABOUT';
	texte[4]:='QUIT';

	select[1]:=ostart;
	select[2]:=options;
	select[3]:=what;
	select[4]:=quit;

	{$IFOPT D+}
		texte[5]:='EDITOR';
		select[5]:=editor;
		maxoption:=5;
	{$ELSE}
		maxoption := 4;
	{$ENDIF}

	color := COLOR_WHITE;
	escape:=none;
end;
	 
with menus[what] do
     begin
     id := what;
     texte[1]:='A WOS Production';texte[2]:='December 1995';
     texte[3]:='Code/Design/Graphics: Stefan Dicu';
     texte[4]:='Title: Traian Pop';
     maxoption:=4;
     color := COLOR_RED;
     escape:=main;
     end;
with menus[sfxvolume] do
     begin
     texte[1]:='Full';
     texte[2]:='Three quarters';
     texte[3]:='Half';
     texte[4]:='Quarter';
     texte[5]:='Mute';
     maxoption:=5;
     for i:=1 to maxoption do select[i]:=setsfxvolume;
     color:=COLOR_WHITE;
     escape:=options;
     end;
with menus[musicvolume] do
     begin
     texte[1]:='Full';
     texte[2]:='Three quarters';
     texte[3]:='Half';
     texte[4]:='Quarter';
     texte[5]:='Mute';
     maxoption:=5;
     for i:=1 to maxoption do select[i]:=setmusicvolume;
     color:=COLOR_WHITE;
     escape:=options;
     end;

with menus[ckeys] do
     begin
     id:=ckeys;
     texte[1]:='Keyboard layout';
     texte[2]:='Move cursor: Arrow keys';
     texte[3]:='Turn laser: O/P';
     texte[4]:='Turn mirror: Enter';
     maxoption:=4;
     color:=COLOR_RED;
     escape:=options;
     end;
     
with menus[ccontroller] do
     begin
     id:=ccontroller;
     texte[1]:='Gamepad layout';
     texte[2]:='Move cursor: D-Pad';
     texte[3]:='Turn laser: X/Y';
     texte[4]:='Turn mirror: A';
     maxoption:=4;
     color:=COLOR_RED;
     escape:=options;
     end;

with menus[options] do
     begin
     id := options;
     texte[1]:='Keyboard';texte[2]:='Gamepad';texte[3]:='Sound Volume';texte[4]:='Music Volume';
     select[1]:=ckeys;select[2]:=ccontroller;select[3]:=sfxvolume;select[4]:=musicvolume;
     maxoption:=4;
     color:=COLOR_WHITE;
     escape:=main;
     end;

end;

procedure WOSintro;
var
  channel: Int32;
begin

LoadSpr(SPR_FILE_NAME_WOS_LOGO, SPRID_WOS_LOGO, nil);

cls(COLOR_BLACK, nil);

loadsound(SFX_WOS_INTRO_FILE_NAME, SFX_WOS_INTRO);
PutSpr(SPRID_WOS_LOGO, 0, 0, SDL_BLENDMODE_NONE, nil);

Flip;

channel := FadeInAudioOneShot(SFX_WOS_INTRO, 250);

WaitForAnyKeyDownOrDelay(5000);

FadeOut(500);

cls(COLOR_BLACK, nil);

Mix_HaltChannel(channel);

freesound(SFX_WOS_INTRO);
DoneSpr(SPRID_WOS_LOGO);

end;

procedure NavigationUp;
begin
    if (SDL_GetTicks - keyNavTimeStamp >= KEYBOARD_NAVIGATION_DELAY) then
    begin
        keyNavTimeStamp := SDL_GetTicks;
        dec(option); 
        if option<1 then option:=menus[whatmenu].maxoption;
		
		PlayAudioOneShot(SFX_MENU_NAVIGATE);
    end;
end;

procedure NavigationDown;
begin
    if (SDL_GetTicks - keyNavTimeStamp >= KEYBOARD_NAVIGATION_DELAY) then
    begin
        keyNavTimeStamp := SDL_GetTicks;
        inc(option); 
        if option>menus[whatmenu].maxoption then option:=1;
		
		PlayAudioOneShot(SFX_MENU_NAVIGATE);
    end;
end;

procedure ExitGame;
begin
	{ there is an invalid pointer operation when calling Halt, investigate further why it happens }
    try
		{ fade out music}
		Mix_FadeoutMusic(450);
		
		fadeout(500);

		Mix_HaltMusic;
		
		if mixMusic <> nil then Mix_FreeMusic(mixMusic);
		
		DoneAllSpr;
		
		TTF_CloseFont(FontMenu);
		TTF_CloseFont(FontGameUI);
		
		ShutDownAudio;
		
		ShutdownSDL;		
    except
		Log.LogStatus('Exception when ExitGame', 'ExitGame');
    end;	
end;

procedure NavigationBack;
begin
    { Back in main menu -> exit the game - this is for convenience of testing the game, maybe it won't make sense in a release }
    if whatmenu = main then 
	begin
		PlayAudioOneShot(SFX_EXIT_GAME);
	
		requestGameExit := true;
		exit;
	end;

    if menus[whatmenu].escape<>0 then 
    begin 
        whatmenu:=menus[whatmenu].escape;
        option:=1;
		
		PlayAudioOneShot(SFX_MENU_SELECT);
    end;
end;

procedure StartGameOrEditor(_gameMode: TGameMode = TGameMode.Play); forward;
procedure GameCompleted; forward;

procedure NavigationSelect;
begin
    case menus[whatmenu].select[option] of
    quit:
	begin
		requestGameExit := true;
		PlayAudioOneShot(SFX_EXIT_GAME);
	end;

    what, options, ckeys, ccontroller: 
    begin
        whatmenu:=menus[whatmenu].select[option];
        option:=1;
		PlayAudioOneShot(SFX_MENU_SELECT);
    end;

    sfxvolume:
    begin
        whatmenu:=menus[whatmenu].select[option];
        option:=1; { TODO get closest volume in table depending on settings }
		PlayAudioOneShot(SFX_MENU_SELECT);
    end;

    musicvolume: 
    begin
        whatmenu:=menus[whatmenu].select[option];
        option:=1;
		PlayAudioOneShot(SFX_MENU_SELECT);
    end;

    setsfxvolume: 
    begin
        volumeInTable := VOLUME_TABLE[5 - option];
        volume:=GameVolumeToSDLMixerVolume(volumeInTable);
        Mix_Volume(-1, volume);
        GameSettings.sfx.Volume := volumeInTable;
        SaveSettings;
        whatmenu:=options;
        option:=1;
		PlayAudioOneShot(SFX_MENU_SELECT);
    end;
            
    setmusicvolume:
    begin
        volumeInTable := VOLUME_TABLE[5 - option];
        volume:=GameVolumeToSDLMixerVolume(volumeInTable);
        Mix_VolumeMusic(volume);
        GameSettings.music.Volume := volumeInTable;
        SaveSettings;
        whatmenu:=options;
        option:=1;
		PlayAudioOneShot(SFX_MENU_SELECT);
    end;
	
    ostart:
		StartGameOrEditor(TGameMode.Play);
		
    editor:
		StartGameOrEditor(TGameMode.Edit);
	end;	
end;

procedure GameCompleted;
begin
	DrawBackground;

	outtextxy(LOGICAL_SCREEN_HALF_WIDTH, LOGICAL_SCREEN_HALF_HEIGHT - 10, 'You have completed the game!', FontMenu, COLOR_WHITE, HCENTER or VCENTER, nil);
	outtextxy(LOGICAL_SCREEN_HALF_WIDTH, LOGICAL_SCREEN_HALF_HEIGHT + 10, Format('Score: %d', [score]), FontMenu, COLOR_WHITE, HCENTER or VCENTER, nil);
	Flip;
		 
	WaitForAnyKeyDown;
	
	fadeout(500);
end;

procedure StartGameOrEditor(_gameMode: TGameMode = TGameMode.Play);
begin
	LoadGameData;
	
	PlayAudioOneShot(SFX_START_GAME);
	
	Fadeout(500);
	 
	cls(COLOR_BLACK, nil);
	
	{$IFOPT D+}
		level:=Clamp(GameSettings.CheatStartLevel, 1, LevelCount) - 1;
	{$ELSE}
		level:=0;
	{$ENDIF}
	
	score:=0;
		 
	repeat
	 
	str(level+1, slevel);
	slevel:='Industrial level '+slevel;
	outtextxy(LOGICAL_SCREEN_HALF_WIDTH,100,slevel, FontMenu, COLOR_WHITE, HCENTER, nil);
	Flip;

	WaitForAnyKeyDown;
	 
	fadeout(500);
	 
	cls(COLOR_BLACK, nil);
	inc(level);
	 
	loadlevel(level);
	startgame(_gameMode);
	 
	fadeout(500);
	cls(COLOR_BLACK, nil);
	
	if exitCode = TExitCode.LevelComplete then
		PlayAudioOneShot(SFX_LEVEL_COMPLETE);
	
	until exitcode <> TExitCode.LevelComplete;
	 
	if exitcode = TExitCode.GameComplete then
		GameCompleted;
	
	option:=1;
	whatmenu := main;		 
end;

procedure LoadSfxAndMusic;
begin
	{ load sfx }
	LoadSound(SFX_MENU_SELECT_FILE_NAME, SFX_MENU_SELECT);
	LoadSound(SFX_MENU_NAVIGATE_FILE_NAME, SFX_MENU_NAVIGATE);
	LoadSound(SFX_EXIT_GAME_FILE_NAME, SFX_EXIT_GAME);
	LoadSound(SFX_LEVEL_COMPLETE_FILE_NAME, SFX_LEVEL_COMPLETE);
	LoadSound(SFX_START_GAME_FILE_NAME, SFX_START_GAME);

	{ load and play music }
	mixMusic := MIX_LoadMUS(PChar(MusicPath(MOD_FILE_NAME)));
	Mix_VolumeMusic(GameSettings.music.volume);
	MIX_PlayMusic(mixMusic, MaxInt);
end;

begin

	SetDefaultSettings;
	LoadSettings;

	InitSDL(APP_WINDOW_TITLE, GameSettings.graphics.ResolutionWidth, GameSettings.graphics.ResolutionHeight);
	InitAudio;

	Mix_Volume(-1, GameSettings.sfx.volume);

	{ extract to method }
	FontMenu := TTF_OpenFont(PChar(FontPath('manaspc.ttf')), 12);
	TTF_SetFontHinting(FontMenu, TTF_HINTING_NORMAL);

	FontGameUI := TTF_OpenFont(PChar(FontPath('manaspc.ttf')), 10);
	TTF_SetFontHinting(FontGameUI, TTF_HINTING_NORMAL);

	cls(COLOR_BLACK, nil);

	{$IFOPT D+}
		if not GameSettings.SkipIntro then WosIntro;
	{$ELSE}
		WosIntro;
	{$ENDIF}	

	loadspr(SPR_FILE_NAME_MENU_BKG, SPRID_MENU_BKG, nil);
	loadspr(SPR_FILE_NAME_MENU_SPOTLIGHT, SPRID_MENU_SPOTLIGHT, nil);
	
	LoadSfxAndMusic();
	
	cx := LOGICAL_SCREEN_HALF_WIDTH - 20 + random(40);
	cy := LOGICAL_SCREEN_HALF_HEIGHT - 20 + random(40);
	stepx := 1 + random(2);
	stepy := 1 + random(2);
	
	spotx:=160;spoty:=50;sspotx:=2;
	ang:=0;
	option:=1;whatmenu := main;
	initmenus;
	
	randomize;

	keyNavTimeStamp := SDL_GetTicks;
	
	requestGameExit := false;
	
	ComputeLensOffsets;

	repeat
		cx := cx+stepx;
		
		if cx + LENS_SIZE >= LOGICAL_SCREEN_WIDTH - 1 then 
		begin 
			stepx := -stepx;
			cx := LOGICAL_SCREEN_WIDTH - 1 - LENS_SIZE;
		end;

		if cx < 0 then 
		begin 
			cx := 0;
			stepx := -stepx;
		end;

		cy := cy + stepy;
		
		if cy + LENS_SIZE >= LOGICAL_SCREEN_HEIGHT - 1 then 
		begin 
			cy := LOGICAL_SCREEN_HEIGHT - 1 - LENS_SIZE;
			stepy := -stepy; 
		end;
		
		if cy < 0 then 
		begin 
			cy := 0;
			stepy := -stepy; 
		end;
		
		spotx:=spotx+sspotx;
		
		case sspotx of
		-2 : if spotx<80 then sspotx:=2;
		2 : if spotx>240 then sspotx:=-2;
		end;
		inc(ang,6);if ang>360 then ang:=0;

		while SDL_PollEvent(@event) = 1 do
		begin
			case event.type_ of
				SDL_QUITEV:
					requestGameExit := true;
			
				SDL_CONTROLLERBUTTONDOWN:
				begin
					case event.cbutton.button of
						SDL_CONTROLLER_BUTTON_DPAD_UP:
							NavigationUp;
							
						SDL_CONTROLLER_BUTTON_DPAD_DOWN:
							NavigationDown;
							
						SDL_CONTROLLER_BUTTON_BACK, SDL_CONTROLLER_BUTTON_B:
							NavigationBack;
							
						SDL_CONTROLLER_BUTTON_A:
							NavigationSelect;
					end;
				end;
			
				SDL_KEYDOWN:
				begin
					case event.key.keysym.sym of
						SDLK_UP:
							NavigationUp;
						
						SDLK_DOWN:
							NavigationDown;
						
						SDLK_ESCAPE:
							NavigationBack;
						
						SDLK_RETURN:
							NavigationSelect;
					end;
				end;
			end;
		end;

		DrawBackground;

		{ render the spotlight }
		putspr(SPRID_MENU_SPOTLIGHT,spotx - 15,spoty - 15,SDL_BLENDMODE_BLEND,nil);

		{ render the spotlight edge lines }
		line(round(spotx+15*sin(ang*p)),round(spoty+15*cos(ang*p)),LOGICAL_SCREEN_WIDTH,199, $40808080, nil);
		line(round(spotx+15*sin((ang+180)*p)),round(spoty+15*cos((ang+180)*p)),LOGICAL_SCREEN_WIDTH,199, $40808080,nil);

		LensFx;

		for i:=1 to menus[whatmenu].maxoption do
			outtextxy(LOGICAL_SCREEN_HALF_WIDTH,100+(i-1)*15,menus[whatmenu].texte[i], FontMenu, menus[whatmenu].color, HCENTER, nil);
		if menus[whatmenu].select[1]<>0
		   then outtextxy(LOGICAL_SCREEN_HALF_WIDTH,100+(option-1)*15,menus[whatmenu].texte[option], FontMenu, COLOR_RED, HCENTER, nil);
		   
		Flip;   

	until requestGameExit;

	ExitGame;
end.
