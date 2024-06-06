unit Events;

interface

uses
	Common;

type
	{$scopedEnums on}
	EventType = ( None, KeyUp, KeyDown );
	
type	
	TEvent = record
		eventType: EventType;
		key: integer; { make it a record if more information is necessary }
	end;

procedure QueueEvent(evt: TEvent);
function PollEvent(var evt: TEvent): boolean;
function EventQueueLength: integer;
procedure ClearEventQueue;

implementation

const
	MAX_EVENTS_IN_Q = 32;

type	
	TEventQ = record
		Locked: boolean;
		Tail: integer;
		Events: array[1..MAX_EVENTS_IN_Q] of TEvent;
	end;

var
	IsQueueingEvent: boolean;
	IsPollingEvent: boolean;
	EventQ: TEventQ;

procedure QueueEvent(evt: TEvent);
begin	
	if IsPollingEvent then exit;
	
	{ reached the limit? }
	if (EventQ.Tail >= MAX_EVENTS_IN_Q) then exit;

	IsQueueingEvent := true;
	
	inc(EventQ.Tail);
	EventQ.Events[EventQ.Tail] := evt;
		
	IsQueueingEvent := false;
end;

function PollEvent(var evt: TEvent): boolean;
begin	
	IrqOff;
		
	if (EventQ.Tail = 0) or IsQueueingEvent then
	begin
		evt.eventType := EventType.None;
		PollEvent := false;
		IrqOn;
		exit;
	end;

	IsPollingEvent := true;
	
	evt := EventQ.Events[EventQ.Tail];
	
	dec(EventQ.Tail);
	
	IsPollingEvent := false;
		
	PollEvent := true;

	IrqOn;
	
end;

function EventQueueLength: integer;
begin
	EventQueueLength := EventQ.Tail;
end;

procedure ClearEventQueue;
begin
	EventQ.Tail := 0;
end;

begin
	IsQueueingEvent := false;
	IsPollingEvent := false;
	EventQ.Tail := 0;
	EventQ.Locked := false;
end.