program char_set;

uses graphics,dos,crt;
var r:registers;
    s,o,u:word;
    i:integer;

begin
vga256;
loadpal('mainfrm.pal');setpal;
r.al:=$30;
r.bh:=2;
r.ah:=$11;
intr($10,r);
s:=r.es;o:=r.bp;
o:=o+14*66;{A}
asm
   push ax
   push bx
   push cx
   push dx
   push si
   push di
   push bp
   push ds
   push es

mov ax,s
mov es,ax
mov di,o
mov cx,0Eh
mov ax,$a000
mov ds,ax
mov bl,200
mov si,0
@1 :
   push cx
   mov cx,8
   mov al,es:[di]
   inc di
@3 :
   xor ah,ah
   shl ax,1
   and ah,1
   jz @2
   mov ds:[si],bl
@2 :
   inc si
   loop @3
   sub si,8
   add si,320
   pop cx
   loop @1

   pop es
   pop ds
   pop bp
   pop di
   pop si
   pop dx
   pop cx
   pop bx
   pop ax

end;
readln;

end.
