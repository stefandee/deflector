unit Timer;

interface

uses
	Crt, Dos, Common;

const
    { this will be set to true every time int 08h gets triggered } 
	{ in the game code/game loop, wait for it to be set to true, then set it to false }
	{ it's a basic way to support running with the desired frame rate }
	TimerTick: boolean = false;

{ Init the timer system with a frequency (times per second) }
procedure InitTimer(freq: integer);

{ Miliseconds since timer was initialized }
function GetTicks:real;

{ Miliseconds since timer was initialized; same as GetTicks, but calculated differently }
function GetTimeElapsed:real;

{ Stops the timer system }
procedure StopTimer;

implementation

const
	ClockTicks: longint = 0;
	Frequency: integer = 0;
	
	{ Frequency of the PIT crystal oscillator }
	PIT_FREQUENCY = 1193182;
	
var
	TimerCount: Word;
	TimeElapsed: Real;
	TimeElapsedDelta: Real;
	OldInt1C: Procedure;
	OldInt08: Procedure;
	initialized: boolean;
	Trigger, IntCount08: Word;

{$F+,S-,W-}
procedure NewInt1C; interrupt;
begin
	{ is it necessary to rewrite 1C? seems that rewriting 08 is enough? }
end;
{$F-,S+,W+}

{$F+}
Procedure NewInt08; Interrupt;
Begin
	IrqOff;
	
	{ call interrupt 1Ch }
	{asm
		int $1C;
	end;}

	TimeElapsed := TimeElapsed + TimeElapsedDelta;
	inc(ClockTicks);
    TimerTick := true;

	{ chaining for int 08h - we still need to call this with the original frequency, which is 18.1 times/second }	
	If IntCount08 = Trigger then
	Begin
		IntCount08 := 0;
		
		asm
			pushf;
		end;

		OldInt08;
	End
	Else
	Begin
		Inc(IntCount08);
	End;	
	
	Port[$20]:=$20; {Sends non-specific EOI to the PIC}
	IrqOn;
End;
{$F-}

{ more info on how programmable interval timer works here: 
  https://wiki.osdev.org/Programmable_Interval_Timer }
procedure InitTimer(freq: integer);
begin
	if initialized then exit;

	ClockTicks := 0;
	
	{ TODO: limit to minimum frequency that can be achieved, which is PIT_FREQUENCY / 65536 = 18.2065 Hz }
	Frequency := freq;

	GetIntVec($08, @OldInt08);
	SetIntVec($08, Addr(NewInt08));
	
	GetIntVec($1C, @OldInt1C);
	SetIntVec($1C, Addr(NewInt1C));
		
	TimerCount := PIT_FREQUENCY div Frequency;
	
	{ values to chain the previous 08h interrupt with its default 18.2Hz frequency }
	{ this is an approximation, but should work well enough for a game }
	IntCount08 := 0;
	{Trigger := Max(Trunc(Frequency/18.2) - 1, 0);}
	Trigger := Trunc(Frequency/18.2);
	
	TimeElapsed := 0;
	TimeElapsedDelta := 1000 / Frequency;
	
	{ change the frequency }
	
	// https://expiredpopsicle.com/articles/2017-04-13-DOS_Timer_Stuff/2017-04-13-DOS_Timer_Stuff.html
	// 0x34 = 0011 0100 in binary.
    // 00  = Select counter 0 (counter divisor)
    // 11  = Command to read/write counter bits (low byte, then high
    //       byte, in sequence).
    // 010 = Mode 2 - rate generator.
    // 0   = Binary counter 16 bits (instead of BCD counter).
				
	Port[$43]:=$34; { $B6 or $34? }
	Port[$40]:=Lo(TimerCount);
	Port[$40]:=Hi(TimerCount);	

	initialized := true;
end;

function GetTicks:real;
begin
	GetTicks := ClockTicks / Frequency;
end;

function GetTimeElapsed:real;
begin
	GetTimeElapsed := TimeElapsed;
end;

procedure StopTimer;
begin
	if not initialized then exit;
	
	Port[$43]:=$34; { $B6 or $34? }
	Port[$40]:=0; { $FF }
	Port[$40]:=0;
	
	{ restore previous interrupt handlers }
	SetIntVec($08, @OldInt08);
	SetIntvec($1C, @OldInt1C);

	initialized := false;
end;

begin
end.