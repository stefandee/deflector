unit MathEx;

interface

uses
	Math;

type
    TVector = record
		x, y: real;
    end;

function Clamp(n : longint; lower: longint; upper: longint): longint;
procedure Normalize(var v: TVector);

implementation

function Clamp(n : longint; lower: longint; upper: longint): longint;
begin
  Clamp := Math.Max(lower, Math.Min(n, upper));
end;

procedure Normalize(var v: TVector);
var
	len: real;
begin
	len := Sqrt(v.x * v.x + v.y * v.y);
	
	if IsZero(len) then exit;
	
	v.x := v.x / len;
	v.y := v.y / len;
end;

begin
end.