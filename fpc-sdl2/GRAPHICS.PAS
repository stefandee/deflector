unit Graphics;
{$G+}

interface

uses 
	Dos,
	Crt,
	Math,
	SDL2,	
	SDL2_image,
	SDLWrapper,
	Logger,
	ResourceDef,
	SysUtils,
	SDL2_ttf,
	ColorDef,
	MathEx;

const
	HCENTER = $01;
	VCENTER = $02;
	RIGHT   = $04;
	BOTTOM  = $08;

Type 
     Tspr    = record
             xl,yl:LongInt;
             pspr: PSDL_Texture;
			 surface: PSDL_Surface;
             end;


     point   = record
             x,y:integer;
             end;
     triangle= record
             a,b,c : point;
             d     : real;
             col   : byte;
             end;

Var 
    Spr         : array [1..255] of tspr;
	FontMenu    : PTTF_Font;
	FontGameUI  : PTTF_Font;

procedure Putpixel(x,y:word;color:LongWord; renderer: PSDL_Renderer);
function  Getpixel(x,y:word;where:word):byte; { NOT IMPLEMENTED }
procedure Line(x1,y1,x2,y2:integer;color:LongWord; renderer: PSDL_Renderer);
procedure Rectangle(xi,yi,xf,yf:integer;color:LongWord; renderer: PSDL_Renderer);
procedure Bar(xb,yb,xf,yf:integer;color:byte; renderer: PSDL_Renderer);

procedure FadeOut(duration:longint; renderer: PSDL_Renderer = nil);

procedure Cls(Color : LongWord; renderer: PSDL_Renderer = nil);
procedure Flip;

{sprite procedures...}
procedure Loadspr(nume:string; nr:byte; renderer: PSDL_Renderer);
procedure Putspr(nr:byte; x1, y1:integer; mode:TSDL_BlendMode; renderer: PSDL_Renderer);
{function SprColor(nr: byte; x,y:integer): LongWord;}
function IsSprPixelTransparent(nr: byte; x,y:integer): boolean;
procedure DoneSpr(nr:byte);
procedure DoneAllSpr;

procedure TextSize(str : string; font: PTTF_Font; out w: Integer; out h : Integer);
procedure OutTextXY(x, y : Integer; str : string; font: PTTF_Font; color: LongWord; align : integer; renderer: PSDL_Renderer);
procedure OutIntXY(x, y : Integer; v:longint; font: PTTF_Font; color: LongWord; align : integer; renderer: PSDL_Renderer);

implementation

{ get alpha component from a ARGB color }
function GetA(color: LongWord): UInt8; forward;

{ get red component from a ARGB color }
function GetR(color: LongWord): UInt8; forward;

{ get green component from a ARGB color }
function GetG(color: LongWord): UInt8; forward;

{ get blue component from a ARGB color }
function GetB(color: LongWord): UInt8; forward;

procedure Putpixel(x,y:word;color:LongWord; renderer: PSDL_Renderer);
begin
	if renderer = nil then renderer := SDLRenderer;
	
	SDL_SetRenderDrawColor(renderer, GetR(color), GetG(color), GetB(color), GetA(color));
	SDL_RenderDrawPoint(renderer, x, y);
end;

function Getpixel(x,y:word;where:word):byte;
begin
end;

procedure Line(x1,y1,x2,y2:integer;color:LongWord; renderer: PSDL_Renderer);
begin
	if renderer = nil then renderer := SDLRenderer;
	
	SDL_SetRenderDrawColor(renderer, GetR(color), GetG(color), GetB(color), GetA(color));
	SDL_RenderDrawLine(renderer, x1, y1, x2, y2);
end;

procedure Rectangle(xi,yi,xf,yf:integer;color:LongWord; renderer: PSDL_Renderer);
var
	rect: TSDL_RECT;
begin
	rect.x := Min(xi, xf);
	rect.y := Min(yi, yf);
	rect.w := Abs(xi - xf) + 1;
	rect.h := Abs(yi - yf) + 1;
	
	if renderer = nil then renderer := SDLRenderer;

	SDL_SetRenderDrawColor(renderer, GetR(color), GetG(color), GetB(color), GetA(color));
	SDL_RenderDrawRect(renderer, @rect);	
end;

procedure Bar(xb,yb,xf,yf:integer;color:byte; renderer: PSDL_Renderer);
var
	rect: TSDL_RECT;
begin
	rect.x := Min(xb, xf);
	rect.y := Max(yb, yf);
	rect.w := Abs(xb - xf) + 1;
	rect.h := Abs(yb - yf) + 1;

	if renderer = nil then renderer := SDLRenderer;
	
	SDL_SetRenderDrawColor(renderer, GetR(color), GetG(color), GetB(color), GetA(color));
	SDL_RenderFillRect(renderer, @rect);	
end;

procedure Cls(Color : LongWord; renderer: PSDL_Renderer);
BEGIN
	if renderer = nil then renderer := SDLRenderer;
	
	SDL_SetRenderDrawColor(renderer, GetR(color), GetG(color), GetB(color), GetA(color));
	SDL_RenderClear(renderer);
END;

procedure Flip;
begin
    SDL_RenderPresent(SdlRenderer);
end;

Procedure Loadspr(nume:string; nr:byte; renderer: PSDL_Renderer);
begin
	if renderer = nil then renderer := SDLRenderer;
	
	{Log.LogStatus(Format('Loadspr: %s at index %d', [nume, nr]), 'Graphics');}
	
	DoneSpr(nr);
	
	with spr[nr] do
	begin		 	
		surface := IMG_Load(PChar(TexturesPath(nume)));

		if surface = nil then
		begin
			Log.LogError(Format('Cannot create surface %s', [SDL_GetError]), 'Graphics');
			exit;
		end;
		
		pspr := SDL_CreateTextureFromSurface(renderer, surface);
		
		if pspr = nil then
		begin
			SDL_FreeSurface(surface);
			
			Log.LogError(Format('Cannot create texture from surface %s', [SDL_GetError]), 'Graphics');
			exit;
		end;
			
		if SDL_QueryTexture(pspr, nil, nil, @xl, @yl) < 0 then
		begin
			Log.LogError(Format('SDL_QueryTexture failed with error %s', [SDL_GetError]), 'Graphics');
		end;
		
		{Log.LogStatus(Format('Texture size is %dx%d', [xl, yl]), 'Graphics');}
	end;
end;

Procedure Putspr(nr:byte;x1,y1:integer; mode:TSDL_BlendMode; renderer: PSDL_Renderer);
var
	dstRect: TSDL_RECT;
	srcRect: TSDL_RECT;
	prevMode: TSDL_BlendMode;
begin
	if renderer = nil then renderer := SDLRenderer;
	
	with spr[nr] do
	begin
		if pspr = nil then 
		begin
			Log.LogError('Putspr %d - texture is nil', 'Graphics');
			exit;
		end;
		
		dstRect.x := x1;
		dstRect.y := y1;
		dstRect.w := xl;
		dstRect.h := yl;
		
		srcRect.x := 0;
		srcRect.y := 0;
		srcRect.w := xl;
		srcRect.h := yl;
		
		SDL_GetTextureBlendMode(pspr, @prevMode);
		SDL_SetTextureBlendMode(pspr, mode);
		
		SDL_RenderCopy(renderer, pspr, @srcRect, @dstRect);
		
		SDL_SetTextureBlendMode(pspr, prevMode);
	end;  
end;

procedure DoneSpr(nr:byte);
begin
	with spr[nr] do
	begin
		if pspr <> nil then SDL_DestroyTexture(pspr);
		pspr := nil;
		
		if surface <> nil then SDL_FreeSurface(surface);
		surface := nil;
	end;
end;

procedure DoneAllSpr;
var
	i: integer;
begin
	for i := Low(spr) to High(spr) do
		DoneSpr(i);
end;

procedure OutTextXY(x, y : Integer; str : string; font: PTTF_Font; color: LongWord; align : integer; renderer: PSDL_Renderer);
var
	DestRect : TSDL_Rect;
	strW, strH : LongWord;
	sdlSurface: PSDL_Surface;
	sdlTexture: PSDL_Texture;
	fontColor: TSDL_Color;
begin
	if (font = nil) then exit;

	if renderer = nil then renderer := SDLRenderer;

	if align > 0 then 
	begin
		TTF_SizeText(font, PChar(str), @strW, @strH);

		if (align and HCENTER <> 0) then x := x - strW div 2;

		if (align and VCENTER <> 0) then y := y - strH div 2;

		if (align and RIGHT <> 0) then x := x - strW;

		if (align and BOTTOM <> 0) then y := y - strH;
	end;

	fontColor.r := GetR(color);
	fontColor.g := GetG(color);
	fontColor.b := GetB(color);
	fontColor.a := GetA(color);

	{ get the surface }
	{ this is not very efficient, as it creates a surface and a texture each time it renders text }
	{ for static text labels, consider pre-render them, only dynamic text should use this method }
	{ alternatively, cache all glyphs, but probably we will lose ttf rendering capabilities }
	{sdlSurface := TTF_RenderText_Blended(font, PChar(str), fontColor);}
	sdlSurface := TTF_RenderText_Solid(font, PChar(str), fontColor);

	if (sdlSurface = nil) then 
	begin
		Log.LogError('Cannot create font surface', 'Graphics');
		exit;
	end;

	sdlTexture := SDL_CreateTextureFromSurface(renderer, sdlSurface);
	SDL_SetTextureAlphaMod(sdlTexture, 255);

	DestRect.x := x;
	DestRect.y := y;
	DestRect.w := sdlSurface^.w;
	DestRect.h := sdlSurface^.h;

	SDL_RenderCopy(renderer, sdlTexture, nil, @DestRect);
	
	SDL_FreeSurface(sdlSurface);
	SDL_DestroyTexture(sdlTexture);		
end;

procedure TextSize(str : string; font: PTTF_Font; out w: Integer; out h : Integer);
begin
	TTF_SizeText(font, PChar(str), @w, @h);
end;

procedure OutIntXY(x, y : Integer; v:longint; font: PTTF_Font; color: LongWord; align : integer; renderer: PSDL_Renderer);
var s:string;
begin
str(v,s);
outtextxy(x,y,s,font,color, align,renderer);
end;

procedure FadeOut(duration:longint; renderer: PSDL_Renderer = nil);
var
	texture: PSDL_Texture;
	surface: PSDL_Surface;
	alpha: longint;
	timestamp: longint;
	logicalW, logicalH: longint;
begin
	if duration <= 0 then exit;

	if renderer = nil then renderer := SDLRenderer;
	
	SDL_GetRendererOutputSize(renderer, @logicalW, @logicalH);
	
	surface := SDL_CreateRGBSurfaceWithFormat(0, logicalW, logicalH, 32, SDL_PIXELFORMAT_ARGB8888);
	
	if surface = nil then
	begin
		Log.LogStatus(Format('SDL_CreateRGBSurfaceWithFormat failed with error %s', [SDL_GetError]), 'Fadeout');
		exit;
	end;
	
	SDL_RenderReadPixels(renderer, nil, surface^.format^.format, surface^.pixels, surface^.pitch);
	
	texture := SDL_CreateTextureFromSurface(renderer, surface);
	
	if texture = nil then
	begin
		Log.LogStatus(Format('SDL_CreateTextureFromSurface failed with error %s', [SDL_GetError]), 'Fadeout');
		
		SDL_FreeSurface(surface);
		exit;
	end;	
	
	SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND);
	
	Cls(COLOR_BLACK, renderer);
	
	timestamp := SDL_GetTicks;
	
	while SDL_GetTicks - timestamp <= duration do
	begin
		Cls(COLOR_BLACK, renderer);
		
		alpha := Math.Max(0, Math.Min((255 * (SDL_GetTicks - timestamp)) div duration, 255));
		
		SDL_SetTextureAlphaMod(texture, 255 - alpha);
		SDL_RenderCopy(renderer, texture, nil, nil);
		Flip;
	end;
	
	SDL_FreeSurface(surface);
	SDL_DestroyTexture(texture);
end;

function IsSprPixelTransparent(nr: byte; x,y:integer): boolean;
var
	bpp: UInt8;
	pixelsUInt8: PUInt8;
	pixelData: UInt32;
	color: TSDL_Color;
begin
	IsSprPixelTransparent := true;
	
	with spr[nr] do
	begin
		if surface <> nil then
		begin
			x := Clamp(x, 0, xl - 1); 
			y := Clamp(y, 0, yl - 1);
						
			bpp := surface^.format^.BytesPerPixel;

			{
			compute the address of a pixel on a SDL_Surface
			
			surface^.pixels	= an array containing the SDL_Surface' pixels
			surface^.pitch		= the length of a row of pixels (in bytes)
			x and y				= the offset on where on the image to retrieve the pixel, (0, 0) is in the upper left corner of the image
			}
			
			SDL_LockSurface(surface);
			
			pixelsUInt8 := PUint8(surface^.pixels) + y * surface^.pitch + x * bpp;

			pixelData := PUInt32(pixelsUInt8)^;
			
			SDL_UnlockSurface(surface);

			{ Retrieve the RGB values of the specific pixel }
			SDL_GetRGBA(pixelData, surface^.format, @color.r, @color.g, @color.b, @color.a);
			
			IsSprPixelTransparent := (color.a = 0);		
		end;
	end;
end;

function GetA(color: LongWord): UInt8;
begin
	GetA := (color and $FF000000) shr 24;
end;

function GetR(color: LongWord): UInt8;
begin
	GetR := (color and $FF0000) shr 16;
end;

function GetG(color: LongWord): UInt8;
begin
	GetG := (color and $00FF00) shr 8;
end;

function GetB(color: LongWord): UInt8;
begin
	GetB := (color and $FF);
end;

begin
end.