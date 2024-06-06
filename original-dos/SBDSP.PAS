Unit SbDSP;

Interface

const maxdigitalsounds=10;
      volume :   byte = 204;
      freqv  :   word = 11025;
      voltable : array[0..8] of byte=(0,51,136,153,187,204,221,238,255);

type DigitalSound = record
                  len  : word;
                  psnd : pointer;
                  end;

var base     : word;
    sounds   : array[1..maxdigitalsounds] of DigitalSound;
    sb_digit : byte;
    blast_env: string;

procedure SetMixerReg(index, value : byte);

function GetMixerReg(index : byte) : byte;

{ ResetDSP returns true if reset was successful
  base should be 1 for base address 210h, 2 for 220h etc... }
function ResetDSP(base : word) : boolean;

{ Write DAC sets the speaker output level }
procedure WriteDAC(level : byte);

{ ReadDAC reads the microphone input level }
function ReadDAC : byte;

{ SpeakerOn connects the DAC to the speaker }
function SpeakerOn: byte;

{ SpeakerOff disconnects the DAC from the speaker,
  but does not affect the DAC operation }
function SpeakerOff: byte;

{ Functions to pause DMA playback }
procedure DMAStop;
procedure DMAContinue;

{ Playback plays a sample of a given size back at a given frequency using
  DMA channel 1. The sample must not cross a page boundry }
procedure LoadSound(fname : string;nr : byte);
procedure PlaySound(nr : byte);
procedure FreeSound(nr : byte);


Implementation

Uses Crt;

var      DSP_RESET : word;
     DSP_READ_DATA : word;
    DSP_WRITE_DATA : word;
  DSP_WRITE_STATUS : word;
    DSP_DATA_AVAIL : word;

{ base = 220h, 230 or 240h }
procedure SetMixerReg(index, value : byte);
begin
  Port[base + 4] := index;
  Port[base + 5] := value;
end;


function GetMixerReg(index : byte) : byte;
begin
  Port[base + 4] := index;
  GetMixerReg := Port[base + 5];
end;


function ResetDSP(base : word) : boolean;
 var count : integer;
begin

  base := base * $10;

  { Calculate the port addresses }
  DSP_RESET := base + $206;
  DSP_READ_DATA := base + $20A;
  DSP_WRITE_DATA := base + $20C;
  DSP_WRITE_STATUS := base + $20C;
  DSP_DATA_AVAIL := base + $20E;

  { Reset the DSP, and give some nice long delays just to be safe }
  Port[DSP_RESET] := 1;
  Delay(10);
  Port[DSP_RESET] := 0;
  Delay(10);
  Count:=1000;
  repeat
   dec(Count);
  until ((Port[DSP_READ_DATA] = $AA) and (Port[DSP_DATA_AVAIL] And $80 = $80)) or (Count<=0);
  if Count<=0 then ResetDsp:=false
              else ResetDsp:=true;
end;

procedure WriteDSP(value : byte);
begin
  while Port[DSP_WRITE_STATUS] And $80 <> 0 do;
  Port[DSP_WRITE_DATA] := value;
end;

function ReadDSP : byte;
begin
  while Port[DSP_DATA_AVAIL] and $80 = 0 do;
  ReadDSP := Port[DSP_READ_DATA];
end;

procedure WriteDAC(level : byte);
begin
  WriteDSP($10);
  WriteDSP(level);
end;

function ReadDAC : byte;
begin
  WriteDSP($20);
  ReadDAC := ReadDSP;
end;

function SpeakerOn: byte;
begin
  WriteDSP($D1);
end;

function SpeakerOff: byte;
begin
  WriteDSP($D3);
end;

procedure DMAContinue;
begin
  WriteDSP($D4);
end;

procedure DMAStop;
begin
  WriteDSP($D0);
end;

procedure LoadSound;
var f:file;
begin
assign(f,fname);
reset(f,1);
with sounds[nr] do
     begin
     len:=filesize(f);
     getmem(psnd,len);
     blockread(f,psnd^,len);
     end;
close(f);
end;

procedure PlaySound(nr:byte);
var time_constant : word;
     page, offset : word;
begin

  with sounds[nr] do
       begin
       len := len - 1;
       { Set up the DMA chip }
       offset := Seg(psnd^) Shl 4 + Ofs(psnd^);
       page := (Seg(psnd^) + Ofs(psnd^) shr 4) shr 12;
       Port[$0A] := 5;
       Port[$0C] := 0;
       Port[$0B] := $49;
       Port[$02] := Lo(offset);
       Port[$02] := Hi(offset);
       Port[$83] := page;
       Port[$03] := Lo(len);
       Port[$03] := Hi(len);
       Port[$0A] := 1;
  {    Set the playback frequency }
       time_constant := 256 - 1000000 div freqv;
       WriteDSP($40);
       WriteDSP(time_constant);
  {    Set the playback type (8-bit) }
       WriteDSP($14);
       WriteDSP(Lo(len));
       WriteDSP(Hi(len));
       end;
end;

procedure FreeSound;
begin
with sounds[nr] do
     begin
     freemem(psnd,len);
     len:=0;
     end;
end;

BEGIN
end.