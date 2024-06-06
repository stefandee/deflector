Program Play_Voc3;
{ Demonstrates the use of SB_Unit by playing a VOC file from disk using DMA }
{ double-buffering.                                                         }

{ Options to this program are given if it is used without parameters. Only  }
{ .VOC files with a single block of data are supported; others may also     }
{ work, but any block information will be output as voice data.             }
{ Also, samples at rates > 22.05kHz seem to use a header format I don't     }
{ have information about. The program flags these and displays an error.    }

Uses CRT,DOS,SbDSP;

Const
   DEFAULT_BUFFER : word = 1000; { $8000; }
   DEFAULT_IRQ : byte = 7;
   DEFAULT_DMA : byte = 1;

Var
   FileStr : String[80];                  { Filename parameter string.      }
   FileName : Array[1..80] of char;       { ASCIZ converted filename.       }
   Loop : integer;                        { Misc. loop counter.             }
   FullFilename : boolean;                { Flag for filename extension.    }
   FileHandle : word;                     { File handle (returned by DOS).  }
   Buffer1, Buffer2 : pointer;            { Double buffers.                 }
   Size : word;                           { Size of disk read.              }
   ReadError : byte;                      { Disk read error code.           }
   Base : word;                           { Base address of card.           }
   IRQ,                                   { Card IRQ.                       }
   DMA : byte;                            { Card DMA channel.               }
   Blaster,                               { "BLASTER" environment variable. }
   Param : string[20];                    { Command line parameter.         }
   Err : integer;                         { "Val" function error code.      }
   BufferSize : word;                     { Size of buffers.                }
   VOCHeader : Array[0..18] of char;      { Header for VOC file.            }
   SampleRate : word;                     { Playback rate (in Hz).          }
   
   f : file;
   FileLen: Word;
   psnd: pointer;

Procedure Instructions;
{ Outputs instructions for command line usage.                              }
   Begin
      Writeln('Usage : PLAY_VOC <filename>[.VOC] [options]');
      Writeln;
   end;


Procedure ReadBuffer(Handle : word; Buffer : pointer; Var Size : word;
                     Var Error : byte);
      assembler;
{ Reads Size bytes from file Handle into Buffer. Size returns with the      }
{ actual number of bytes read, and Error returns with error code (if any).  }

      asm
         cld                              { Forward string moves.           }
         push  ds                         { Can't modify ds.                }
         mov   ax,word ptr Buffer+2       { Segment of Buffer pointer.      }
         mov   ds,ax
         mov   dx,word ptr Buffer         { Offset of Buffer pointer.       }
         mov   bx,Handle                  { bx = File handle.               }
         mov   es,word ptr Size+2         { es:si -> Size                   }
         mov   si,word ptr Size
         mov   di,word ptr Error          { <seg>:di -> Error               }
         mov   cx,es:[si]                 { cx = Size.                      }
         mov   ah,3Fh                     { DOS - read from file.           }
         int   21h
         jnc   @@Success
         @@Fail:
            mov   es,word ptr Error+2     { Return error code.              }
            mov   es:[di],al
            jmp   @@Finish
         @@Success:
            mov   es:[si],ax              { Return actual number read.      }
            mov   es,word ptr Error+2
            mov   al,0                    { No error.                       }
            mov   es:[di],al
         @@Finish:
            pop   ds
      end;


Procedure SwapBuffers(Var BufferA, BufferB : pointer);
   Var
      Temp : pointer;
   Begin
      Temp := BufferA;
      BufferA := BufferB;
      BufferB := Temp;
   end;


Begin
   ClrScr;

   { If no command line parameters, output instructions and exit. }
   If (ParamCount = 0)
      then
         Begin
            Instructions;
            Halt(1);
         end;

   { Convert Pascal-style filename string to null-terminated. }
   FullFilename := FALSE;
   FileStr := ParamStr(1);
   For Loop := 1 to Ord(FileStr[0]) do
      Begin
         FileName[Loop] := FileStr[Loop];
         If FileName[Loop] = '.'
            then
               FullFilename := TRUE;
      end;

   Inc(Loop);
   { If suffix not given, add .VOC. }
   If Not(FullFilename)
      then
         Begin
            FileName[Loop] := '.';
            Filename[Loop+1] := 'V';
            FileName[Loop+2] := 'O';
            Filename[Loop+3] := 'C';
            Inc(Loop,4);
         end;
   FileName[Loop] := #0;     { Null tail. }

   { Use DOS services to open the file and return a file handle. Block      }
   { reads can then be performed (much more efficient).                     }
   (*
   asm
      push  ds                         { Can't modify ds.                   }
      mov   ax,seg FileName
      mov   ds,ax
      mov   dx,offset FileName         { ds:dx -> ASCIZ filename.           }
      mov   ax,3D00h
      int   21h                        { DOS - open file.                   }
      jnc   @@Success
      @@Fail:
         mov   [ReadError],al          { Return the error code.             }
         jmp   @@Finish
      @@Success:
         mov   [FileHandle],ax         { Return the file handle.            }
         mov   [ReadError],0           { No error.                          }
      @@Finish:
         pop   ds
   end;

   { Check if given a valid filename. }
   If (ReadError <> 0)
      then
         Begin
            Writeln('Invalid filename: ',Paramstr(1));
            Halt(2);
         end;
   *)

   { Check if file is a .VOC. }
   
   (*
   Size := 19;
   ReadBuffer(FileHandle,@VOCHeader,Size,ReadError);
   If Not(VOCHeader = 'Creative Voice File')
      then
         Begin
            Writeln('Not a valid .VOC file.');
            Halt(2);
         end;

   { Read header data (see VOC-INFO.TXT for details). If the first block    }
   { is data, read the sample rate and blindly assume no headers follow.    }
   Size := 13;
   ReadBuffer(FileHandle,@VOCHeader,Size,ReadError);
   If (VOCHeader[7] = #1)
      then
         { First block is data - find sample rate. }
         SampleRate := word (VOCHeader[11])
      else
         Begin
            Writeln('Unable to play .VOC files of this type.');
            Halt(4);
         end;

   { File pointer is now positioned at start of data (hopefully?). }

	writeln('sample rate ', SampleRate);

   { Sample rate is in Blaster byte format - convert to Hz. }
   SampleRate := word (1000000 div (256 - SampleRate));
   *)
   
   writeln('opening ', FileStr);
   
InitSoundBlaster;
loadsound(FileStr,10);
playsound(10);

	repeat until KeyPressed;
end.
