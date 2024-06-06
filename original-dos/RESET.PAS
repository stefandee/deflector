uses graphics;
var f : file;
I : INTEGER;
begin
loadpal('chroma.pal');
for i:=0 to 255 do
    begin
    workpal[i,1]:=workpal[i,1] div 4;
    workpal[i,2]:=workpal[i,2] div 4;
    workpal[i,3]:=workpal[i,3] div 4;
    end;
assign(f,'mchroma.pal');rewrite(f,1);
blockwrite(f,workpal,768);
close(f);
end.