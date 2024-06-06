unit Keyboard;

interface

uses
	Common, Dos, Events;
	
const
	DEFAULT_KEYBOARD_DELAY = 0.2; { miliseconds }
	
const
	EXTENDED_SCANCODE_BASE = $60;
	KEY_ESC = 1;
	KEY_ENTER = 28;
	KEY_O = 24;
	KEY_P = 25;
	KEY_UP = EXTENDED_SCANCODE_BASE + 72;
	KEY_DOWN = EXTENDED_SCANCODE_BASE + 80;
	KEY_LEFT = EXTENDED_SCANCODE_BASE + 75;
	KEY_RIGHT = EXTENDED_SCANCODE_BASE + 77;

procedure InitKeyboard;
function IsKeyDown(keyCode: integer): boolean;
function IsXKeyDown(keyCode: integer): boolean;
function IsAnyKeyDown: boolean;
function KeyDownStr: string;
procedure StopKeyboard;

{ https://stanislavs.org/helppc/int_16-3.html }
procedure SetKeyboardParams(typematicRate: byte; delay: byte; turnOffTypematic: boolean);

procedure ResetKeyboardParams;

implementation

var
	normalKeys: array[0..$5F] of byte; { $60 length }
	extendedKeys: array[0..$5F] of byte;
	initialized: boolean;
	OldInt09: Procedure;
	buffer: byte;

procedure QueueKeyboardEvent(scancode: integer; makeBreak: integer); forward;

{$F+}
Procedure NewInt09; Interrupt;
var
	rawcode, makeBreak, scanCode: byte;
Begin
	IrqOff;
	
	rawcode := port[$60];
	
	{ bit 7: 0 = make, 1 = break }
	if rawcode and $80 = 0 then makeBreak := 1
	else makeBreak := 0;
	{makeBreak := not (rawcode and $80);}
	scanCode := rawcode and $7F;
	
    if buffer = $E0 then { second byte of an extended key }
	begin	    
        if (scancode < $60) then 
		begin
            extendedKeys[scancode] := makeBreak;
			QueueKeyboardEvent(EXTENDED_SCANCODE_BASE + scancode, makeBreak);
        end;
		
        buffer := 0;
    end 
	else if (buffer >= $E1) and (buffer <= $E2) then { ignore these extended keys }
	begin
        buffer := 0;
    end 
	else if (rawcode >= $E0) and (rawcode <= $E2) then { first byte of an extended key }
	begin
        buffer := rawcode; 
    end 
	else if scancode < $60 then
	begin
        normalKeys[scanCode] := makeBreak;
		QueueKeyboardEvent(scancode, makeBreak);
    end;
		
	{chain old interrupt}
	OldInt09;
	
	IrqOn;
	
	Port[$20]:=$20; {Sends non-specific EOI to the PIC}	
End;
{$F-}

procedure InitKeyboard;
begin
	if initialized then exit;
	
	GetIntVec($09, @OldInt09);
	SetIntVec($09, Addr(NewInt09));
	
	initialized := true;
end;

function IsKeyDown(keyCode: integer): boolean;
begin
	if (keyCode < Low(normalKeys)) or (keyCode > High(normalKeys)) then 
	begin
		IsKeyDown := false;
		exit;
	end;
	
	IsKeyDown := normalKeys[keyCode] > 0;
end;

function IsXKeyDown(keyCode: integer): boolean;
begin
	if (keyCode < Low(extendedKeys)) or (keyCode > High(extendedKeys)) then 
	begin
		IsXKeyDown := false;
		exit;
	end;
	
	IsXKeyDown := extendedKeys[keyCode] > 0;
end;

function KeyDownStr: string;
var
	i: integer;
	iStr: string;
begin
	for i:=Low(normalKeys) to High(normalKeys) do
	begin
		if normalKeys[i] <> 0 then 
		begin
			str(i, iStr);
			KeyDownStr := iStr;
			exit;
		end;		
	end;
	
	for i:=Low(extendedKeys) to High(extendedKeys) do
	begin
		if extendedKeys[i] <> 0 then 
		begin
			str(i, iStr);
			KeyDownStr := iStr + '(x)';
			exit;
		end;		
	end;
	
	KeyDownStr := '';
end;

function IsAnyKeyDown: boolean;
var
	i: integer;
begin
	for i:=Low(normalKeys) to High(normalKeys) do
	begin
		if normalKeys[i] <> 0 then 
		begin
			IsAnyKeyDown := true;
			exit;
		end;		
	end;
	
	for i:=Low(extendedKeys) to High(extendedKeys) do
	begin
		if extendedKeys[i] <> 0 then 
		begin
			IsAnyKeyDown := true;
			exit;
		end;		
	end;
	
	IsAnyKeyDown := false;
end;

procedure StopKeyboard;
begin
	if not initialized then exit;
	
	SetIntVec($09, Addr(OldInt09));
end;
	
procedure QueueKeyboardEvent(scancode: integer; makeBreak: integer);
var
	event: TEvent;
begin
	if makeBreak > 0 then event.eventType := EventType.KeyDown
	else event.eventType := EventType.KeyUp;
	
	event.key := scancode;
	
	QueueEvent(event);
end;	

procedure SetKeyboardParams(typematicRate: byte; delay: byte; turnOffTypematic: boolean);
begin
	{ TODO range check for params }
	asm
		mov ah, 3;
		mov al, 5;
		mov bh, delay;
		mov bl, typematicRate;
		int $16;
	end;
	
	if turnOffTypematic then begin	
		asm
			mov ah, 3;
			mov al, 4;
			int $16;
		end;
	end;
end;

procedure ResetKeyboardParams;
begin
	asm
		mov ah, 3;
		mov al, 0;
		int $16;
	end;
end;

begin
end.