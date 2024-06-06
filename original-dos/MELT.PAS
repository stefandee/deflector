program meltdown;
uses graphics,crt;
const grain = 2;
var melt_table : array[1..320 div grain,1..2] of integer;
    i,j : integer;
    txt : string;
begin
vga256;
initvscreen;cls(0,vaddr);
loadpal('mainfrm.pal');setpal;
loadspr('mainfrm.spr',1);putspr(1,0,0,normalput,vaddr);
for i:=1 to 320 div grain do
    begin
    melt_table[i,1]:=0;
    melt_table[i,2]:=abs(round(10*sin(i)))+10;
    end;
txt:='METAL MELTDOWN !';
for i:=1 to 9 do
    begin
    for j:=1 to 320 div grain do
        if melt_table[j,2]+melt_table[j,1]<200
           then begin
                getimage(2,(j-1)*grain,melt_table[j,1],grain,199-melt_table[j,1],vaddr);
                bar((j-1)*grain,0,j*grain,200,0,vaddr);
                melt_table[j,1]:=melt_table[j,1]+melt_table[j,2];
                spr[2].yl:=spr[2].yl-melt_table[j,2];
                putspr(2,(j-1)*grain,melt_table[j,1],normalput,vaddr);
                donespr(2);
                end;
    flip;
    end;
outtext(160-length(txt)*4,40,txt,4,240,vga);
delay(2000);
fadeout(4);
end.

