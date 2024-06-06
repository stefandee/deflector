unit ResourceDef;

interface

const
	DATA_PATH = 'data/';
	TEXTURES_PATH = 'data/textures/';
	GAMEDATA_PATH = 'data/gamedata/';
	SFX_PATH = 'data/sfx/';
	MUSIC_PATH = 'data/music/';
	FONT_PATH = 'data/fonts/';
	
	APP_WINDOW_TITLE = 'Deflector';
	
function TexturesPath(fileName: string): string;	
function GameDataPath(fileName: string): string;	
function SfxPath(fileName: string): string;	
function MusicPath(fileName: string): string;	
function FontPath(fileName: string): string;	

implementation

function TexturesPath(fileName: string): string;
begin
	TexturesPath := TEXTURES_PATH + fileName;
end;

function GameDataPath(fileName: string): string;
begin
	GameDataPath := GAMEDATA_PATH + fileName;
end;

function SfxPath(fileName: string): string;
begin
	SfxPath := SFX_PATH + fileName;
end;

function MusicPath(fileName: string): string;
begin
	MusicPath := MUSIC_PATH + fileName;
end;

function FontPath(fileName: string): string;
begin
	FontPath := FONT_PATH + fileName;
end;

begin
end.