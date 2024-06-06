Unit SdlWrapper;

Interface

Uses 
	SDL2,
	SDL2_ttf,
	Logger;
	
Const 
	  LOGICAL_SCREEN_WIDTH = 320; { design/logical resolution width }
	  LOGICAL_SCREEN_HEIGHT = 200; { design/logical resolution height }
	  
	  LOGICAL_SCREEN_HALF_WIDTH = LOGICAL_SCREEN_WIDTH div 2; { design/logical resolution half width }
	  LOGICAL_SCREEN_HALF_HEIGHT = LOGICAL_SCREEN_HEIGHT div 2; { design/logical resolution half height }
	  
	  SCREEN_WIDTH = 640; 
	  SCREEN_HEIGHT = 400; 
	  	
Var
  SdlRenderer: PSDL_Renderer;

{ initializes all SDL related things that the app uses }
procedure InitSDL(windowName: string; width, height: longint);

{ close down SDL }
procedure ShutdownSDL;

procedure WaitForAnyKeyDown;

procedure WaitForAnyKeyDownOrDelay(delay: UInt32);

Implementation

Var
  SdlWindow: PSDL_Window;

procedure InitJoysticks; forward;

procedure InitSDL(windowName: string; width, height: longint);
begin
	SDL_SetHint(SDL_HINT_JOYSTICK_THREAD, '1');
	
	// scaling filter
	SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, '0');

	if SDL_Init(SDL_INIT_EVERYTHING ) < 0 then Halt;
	
	SdlWindow := SDL_CreateWindow(PChar(windowName), SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height, SDL_WINDOW_SHOWN);
	if SdlWindow = nil then Halt;
	
	sdlRenderer := SDL_CreateRenderer(SdlWindow, -1, SDL_RENDERER_PRESENTVSYNC or SDL_RENDERER_ACCELERATED);
	if sdlRenderer = nil then Halt;
	
	// set logical resolution
	if SDL_RenderSetLogicalSize(sdlRenderer, LOGICAL_SCREEN_WIDTH, LOGICAL_SCREEN_HEIGHT) <> 0 then Halt;
	
	if TTF_Init = -1 then HALT;
	
	InitJoysticks;
end;

procedure InitJoysticks;
var
	i: longint;
begin
	for i := 0 to SDL_NumJoysticks - 1 do
	begin
		SDL_JoystickOpen(i);
		SDL_GameControllerOpen(i);
	end;
end;

procedure ShutdownSDL;
begin
	TTF_Quit;

	SDL_DestroyRenderer(SdlRenderer);
	
	SDL_DestroyWindow (SdlWindow);

	// bye
	SDL_Quit;
end;

function WaitForAnyKeyDownInternal: boolean;
var
	sdlEvent: TSDL_Event;
begin
	while SDL_PollEvent( @sdlEvent ) = 1 do
	begin
		if (sdlEvent.type_ = SDL_CONTROLLERBUTTONDOWN) and (sdlEvent.cbutton.button = SDL_CONTROLLER_BUTTON_A) or
		   (sdlEvent.type_ = SDL_KEYDOWN) then 
		begin
			WaitForAnyKeyDownInternal := true;
			exit;
		end;
	end;
		
	WaitForAnyKeyDownInternal := false;		
end;

procedure WaitForAnyKeyDown;
begin
	while not WaitForAnyKeyDownInternal do
	begin
	end;	
end;

procedure WaitForAnyKeyDownOrDelay(delay: UInt32);
var
	ticks: UInt32;
begin
	ticks := SDL_GetTicks;

	while (SDL_GetTicks - ticks < delay) and (not WaitForAnyKeyDownInternal) do
	begin
	end;
end;

begin
end.

