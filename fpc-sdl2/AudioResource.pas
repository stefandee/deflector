unit AudioResource;

interface

uses
	SDL2_mixer,
	Audio,
	Logger,
	SDL2,
	SysUtils,
	ResourceDef;

const
    SFX_WOS_INTRO = 1;
    SFX_MENU_SELECT = 2;
    SFX_MENU_NAVIGATE = 3;
    SFX_MENU_BACK = SFX_MENU_SELECT;
    SFX_LEVEL_COMPLETE = 5;
    SFX_EXIT_GAME = 6;
    SFX_START_GAME = 7;
    SFX_MELTDOWN = 8;
	
    SFX_GAME_ROTATE_MIRROR = 32;
    SFX_GAME_TEMP_INCREASE_LOW = 33;
    SFX_GAME_TEMP_INCREASE_HIGH = SFX_GAME_TEMP_INCREASE_LOW;
    SFX_GAME_TEMP_NORMAL = 35;
    SFX_GAME_BUBBLE_POP = 36;

const
	SFX_WOS_INTRO_FILE_NAME = 'wosintro.wav';
	SFX_MENU_SELECT_FILE_NAME = '571189__user391915396__menuselect5.wav';
	SFX_MENU_NAVIGATE_FILE_NAME = '239523__cmdrobot__computer-beep-sfx-for-videogames.wav';
	SFX_EXIT_GAME_FILE_NAME = '458708__matrixxx__turn-on-turn-off-02.wav';
	SFX_LEVEL_COMPLETE_FILE_NAME = '652330__imataco__level-up.wav';
	SFX_START_GAME_FILE_NAME = '458427__matrixxx__turn-on-turn-off-01.wav';
	SFX_MELTDOWN_FILE_NAME = '609025__colorscrimsontears__power-down-2-rpg.wav';
	
	SFX_GAME_ROTATE_MIRROR_FILE_NAME = '608036__department64__rotarytool_02-short-fwd.wav';	
	SFX_GAME_TEMP_NORMAL_FILE_NAME = '582670__ironcross32__lowering-deactivate-07.wav';
	SFX_GAME_BUBBLE_POP_FILE_NAME = '187024__lloydevans09__jump2.wav';
	SFX_GAME_TEMP_INCREASE_LOW_FILE_NAME = '249705__unfa__short-glitch.wav';
	
const
	MOD_FILE_NAME = 'neontech.mod';

implementation

begin
end.
