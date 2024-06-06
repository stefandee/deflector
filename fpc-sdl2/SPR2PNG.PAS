{ converts .spr and their palette files to .png files }
{ this has only been done once, the spr files for the fpc-sdl2 project have been deleted }
{ if the conversion needs to be done again, use the spr files from the other versions of the game }

Program Spr2Png;

Uses 
	SDL2,
	GameDef,
	SDL2_image;
	
Type
     paltype = array[0..255,1..3] of byte; { 1 - red, 2 - green, 3 - blue }
	
Var i:integer;
    sprfname : string;
	workpal, pal: paltype;

procedure LoadPal(numef: string);

var
    result:word;
    fs:file;
begin
	writeln('loading palette ', numef);
    assign(fs,numef);
    reset(fs,1);
    blockread(fs,workpal,768,result);
    close(fs);
    move(workpal,pal,768);
end;
	
procedure Spr2Png(basesprfname: string);
var
    fs         : file;
	sprfname: string;
	xl, yl, x, y: word;
	pspr: ^byte;
	surface: PSDL_Surface;
	rmask, gmask, bmask, amask: longword;
	pixelIndex: longword;
	palIndex: byte;
	p: pointer;
	pixels: ^UInt32;
	pixelsUInt8: ^UInt8;
begin
	sprfname := DataPath(basesprfname+'.spr');
	
	assign(fs, sprfname);
	reset(fs,1);
	
	blockread(fs,xl,2);
	blockread(fs,yl,2);
	getmem(pspr,xl*yl);
	blockread(fs,pspr^,xl*yl);
			 
	close(fs);
	
	writeln(basesprfname, ' ', xl, 'x', yl);
	
{#if SDL_BYTEORDER == SDL_BIG_ENDIAN
    rmask = $ff000000;
    gmask = $00ff0000;
    bmask = $0000ff00;
    amask = $000000ff;
#else}
    rmask := $000000ff;
    gmask := $0000ff00;
    bmask := $00ff0000;
    amask := $ff000000;
{#endif}
	
	surface := SDL_CreateRGBSurface(0, xl, yl, 32, rmask, gmask, bmask, amask);
	{surface := SDL_CreateRGBSurface(0, xl, yl, 32, 0,0,0,0);}

	{ set the surface pixels! }
	pixelIndex := 0;
	
	pixels := PuInt32(surface^.pixels);
	pixelsUInt8 := PuInt8(surface^.pixels);
	
	writeln('surface^.format^.BytesPerPixel ', surface^.format^.BytesPerPixel);
	writeln('surface^.pitch ', surface^.pitch);
	
	for x := 0 to xl - 1 do
	begin
		for y := 0 to yl - 1 do
		begin
			palIndex := pspr[x + y * xl];
			pixelIndex := y * surface^.pitch + x * surface^.format^.BytesPerPixel;
						
			// dos vga mode x only had 64 values, so need shifting it 2 bits to the left
			pixelsUInt8[pixelIndex]     := workpal[palIndex, 1] shl 2;
			pixelsUInt8[pixelIndex + 1] := workpal[palIndex, 2] shl 2;
			pixelsUInt8[pixelIndex + 2] := workpal[palIndex, 3] shl 2;
			
			// add transparency - seems that pallete index 0 is black, which we can use as transparency for png
			if palIndex = 0 then
				pixelsUInt8[pixelIndex + 3] := 0
			else
				pixelsUInt8[pixelIndex + 3] := $FF;
			
			{pixels[y * xl + x] := (workpal[palIndex, 1]) or (workpal[palIndex, 2] shl 8) or (workpal[palIndex, 3] shl 16) or ($FF shl 24);}
		end;		
	end;
	
	IMG_SavePNG(surface, PChar(DataPath('/png/' + basesprfname + '.png')));
end;	
	
begin

if SDL_Init(SDL_INIT_VIDEO) < 0 then HALT;

loadpal(DataPath('sprites.pal'));

for i:=0 to 39 do
begin
    { file name }
	str(i, sprfname);	
	
	Spr2Png('spr' + sprfname);
end;	

loadpal(DataPath('MAINFRM.pal'));
Spr2Png('MAINFRM');

SDL_Quit;

end.

