Unit SB_Unit;           { Version 1.0     January, 1993 }

{ Includes procedures for controlling a Sound Blaster or compatible card in }
{ direct or DMA mode.                                                       }
{ Notice how all the procedures start with SB_ - just begging for an OOP    }
{ implementation, huh?                                                      }


{ ******************** Obligatory Legal Stuff ***************************** }
{     This package is public domain. Use it, distribute it, and modify it.  }
{     This was written without the SBDK, so the information contained       }
{     within may be false - live with it or lend me $100 to get the kit.8-) }
{ ************************************************************************* }


{ Important Sound Blaster ports:                                            }
{     Base+05h : DSP Reset                   (write only)                   }
{     Base+0Ah : DSP Read Data               (read only)                    }
{     Base+0Ch : DSP Write Data or Command   (write only)                   }
{                DSP Write Buffer Status     (read only)                    }
{     Base+0Eh : DSP Data Available Status   (read only)                    }

Interface

Uses CRT,DOS,Memory,Common;

{ Global variables. }
Var
   SB_DMAComplete : boolean;       { Set to TRUE on DMA transfer completion }


{ ------ Control procedure declarations ----------------------------------- }

{ Initially, a call to SB_DetectBase is all that is needed to detect and    }
{ initialize the card. SB_DSPReset is made available in case it is needed   }
{ to reset the card later (after an aborted transfer, for example).         }
{ In case of an error in SB_DetectBase, SB_SetBaseAddr is available.        }

Function SB_DSPReset(BaseAddr : word) : boolean;
{ Resets Sound Blaster DSP at I/O BaseAddr. Returns TRUE if successful.     }

Procedure SB_DetectBase(Var BaseAddr : word);
{ Detects the base address of the Sound Blaster and returns it to BaseAddr. }
{ (Uses SB_DSPReset, so Blaster is automatically initialized when detected.)}

Procedure SB_SetBaseAddr(BaseAddr : word);
{ Sets the base address to BaseAddr. Use this if SB_DetectBase fails for    }
{ some reason (although I've never seen it fail). This can also be used to  }
{ implement a command-line switch, for example (/a210 , etc.).              }

Procedure SB_SetIRQ(IRQ : byte);
{ Manually sets the Sound Blaster IRQ.                                      }

Procedure SB_SetDMAChannel(DMA : byte);
{ Manually sets the Sound Blaster DMA Channel.                              }

Procedure SB_Speaker(Toggle : byte);
{ Toggles the DAC->speaker connection. Toggle=0 sets speaker off, any       }
{ other value turns it on.                                                  }


{ ------ Direct port transfer procedure declarations ---------------------- }

Procedure SB_SampleByte(Var InByte : byte);
{ Samples a single byte from the microphone input and returns it to InByte. }
{ *Note: The sound blaster speaker MUST be turned off for it to sample any  }
{        data - this is done through the SB_Speaker procedure.              }

Procedure SB_PlayByte(OutByte : byte);
{ Sends OutByte through the Sound Blaster DAC.                              }
{ *Note: The sound blaster speaker MUST be turned on for any sound to be    }
{        heard - this is done through the SB_Speaker procedure.             }


{ ------ DMA transfer procedure declarations ------------------------------ }

Procedure SB_MakeDMABuffer(Var Buffer : pointer; Size : word);
{ Creates a memory buffer for DMA use. See procedure body for detail.       }

Procedure SB_FreeDMABuffer(Buffer : pointer; Size : word);
{ Disposes of the memory allocated by SB_MakeDMABuffer.                     }

Procedure SB_SetIntHandler;
{ Sets the custom interrupt handler - required before any DMA transfers.    }

Procedure SB_ResetIntHandler;
{ Resets the interrupt handler to the previous routine.                     }

Procedure SB_PlayDMA(Buffer : pointer; Rate : word; Length : word);
{ Outputs a buffer of data (indicated by Buffer) to the Sound Blaster at    }
{ Rate (in Hz) and Length (in bytes) using DMA.                             }

Procedure SB_SampleDMA(Buffer : pointer; Rate : word; Length : word);
{ Reads a buffer of data (indicated by Buffer) from the Sound Blaster at    }
{ Rate (in Hz) and Length (in bytes) using DMA.                             }
{ ***************** This procedure doesn't work. Sorry. ******************* }

Procedure SB_StopDMA;
{ Stops the DMA transfer immediately.                                       }


{ ------------------------------------------------------------------------ }

Implementation

{ Defined variables. These are assigned with calls to various routines. See }
{ end of unit for default assignments.                                      }

Var
   { Set on call to SB_DetectBase and SB_SetBaseAddr. Default=22xh.         }
   ReadPort,                           { DSP Read Data port (2xAh).         }
   WritePort,                          { DSP Write Data or Command port     }
                                       { (2xCh).                            }
   DataPort : word;                    { DSP Data Available port (2xEh).    }

   { Set on call to SB_SetIRQ. Default=5. }
   SB_Int : byte;                      { Interrupt number (IRQ+8).          }

   DMAChannel : byte;                  { DMA channel for Blaster.           }
   OldIntHandler : pointer;            { Storage for old interrupt routine. }


{ ------ Control procedures ----------------------------------------------- }

Function SB_DSPReset(BaseAddr : word) : boolean;
{ Resets the Sound Blaster DSP - necessary whenever any major changes are   }
{ made to its function. BaseAddr is the base address (210h,220h,etc.)       }
{ Returns TRUE if successful, FALSE otherwise.                              }

{ The procedure here is as follows:                                         }
{     1. Pulse the DSP reset port (2x6h). This involves sending a 1, a      }
{        delay, then sending a 0. (Length of delay is suggested at 1msec;   }
{        using a larger value will ensure compatibility with faster         }
{        processors. Speed here is usually not critical but experiment for  }
{        best results if required.)                                         }
{     2. Continue reading from the DSP Read Data port (2xAh) until 0AAh is  }
{        returned or the counter expires. If 0AAh is returned, the card     }
{        reset was succesful; if not, the base address must be incorrect    }
{        or the reset delay (step 1) too short. The counter is used to      }
{        prevent lockup - if the Blaster does not respond with 0AAh after   }
{        about 1000 (arbitrary) reads, take action to return an error.      }

   Var
      Counter : integer;               { Counter for port reads.            }

   Begin
      { Pulse DSP Reset }
      Port[BaseAddr+6] := 1;           { Begin pulse to port 2x6h.          }
      Delay(15);                       { I use 15 msec; experiment if you   }
                                       { want more speed.                   }
      Port[BaseAddr+6] := 0;           { End pulse to port 2x6h.            }

      { Loop until DSP Read Data returns 0AAh or counter expires.           }
      Counter := 1000;                 { Use whatever you want - 1000 is    }
                                       { a safety for faster processors.    }

      { Loop until port 2xAh returns 0AAh or counter expires.               }
      Repeat
         Dec(Counter);
      Until ((Port[BaseAddr+$0A] = $AA) OR (Counter = 0));
      { Incidentally, this loop never iterates more than 10 times on my     }
      { 386/33 - 1000 is obviously overkill, but (like I mentioned before)  }
      { timing for this procedure isn't very significant.                   }

      SB_DSPReset := Not(Counter = 0); { Return TRUE if successful.         }

   end; { End SB_DSPReset. }


Procedure SB_DetectBase(Var BaseAddr : word);
{ Detects the base I/O address of the Sound Blaster card and returns it to  }
{ BaseAddr. If none detected, returns 0. Card is automatically initialized  }
{ as part of the detection routine.                                         }

{ Procedure: Checks the result of SB_DSPReset for I/O addresses 210h to 260h}
{            and returns the correct address.                               }

   Begin
      BaseAddr := $210;                { Start at first possible I/O port.  }

      { Try to reset each address until successful or overshot. }
      While ((BaseAddr < $270) AND (Not(SB_DSPReset(BaseAddr)))) do
         Inc(BaseAddr,$10);

      { Return 0 if none found. }
      If (BaseAddr = $270)
         then
            BaseAddr := 0
         else
            SB_SetBaseAddr(BaseAddr);
            { Procedure to set internal variables already exists, so use it.}

   end; { End SB_DetectBase. }


Procedure SB_SetBaseAddr(BaseAddr : word);
{ Sets internal variables relative to the given base address of the card.   }

   Begin
      ReadPort := BaseAddr + $0A;      { DSP Read Data port.                }
      WritePort := BaseAddr + $0C;     { DSP Write Data or Command.         }
      DataPort := BaseAddr + $0E;      { DSP Data Available port.           }
   end;


Procedure SB_SetIRQ(IRQ : byte);
{ Sets the internal IRQ variable to the IRQ of the card.                    }
   Begin
      SB_Int := IRQ + 8;
   end;


Procedure SB_SetDMAChannel(DMA : byte);
{ Sets the internal DMA channel variable to the card's DMA channel.         }
   Begin
      DMAChannel := DMA;
   end;


Procedure SB_Speaker(Toggle : byte);
{ Toggles the DAC->speaker connection. Toggle=0 sets speaker off, any       }
{ other value turns it on.                                                  }

{ Procedure :                                                               }
{     1. Standard check is made to see if the Sound Blaster is ready for    }
{        input - read DSP Write Buffer status port (2xCh) until MSB (bit 7) }
{        is 0. (Notice port 2xCh has different functions when written to    }
{        and when read.)                                                    }
{     2. Send the speaker status byte to the DSP Write Data or Command port }
{        (2xCh). D1h=speaker connected (on), D3h=speaker disconnected (off) }

   Begin
      { Loop until MSB of port 2xCh is 0. }
      Repeat
      Until ((Port[WritePort] AND $80) = 0);

      If (Toggle = 0)
         then
            Port[WritePort] := $D3  { off }
         else
            Port[WritePort] := $D1; { on }
   end;



{ ------ Direct port transfer procedures ---------------------------------- }

Procedure SB_SampleByte(Var InByte : byte);
{ Samples a single byte from the microphone input and returns it to InByte. }
{ *Note: The Sound Blaster speaker must be turned OFF for any data to be    }
{        sampled.                                                           }

{ Procedure to sample a byte of data :                                                              }
{     1. Standard poll to see if the Blaster is ready to receive data -     }
{        read the Write Buffer Status port (2xCh) until the MSB is 0.       }
{     2. Send 20h ("Read" command) to DSP Write Command port (2xCh).        }
{     3. Read the DSP Data Available port (2xEh) until MSB (bit 7) is set.  }
{        *Note how this differs from the standard SB ready polling.         }
{     4. The sampled byte is then ready. Read it from the DSP Read Data     }
{        port (2xAh).                                                       }

   Begin
      { Loop until SB ready to receive data. }
      Repeat
      Until ((Port[WritePort] AND $80) = 0);

      Port[WritePort] := $20;          { Send 20h to port 2xCh.             }

      { Loop until bit 7 of port 2xEh is set. }
      Repeat
      Until ((Port[DataPort] AND $80) > 0);

      InByte := Port[ReadPort];        { Read data byte from port 2xAh.     }
   end;


Procedure SB_PlayByte(OutByte : byte);
{ Sends OutByte through the Sound Blaster DAC.                              }
{ *Note: The sound blaster speaker must be turned ON for any sound to be    }
{        heard - this is done through the SB_Speaker procedure.             }

{ Procedure to output a byte of data :                                      }
{     1. Standard poll to see if the Blaster is ready to receive data -     }
{        read the Write Buffer Status port (2xCh) until the MSB is 0.       }
{     2. Write 10h ("Write" command) to DSP Write Command port (2xCh).      }
{     3. Poll again, same as in step 1, to wait to send data.               }
{     4. Send the data byte to the DSP Write Data port (2xCh).              }

   Begin
      { Loop until SB ready to receive data. }
      Repeat
      Until ((Port[WritePort] AND $80) = 0);

      Port[WritePort] := $10;          { Send 10h to port 2xCh.             }

      { Loop until SB ready to receive data. }
      Repeat
      Until ((Port[WritePort] AND $80) = 0);

      Port[WritePort] := OutByte;      { Send data byte to port 2xCh.       }
   end;



{ ------ DMA transfer procedures ------------------------------------------ }

Procedure SB_MakeDMABuffer(Var Buffer : pointer; Size : word);
{ Creates a buffer of Size paragraphs which does not cross a page boundary  }
{ and assigns Buffer to the start. If the required amount of memory is not  }
{ available, Buffer is assigned nil.                                        }
{ This uses MemAllocSeg instead of MemAlloc to make calculations simpler,   }
{ sacrificing a possible 15 bytes.                                          }

{ Theory: The DMA controller cannot transfer over memory page boundaries;   }
{ ie. It is limited to 0000:0000 - 0000:FFFF (page 0),1000:0000 - 1000:FFFF }
{ (page 1), etc. To avoid unnecessary hardship in the transfer routines,    }
{ the DMA buffer should be in a single page. This procedure finds the most  }
{ efficient location of that buffer.                                        }
{  (* DMAPORTS.TXT states DMA pages are 128k rather than 64k; I disagree.)  }
{                                                                           }
{ *Warning: The pointer returned is not static. If used in memory moves,    }
{           for example, segment and offset may be altered and it cannot be }
{           used properly. It might be a good idea to do something like:    }
{                 SB_MakeDMABuffer(Buff,$800);                              }
{                 BuffSeg := Seg(Buff);                                     }
{                 BuffOfs := Ofs(Buff);                                     }
{  Before using:  Buff := Ptr(BuffSeg,BuffOfs);                             }

   Var
      BeginSeg, EndSeg : word;
      ExtraMem : word;
      BufferExt : pointer;

   Begin
      { Allocate required memory. (Size paragraphs=Size*10h bytes) }
      {Buffer := MemAllocSeg(Size*$10);}
      Buffer := GetMem(Size);

      { Don't continue if MemAlloc was unable to allocate the memory. }
      If Not(Buffer = nil)
         then
            Begin
               { Find the beginning and ending segments and offsets. }
               BeginSeg := Seg(Buffer^);
               EndSeg := BeginSeg + Size;

               { Now - two possibilities: }
               {   1. The allocated memory lies entirely in the same page.  }
               {   2. The allocated memory crossed a page boundary.         }
               If ((BeginSeg AND $1000) = (EndSeg AND $1000))
                  then  { Same page - no need to do anything more. }
                  else  { Different pages - attempt to fix. }
                     Begin
                        { Try to fix as follows:                            }
                        {   1. Find out how much of the buffer lies in the  }
                        {      first page.                                  }
                        {   2. Allocate that much memory at the end of the  }
                        {      buffer.                                      }
                        {   3. It's possible that it was not allocated      }
                        {      immediately after - admit defeat.            }
                        {   4. If immediately after, assign the buffer to   }
                        {      start of the second page.                    }
                        ExtraMem := ((EndSeg AND $F000) - BeginSeg);
                        {BufferExt := MemAllocSeg(ExtraMem*$10);}
                        BufferExt := GetMem(ExtraMem);
                        If (Seg(BufferExt^) = EndSeg)
                           then  { Immediately after. }
                              Begin
                                 { A note about the next line - it frees   }
                                 { the unused memory in the first page.    }
                                 { This leaves a "hole" in memory and      }
                                 { subsequent calls may fail to allocate   }
                                 { a contiguous buffer because added       }
                                 { memory, if small enough, will fit in    }
                                 { the "hole". With very small or very     }
                                 { large buffers, it can be used (maximum  }
                                 { wasted memory is < 64K - not critical.) }

                                 { FreeMem(Buffer,ExtraMem*$10);  }
                                 Buffer := Ptr((EndSeg AND $F000),0);
                              end
                           else  { Somewhere else - return nil. }
                              Buffer := nil;
                              { This really doesn't happen very often. If   }
                              { desired, this portion could contain a       }
                              { complex routine to find another contiguous  }
                              { part of memory - too much trouble, I say.   }
                              { Better to just use smaller buffers, or just }
                              { avoid disposing of memory until the end     }
                              { (to eliminate small "holes").               }
                     end;
            end;
   end;


Procedure SB_FreeDMABuffer(Buffer : pointer; Size : word);
{ Releases Size paragraphs of memory referenced by Buffer.                  }
{ Make sure the value of Size is the exact amount used for SB_MakeDMABuffer.}

{ Theory: Very simple. Use FreeMem to release the required amount of memory.}
{ (Size is in paragraphs, so adjust to a byte value in FreeMem.)            }

   Begin
      { Deallocate memory. (Size paragraphs=Size*10h bytes.) }
      FreeMem(Buffer,Size*$10);
      Buffer := nil;
   end;


Procedure SB_InitDMA(Toggle : byte; Buffer : pointer; DataLength : word);
{ Initializes the DMA controller for a transfer.                            }
{ Toggle=0 is record, else Toggle is play.                                  }
{ This procedure is not public and is called internally by SB_PlayDMA and   }
{ SB_SampleDMA.                                                             }
{ Refer to included file DMAPORTS.TXT for some details on initializing the  }
{ DMA ports.                                                                }

   Var
      DMAPage : word;
      DMAOfs : word;

   Begin
       DMAOfs := Seg(Buffer^) Shl 4 + Ofs(Buffer^);
       DMAPage := (Seg(Buffer^) + Ofs(Buffer^) shr 4) shr 12;
   
      (*
      { Calculate what DMA page the buffer lies in. 1000:0000-1000:FFFF is  }
      { page 1, etc.                                                        }
      DMAPage := word (Ofs(Buffer^) SHR 4);
      DMAPage := Seg(Buffer^) + DMAPage;
      DMAPage := word (Hi(DMAPage) SHR 4);

      { Calculate the offset within the DMA page.                           }
      DMAOfs := (Seg(Buffer^) AND $0FFF) SHL 4;
      DMAOfs := DMAOfs + Ofs(Buffer^);
      DMAOfs := DMAOfs mod $10000;*)

      Port[$0A] := DMAChannel+4;          { Mask out DMA channel.           }
      Port[$0C] := 0;                     { Clear byte pointer.             }
      If (Toggle = 0)
         then                             { Write function:                 }
            Port[$0B] := $44+DMAChannel   { Record.                         }
         else
            Port[$0B] := $48+DMAChannel;  { Play.                           }

      { Send low, then high byte of page offset. }
      (*Port[(DMAChannel SHL 1)] := byte (DMAOfs AND $00FF);
      Port[(DMAChannel SHL 1)] := byte (DMAOfs SHR 8);*)
      Port[(DMAChannel SHL 1)] := Lo (DMAOfs);
      Port[(DMAChannel SHL 1)] := Hi (DMAOfs);

      { Write DMA page. }
      Case DMAChannel of
         0 : Port[$87] := byte (DMAPage);
         1 : Port[$83] := byte (DMAPage);
         2 : Port[$81] := byte (DMAPage);
         3 : Port[$82] := byte (DMAPage);
      end;

      { Write the length-1 in low, high byte order. }
      Port[(DMAChannel SHL 1)+1] := Lo(DataLength - 1);
      Port[(DMAChannel SHL 1)+1] := Hi(DataLength - 1);

      Port[$0A] := DMAChannel;            { Enable DMA channel.             }
   end;


Procedure SB_InitDSPDMA(Toggle : byte; Rate : integer; DataLength : word);
{ Initializes the Sound Blaster for a DMA transfer. Sampling or playback    }
{ starts immediately after this procedure.                                  }
{ Toggle=0 is record, otherwise play.                                       }

   Begin
      { All these Repeat-Until loops do a standard check to wait until the  }
      { Blaster is ready to receive a byte.                                 }
      Repeat
      Until ((Port[WritePort] AND $80) = 0);

      { Set the time constant. }
      Port[WritePort] := $40;

      Repeat
      Until ((Port[WritePort] AND $80) = 0);

      { Write time constant = 256 - (1000000 / SamplingRate) }
      Port[WritePort] := byte (Trunc(256 - (1000000 / Rate)));

      Repeat
      Until ((Port[WritePort] AND $80) = 0);

      If (Toggle = 0)               { Set card function:                    }
         then
            Port[WritePort] := $24  { Record.                               }
         else
            Port[WritePort] := $14; { Play.                                 }

      Repeat
      Until ((Port[WritePort] AND $80) = 0);

      { Low byte of length-1. }
      Port[WritePort] := Lo(DataLength - 1);

      Repeat
      Until ((Port[WritePort] AND $80) = 0);

      { High byte of length-1. }
      Port[WritePort] := Hi(DataLength - 1);

      { Sound Blaster DMA function starts now. When finished transfer, an   }
      { interrupt occurs.                                                   }
   end;


{$F+}
Procedure SB_IntHandler;
   Interrupt;
{ Quick & dirty interrupt handler. When the DMA transfer completes, this    }
{ routine acknowledges the interrupt and sets the SB_DMAComplete flag.      }

{ The interrupt handler must:                                               }
{     1. Preserve machine status (done automatically in Pascal).            }
{     2. Acknowledge the interrupt by reading from port 2xEh.               }
{     3. Carry out desired function (a flag is set in this example).        }
{     4. Reset interrupt controller (send 20h to port 20h).                 }
{     5. Restore machine status (again, done automatically by Pascal).      }
{     6. Terminated by an "IRET" instruction (handled by Pascal).           }

   Var
      InByte : byte;

   Begin
      { Clear interrupt flag. Sometimes not necessary; take no chances.     }
      IrqOff;  {Inline($FA);}  { "cli" }
      InByte := Port[DataPort];        { Acknowledge interrupt (from 2xEh). }
      SB_DMAComplete := TRUE;          { Set a flag to indicate DMA done.   }
      Port[$20] := $20;                { Reset interrupt controller.        }
      IrqOn; {Inline($FB);}  { "sti" }
   end;
{$F-}


Procedure SB_SetIntHandler;
{ Replaces the interrupt corresponding to the Sound Blaster IRQ.            }

   Begin
      GetIntVec(SB_Int,OldIntHandler);       { Save old handler.            }
      SetIntVec(SB_Int,@SB_IntHandler);      { Replace with custom handler. }
      SB_DMAComplete := FALSE;
   end;


Procedure SB_ResetIntHandler;
{ Sets the Sound Blaster interrupt back to its previous handler.            }

   Begin
      SetIntVec(SB_Int,OldIntHandler);
   end;


Procedure SB_PlayDMA(Buffer : pointer; Rate : word; Length : word);
{ Output a buffer of data (of given Length) to the Sound Blaster using DMA  }
{ at Rate (in Hz).                                                          }

   Begin
      { Enable Sound Blaster IRQ on interrupt controller. }
      Port[$21] := Port[$21] AND Not(1 SHL (SB_Int - 8));

      { Initialize the DMA controller. }
      SB_InitDMA(1,Buffer,Length);

      { Initialize Blaster for DMA transfer. }
      SB_InitDSPDMA(1,Rate,Length);

      { Reset flag. }
      SB_DMAComplete := FALSE;
   end;


Procedure SB_SampleDMA(Buffer : pointer; Rate : word; Length : word);
{ Read in a buffer of data (of given Length) from the Sound Blaster using   }
{ DMA at Rate (in Hz).                                                      }
{ ************** This procedure doesn't seem to work. Sorry. ************** }
{ The technique is probably wrong; nothing I can do about that.             }

   Begin
      { Enable Sound Blaster IRQ on interrupt controller. }
      Port[$21] := Port[$21] AND Not(1 SHL (SB_Int - 8));

      { Initialize the DMA controller. }
      SB_InitDMA(0,Buffer,Length);

      { Initialize Blaster for DMA transfer. }
      SB_InitDSPDMA(0,Rate,Length);

      { Reset flag. }
      SB_DMAComplete := FALSE;
   end;


Procedure SB_StopDMA;
{ Stops the DMA transfer immediately.                                       }
   Begin
      Port[$0A] := 4 + DMAChannel;
      Port[$0C] := 0;
      Port[$0A] := 0;
   end;

Begin
   { Assign defaults. }
   SB_DMAComplete := FALSE;
   ReadPort := $22A;
   WritePort := $22C;
   DataPort := $22E;
   SB_Int := 5;
   DMAChannel := 1;
end.
