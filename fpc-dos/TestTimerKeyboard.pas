program TestTimerKeyboard;

uses 
	Graphics, 
	Crt,
	Keyboard,
	Timer,
	SysUtils,
	Events;

label exit;

var 
	input: string;
	key: integer;
	getTicksStr: string;
	event: TEvent;
  
{$R-}

begin
    { init systems }
	InitTimer(41);
	InitKeyboard;
	
    vga256;
    initvscreen;
    
    loadpal('sprites.pal');
    setpal;	
	
	input := 'Text';
	
    repeat
		{key:=port[$60];	
		if key = 1 then goto exit;}
	
		cls(0, vaddr);
	
        {outtext(160 - length(input) * 8, 100, KeyDownStr, 4, 255, vaddr);}
		{str(GetTicks, getTicksStr);}
		getTicksStr := FormatFloat('000.000', GetTicks);
        outtext(0, 0, 'GetTicks: ' + getTicksStr, 4, 255, vaddr);    
		
		getTicksStr := FormatFloat('000.000', GetTimeElapsed / 1000);
        outtext(0, 10, 'GetTimeElapsed: ' + getTicksStr, 4, 255, vaddr);    
		
		str(EventQueueLength, input);
		outtext(160 - length(input) * 8, 80, input, 4, 255, vaddr);
		
		while (PollEvent(event)) do
		begin
			case event.eventType of
				EventType.KeyUp:
					begin
						str(event.key, input);
						outtext(160 - length(input) * 8, 90, 'KeyUp: ' + input, 4, 255, vaddr);
					end;
					
				EventType.KeyDown:
					begin
						if event.key = KEY_ESC then goto exit;
						
						str(event.key, input);
						outtext(160 - length(input) * 8, 100, 'KeyDown: ' + input, 4, 255, vaddr);
					end;
			end;
		end;
		
{asm mov ah,$0c
    mov al,$06
    mov dl,$ff
    int $21
end;}
		
		Flip;
		
	repeat
	until TimerTick;
	TimerTick := false;
		
    until false;
	
exit:	
    { shutdown systems }
    donevga256;
    donevscreen;    
	StopTimer;
	StopKeyboard;
	ClearEventQueue;
end.