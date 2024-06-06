# Deflector

Welcome to Deflector, a Deflektor clone written in Pascal.

This remake was created in 1995, and it was written in Turbo Pascal + bits of assembler. Gameplay is slightly different than the original, main differences being that you can rotate the laser beam, the level is completed once you destroy all the balls, there is no timer and there's only one life (yolo baby!).

This was, if I remember correctly, the 6th game made for PC and it worked on a 386-40DX. It was released under the previous incarnation of Piron Games, pompously named "Wings of Sorrow" (W.O.S.)

Game logo was created by my friend Traian Pop.

In 2024, I've decided to port it to Free Pascal. 

I've started off by creating an intermediary "fpc-dos" project, which improves on the original (implements correctly timer, keyboard and events sub-systems) while still working under MS-DOS. This one is still work-in-progress, takes a while to remember all the low level DOS system programming.

Eventually, I've made it work with SDL2 as well, while also bug fixing and adding new features (gamepad support, built-in game editor, etc)

Only 3 test levels are available.

This game has a special meaning to me, as I kept returning to explore its mechanics over the years. Check out [Laser Lab](https://www.pirongames.com/laser-lab/), a similar browser game I've started to develop in 2012 and finally released in 2018.

## License

Code license:
https://opensource.org/licenses/MIT

Graphics license:
https://creativecommons.org/licenses/by-nc-sa/4.0/

Music:
[Neon Techno by Drozerix](https://modarchive.org/index.php?request=view_by_moduleid&query=178172) - public domain

## Media

SDL2 version:
![Deflector Gameplay](.media/deflector_game_play.gif "Deflector Game Play")
![Deflector Main Menu](.media/deflector_main_menu.gif "Deflector Main Menu")


## Setup&Install&Build (FPC SDL2)

Install Free Pascal Compiler (version 3.2.2+)

Run build_deflector.bat to build and run the game. 

Ingame editor is available if you build the debug version.

SDL 2 DLLs are provided. Feel free to use your own or build them from sources.


## Setup&Install&Build (FPC DOS)

Install Free Pascal Compiler (version 3.2.2+) and the [Free Pascal 16-bit DOS cross-compiler](https://www.freepascal.org/down/i8086/msdos-canada.var)

Run build_deflector.bat to build the game.

The resulting executable has to be run from a MS-DOS emulator. It's been tested with DOSBox, but it might work under an original MS-DOS installation or FreeDOS.

This version lacks music and the editor has not been tested yet.


## Setup&Install&Build (original)

This may only be built using Turbo Pascal/Borland Pascal. It's provided for historical purposes only.


## Cheats
Open settings.json and locate the section "cheats"/"flow".

Note that some cheats only work in debug build.

These are:
* "spacewarp": starting level
* "skipintro": skip the game intro


## TODO
* complete the integration of the editor for the SDL2 version
* ingame laser line optimization - don't draw each pixel but draw line between collisions
* more audio sfx
* per menu option color
* return to the previous menu option 
* rotate mirror in both directions 
* free form mirror rotations (instead of 45 degrees increments)
* add lives support 
* add support to finish the level by connecting to the end point like in the original
* add support for fixed laser (to extend the mechanics range)
* fast/instant fade out in the settings to improve development flow
* create more levels
* fullscreen support
