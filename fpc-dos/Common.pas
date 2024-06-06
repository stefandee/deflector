unit Common;

interface

Procedure IrqOn;
Procedure IrqOff;

implementation

Procedure IrqOn;
begin
	asm
		sti;
	end;
end;

Procedure IrqOff;
begin
	asm
		cli;
	end;
end;

begin
end.