Program Play_Voc2;
{ Demonstrates the use of SB_Unit by playing a VOC file from disk using DMA }
{ double-buffering.                                                         }

{ Options to this program are given if it is used without parameters. Only  }
{ .VOC files with a single block of data are supported; others may also     }
{ work, but any block information will be output as voice data.             }
{ Also, samples at rates > 22.05kHz seem to use a header format I don't     }
{ have information about. The program flags these and displays an error.    }

Uses CRT,DOS,SB_Unit;

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
   
   assign(f, FileStr);
   reset(f,1);
   
   FileLen:=filesize(f);
   writeln('length ', FileLen);
   
   getmem(psnd, FileLen);
   
   blockread(f, psnd^, FileLen);

   close(f);
   
   SampleRate := 11025;

   { Set defaults for IRQ and DMA channel. These are used if nothing new    }
   { is defined.                                                            }
   Base := 0;              { If no other base address is found, autodetect. }
   IRQ := DEFAULT_IRQ;
   DMA := DEFAULT_DMA;
   BufferSize := DEFAULT_BUFFER;

   { Second source for settings : "BLASTER" environment variable. }
   Blaster := GetEnv('BLASTER');
   Err := 0;
   While (Blaster <> '') and (Err = 0) do
      Case Blaster[1] of
         'A','a' : Begin         { Base address. }
                      Val(Blaster[2]+Blaster[3]+Blaster[4],Base,Err);
                      Base := ((Base mod 200) div 10)*16 + 512;
                      If (Err = 0)
                        then
                           Blaster := Copy(Blaster,5,Length(Blaster)-4);
                   end;
         'I','i' : Begin         { IRQ }
                      Val(Blaster[2],IRQ,Err);
                      If (Err = 0)
                        then
                           Blaster := Copy(Blaster,3,Length(Blaster)-2);
                   end;
         'D','d' : Begin         { DMA channel. }
                      Val(Blaster[2],DMA,Err);
                      If (Err = 0)
                        then
                           Blaster := Copy(Blaster,3,Length(Blaster)-2);
                   end;
         else    { Step past extraneous characters. }
            Blaster := Copy(Blaster,2,Length(Blaster)-1);
      end;

   { Check command line switches. }
   For Loop := 2 to Paramcount do
      Begin
         Param := ParamStr(Loop);
         Case Param[2] of
            'A','a' : Begin
                         Val(Param[3]+Param[4]+Param[5],Base,Err);
                         Base := ((Base mod 100) div 10)*16 + 512;
                      end;
            'I','i' : Val(Param[3],IRQ,Err);
            'D','d' : Val(Param[3],DMA,Err);
            'B','b' : Begin
                         Case Length(Param) of
                            3 : Val(Param[3],BufferSize,Err);
                            4 : Val(Param[3],BufferSize,Err);
                            else
                               Err := 1;
                         end;
                         If ((BufferSize < 1) OR (BufferSize > 64))
                           then
                              Err := 1
                           else
                              BufferSize := (BufferSize-1)*$400 + $3F0;
                      end;
            else
               Err := 1;
            end;
         If (Err <> 0)
            then
               Begin
                  Writeln('Invalid switch : ',Param);
                  Halt(3);
               end;
      end;

   If (Base = 0)
      then
         SB_DetectBase(Base);

   { Correct Base address, IRQ, DMA channel, and buffer size found. }

   SB_SetBaseAddr(Base);
   If Not(SB_DSPReset(Base))
      then
         Begin
            Writeln('Unable to initialize Sound Blaster.');
            Halt(4);
         end;

   writeln('Blaster Env: ', Blaster);
   writeln('Base: ', Base, ' ', 'IRQ: ', IRQ, ' ', 'DMA: ', DMA);	 
   
   SB_SetIRQ(IRQ);
   SB_SetDMAChannel(DMA);

   { Reset DSP (only necessary if not autodetected). }
   SB_DSPReset(Base);

   { Set speaker on for output. }
   SB_Speaker(1);

   { Since using DMA, set the interrupt handler. }
   SB_SetIntHandler;
   
   { Create two buffers - one will be filled with data from disk while the  }
   { other plays.                                                           }

   { Ready to start playing. }
   Writeln('Press any key to end playing...');
   Writeln;

   SB_DMAComplete := FALSE;

   SB_PlayDMA(PSnd,SampleRate,FileLen);     

   { Wait for final buffer to finish playing. }
   Repeat
   {Until ((SB_DMAComplete) OR (Keypressed));}
   Until ( (Keypressed));

   { Needed for an abort, but can't hurt either way. }
   SB_StopDMA;

   If (Keypressed)
      then
         Writeln('Playback aborted.')
      else
         Writeln('Playback complete.');


   { That's it. Do some routine cleaning. }
   { After an aborted transfer, always reset the DSP before other functions.}
   SB_DSPReset(Base);
   SB_Speaker(0);

   SB_ResetIntHandler;

end.
