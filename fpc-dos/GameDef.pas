unit GameDef;

interface

const
	DATA_PATH = 'data/';
	
function DataPath(fileName: string): string;	

implementation

function DataPath(fileName: string): string;
begin
	DataPath := DATA_PATH + fileName;
end;

begin
end.