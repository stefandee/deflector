unit Audio;

interface

uses 
  SDL2_mixer,
  Logger,
  SDL2,
  SysUtils,
  ResourceDef,
  MathEx;

const
	AUDIO_RATE = 22050;
	AUDIO_FORMAT = AUDIO_S16SYS;
	AUDIO_CHANNELS = 2;
	
	SOUNDS_COUNT = 32;
  
type
  TSoundList = array[0..SOUNDS_COUNT] of PMix_Chunk;
  
var
  Sounds : TSoundList;  

procedure InitAudio;
function PlayAudioOneShot(index : Integer): Int32;
function FadeInAudioOneShot(index : Integer; fadeTimeMS: UInt32): Int32;
procedure LoadSound(filename : String; index : Integer);
procedure FreeSound(index: Integer);
procedure ShutDownAudio;

function GameVolumeToSDLMixerVolume(volume: longint): longint;

implementation

function PlayAudioOneShot(index : Integer): Int32;
begin
  if Sounds[index] <> nil then
  begin
	PlayAudioOneShot := Mix_PlayChannel(-1, Sounds[index], 0);
  end;
end;

function FadeInAudioOneShot(index : Integer; fadeTimeMS: UInt32): Int32;
begin
  if Sounds[index] <> nil then
  begin
	FadeInAudioOneShot := Mix_FadeInChannel(-1, Sounds[index], 0, fadeTimeMS);	
  end;
end;

procedure InitAudio;
begin
    { Open the audio device }
	if (Mix_OpenAudio(AUDIO_RATE, AUDIO_FORMAT, AUDIO_CHANNELS, 65536) < 0) then
	begin
		Log.LogError(Format('Couldn''t open audio: %s', [SDL_GetError]), 'Main');
		Halt;
	end	
end;

procedure LoadSound(filename : String; index : Integer);
begin
	Log.LogStatus(Format('LoadSound: %s at index %d', [filename, index]), 'Audio');
	
	if (index < Low(Sounds)) or (index > High(Sounds)) then 
	begin 
		Log.LogError(Format('LoadSound: index %d is out of range', [index]), 'Audio');
		exit;
	end;

	Sounds[index] := Mix_LoadWAV(PChar(SfxPath(filename)));
	if ( Sounds[index] = nil ) then
	begin
		Log.LogError(Format('Couldn''t load %s: %s', [filename, SDL_GetError]), 'Audio');
	end;
end;

procedure FreeSound(index: Integer);
begin
	if (index < Low(Sounds)) or (index > High(Sounds)) then 
	begin 
		Log.LogError(Format('LoadSound: index %d is out of range', [index]), 'Audio');
		exit;
	end;
	
	Mix_FreeChunk(Sounds[index]);
	Sounds[index] := nil;
end;

procedure ShutDownAudio;
begin
	Mix_CloseAudio;
end;

function GameVolumeToSDLMixerVolume(volume: longint): longint;
begin
	volume := Clamp(volume, 0, 100);
	GameVolumeToSDLMixerVolume := (volume * MIX_MAX_VOLUME) div 100;
end;

begin
end.
