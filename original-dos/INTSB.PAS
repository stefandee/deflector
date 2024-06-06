base:=0{220};volcnt:=8;
{resetdsp(2);}
for i:=1 to 9 do
      if resetdsp(i) then begin
                          base:=2*256+i*16;
                          break;
                          end;

if base=0 then begin
                 donevscreen;
                 donevga256;
                 writeln('No SoundBlaster available .');
                 meml[0:(9*4)]:=int9;
                 halt;
                 end;
