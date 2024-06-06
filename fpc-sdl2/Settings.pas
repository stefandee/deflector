unit Settings;

interface

uses
	Math,
	MathEx,
	SDLWrapper,
	fpjson,
	jsonparser,
	jsonConf;

type
	TGraphicsSettings = record
		ResolutionWidth: longint;
		ResolutionHeight: longint;
		FullScreen: boolean;
	end;
	
	TSfxSettings = record
		Volume: longint;
	end;
	
	TMusicSettings = record
		Volume: longint;
	end;
	
	TGameSettings = record
		SkipIntro: boolean;
		NoFadeOut: boolean;
		
		graphics: TGraphicsSettings;
		sfx: TSfxSettings;
		music: TMusicSettings;
	
		CheatStartLevel: longint;
		CheatNoOverload: boolean;
		CheatInfiniteLives: boolean;
	end;

const
  SETTINGS_FILE_NAME = 'settings.json';
  MAX_VOLUME = 100;
  MIN_VOLUME = 0;
  HALF_VOLUME = (MAX_VOLUME - MIN_VOLUME) div 2;
  
var
	GameSettings: TGameSettings;
  
procedure SetDefaultSettings;
procedure LoadSettings;
procedure SaveSettings;  

implementation

procedure SetDefaultSettings;
begin
	with GameSettings do
	begin
		SkipIntro := false;
		NoFadeOut := false;
		
		with graphics do
		begin
			ResolutionWidth := SCREEN_WIDTH;
			ResolutionHeight := SCREEN_HEIGHT;
			FullScreen := false;
		end;
		
		with sfx do
		begin
			Volume := HALF_VOLUME;
		end;
		
		with music do
		begin
			Volume := HALF_VOLUME;
		end;
		
		CheatStartLevel := 1;
	end;
end;

procedure LoadSettings;
var
  c: TJSONConfig;
begin
  c:= TJSONConfig.Create(Nil);
  try
    //try/except to handle broken json file
    try
      c.Formatted:= true;
      c.Filename:= SETTINGS_FILE_NAME;
    except
      exit;
    end;

	with GameSettings do
	begin
		SkipIntro := c.GetValue('/flow/skipintro', false);
		NoFadeOut := c.GetValue('/flow/nofadeout', false);
	
		with graphics do
		begin
			ResolutionWidth := Max(c.GetValue('/graphics/resolution/width', SCREEN_WIDTH), SCREEN_WIDTH);
			ResolutionHeight := Max(c.GetValue('/graphics/resolution/height', SCREEN_HEIGHT), SCREEN_HEIGHT);
			FullScreen := c.GetValue('/graphics/resolution/fullScreen', false);
		end;
		
		with sfx do
		begin
			Volume := Clamp(c.GetValue('/sfx/volume', HALF_VOLUME), MIN_VOLUME, MAX_VOLUME);
		end;
		
		with music do
		begin
			Volume := Clamp(c.GetValue('/music/volume', HALF_VOLUME), MIN_VOLUME, MAX_VOLUME);
		end;
		
		CheatStartLevel := Max(c.GetValue('/cheats/spacewarp', 1), 1);
	end;
  finally
    c.Free;
  end;
end;

procedure SaveSettings;
var
  c: TJSONConfig;
begin
  c:= TJSONConfig.Create(Nil);
  try
    //try/except to handle broken json file
    try
      c.Formatted:= true;
      c.Filename:= SETTINGS_FILE_NAME;
    except
      exit;
    end;

	with GameSettings do
	begin	
		c.SetValue('/flow/skipintro', SkipIntro);
		c.SetValue('/flow/nofadeout', NoFadeOut);
	
		with graphics do
		begin
			c.SetValue('/graphics/resolution/width', ResolutionWidth);
			c.SetValue('/graphics/resolution/height', ResolutionHeight);
			c.SetValue('/graphics/resolution/fullScreen', FullScreen);
		end;
		
		with sfx do
		begin
			c.SetValue('/sfx/volume', Volume);
		end;
		
		with music do
		begin
			c.SetValue('/music/volume', Volume);
		end;

		c.SetValue('/cheats/spacewarp', CheatStartLevel);
	end;
	
  finally
    c.Free;
  end;
end;

begin
end.