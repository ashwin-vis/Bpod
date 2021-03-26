%{
----------------------------------------------------------------------------

T

----------------------------------------------------------------------------
%}
function OdorTest

global BpodSystem

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 1000;
    S.GUI.OdorTime = 1;
    S.GUI.OdorInterval = 1;
    S.GUI.Port = 0; %0 = center, 1 = left, 2 = right
    S.GUI.OdorID = 0; % 0 = odor 1
end

%% DAQ
DAQ=1;
if DAQ==1
    dq = daq('ni'); 
    ch = addinput(dq, 'Dev1', 0:3, 'Voltage');
    ch(1).TerminalConfig = 'Differential';
    ch(2).TerminalConfig = 'SingleEnded';
    ch(3).TerminalConfig = 'SingleEnded';
    ch(4).TerminalConfig = 'SingleEnded';
    dq.Channels
    createDAQFileName();
    dq.Rate = 100;
    dq.ScansAvailableFcn = @(src,evt) recordDataAvailable(src,evt);
    dq.ScansAvailableFcnCount = 100;
    start(dq,'continuous');
end

%% Initialize plots

BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% MAIN TRIAL LOOP

MaxTrials = S.GUI.SessionTrials;

%% SET ODOR SIDES (LATCH VALVES)

port = S.GUI.Port;

modules = BpodSystem.Modules.Name;
latchValves = [16 15 14 11 10 9 8 7]; % evens to left!
latchModule = [modules(strncmp('DIO',modules,3))];
latchModule = latchModule{1};

if port == 1 % SEND ALL ODORS TO LEFT (A,B)
    pins = latchValves(1:2:end);    
elseif port == 2 % RIGHT
    pins = latchValves(2:2:end);
end

if port ~= 0
    for i = 1:4
        ModuleWrite(latchModule,[pins(i) 1]);
        pause(100/1000);
        ModuleWrite(latchModule,[pins(i) 0]);
        pause(100/1000);
    end
end

ResetSerialMessages();

%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
   S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
   
   MaxTrials = S.GUI.SessionTrials;
   odor = S.GUI.OdorID; % logic here to cycle odors
   newPort = S.GUI.Port;
   
    if newPort~= port
        if newPort == 1 % SEND INFO ODORS TO LEFT (A,B)
            pins = latchValves(1:2:end);    
        elseif newPort == 2
            pins = latchValves(2:2:end);
        end
        
        if port ~= 0
        for i = 1:4
            ModuleWrite(latchModule,[pins(i) 1]);
            pause(100/1000);
            ModuleWrite(latchModule,[pins(i) 0]);
            pause(100/1000);
        end
        end
   end
   port = newPort; % change here to switch sides
   
   
	% controls
    LoadSerialMessages('ValveModule1',{[1 2],[3 4],[5 6]}); % control by port    
    
    %--- Assemble state machine
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'OdorOn', ...
        'Timer', S.GUI.OdorTime,...
        'StateChangeConditions', {'Tup', 'OdorOff'},...
        'OutputActions', RunOdor(odor,port));
    sma = AddState(sma, 'Name', 'OdorOff', ...
        'Timer', S.GUI.OdorInterval,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', RunOdor(odor,port));  
    
    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events
    
    %--- Package and save the trial's data, update plots
    if ~isempty(fieldnames(RawEvents)) % If you didn't stop the session manually mid-trial
        for v = 1:8
            ModuleWrite('ValveModule1',['C' v]);
            ModuleWrite('ValveModule2',['C' v]);
            ModuleWrite('ValveModule3',['C' v]);
        end
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Adds raw events to a human-readable data struct
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        
        %--- Typically a block of code here will update online plots using the newly updated BpodSystem.Data
        
    end
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        for v = 1:8
            ModuleWrite('ValveModule1',['C' v]);
            ModuleWrite('ValveModule2',['C' v]);
            ModuleWrite('ValveModule3',['C' v]);
        end
        return
    end
end
end

%% ODOR CONTROL

%% GENERAL ODOR

function OdorOutputActions = RunOdor(odorID,port)
    switch port
        case 0
            cmd1 = {'ValveModule1',1}; % center control  
            switch odorID
                case 1
                    cmd2 = {'ValveModule2',1};
                    cmd3 = {'ValveModule3',1};
                case 2
                    cmd2 = {'ValveModule2',2};
                    cmd3 = {'ValveModule3',2};
                case 3
                    cmd2 = {'ValveModule2',3};
                    cmd3 = {'ValveModule3',3};                    
                case 4
                    cmd2 = {'ValveModule2',4};
                    cmd3 = {'ValveModule3',4};                    
            end
        case 1
            cmd1 = {'ValveModule1',2}; % left control
            switch odorID
                case 1
                    cmd2 = {'ValveModule2',5};
                    cmd3 = {'ValveModule3',5};
                case 2
                    cmd2 = {'ValveModule2',6};
                    cmd3 = {'ValveModule3',6};
                case 3
                    cmd2 = {'ValveModule2',7};
                    cmd3 = {'ValveModule3',7};                    
                case 4
                    cmd2 = {'ValveModule2',8};
                    cmd3 = {'ValveModule3',8};                    
            end            
        case 2
            cmd1 = {'ValveModule1',3}; % right control
            switch odorID
                case 1
                    cmd2 = {'ValveModule2',5};
                    cmd3 = {'ValveModule3',5};
                case 2
                    cmd2 = {'ValveModule2',6};
                    cmd3 = {'ValveModule3',6};
                case 3
                    cmd2 = {'ValveModule2',7};
                    cmd3 = {'ValveModule3',7};                    
                case 4
                    cmd2 = {'ValveModule2',8};
                    cmd3 = {'ValveModule3',8};
            end
    end
    OdorOutputActions = [cmd1,cmd2,cmd3];
end

function OdorOutputActions = turnOnOdor(odorID,port)
%     LoadSerialMessages('ValveModule1',{['O' 1],['O' 2],['O' 3],['O' 4],['O' 5],['O' 6]});
    switch port
        case 0
            cmd1 = {'ValveModule1',1}; % center control   
            cmd2 = {'ValveModule1',2}; % center control
            switch odorID
                case 0
                   cmd3 = {'ValveModule2',1};
                   cmd4 = {'ValveModule3',1};
                case 1
                   cmd3 = {'ValveModule2',2};
                   cmd4 = {'ValveModule3',2};                    
                case 2
                   cmd3 = {'ValveModule2',3};
                   cmd4 = {'ValveModule3',3};                    
                case 3
                   cmd3 = {'ValveModule2',4};
                   cmd4 = {'ValveModule3',4};                    
            end            
        case 1
            cmd1 = {'ValveModule1',3}; % left control
            cmd2 = {'ValveModule1',4}; % left control
            switch odorID
                case 0
                   cmd3 = {'ValveModule2',5};
                   cmd4 = {'ValveModule3',5};
                case 1
                   cmd3 = {'ValveModule2',6};
                   cmd4 = {'ValveModule3',6};                    
                case 2
                   cmd3 = {'ValveModule2',7};
                   cmd4 = {'ValveModule3',7};                    
                case 3
                   cmd3 = {'ValveModule2',8};
                   cmd4 = {'ValveModule3',8};                    
            end            
        case 2
            cmd1 = {'ValveModule1',5}; % right control
            cmd2 = {'ValveModule1',6}; % right control
            switch odorID
                case 0
                   cmd3 = {'ValveModule2',5};
                   cmd4 = {'ValveModule3',5};
                case 1
                   cmd3 = {'ValveModule2',6};
                   cmd4 = {'ValveModule3',6};                    
                case 2
                   cmd3 = {'ValveModule2',7};
                   cmd4 = {'ValveModule3',7};                    
                case 3
                   cmd3 = {'ValveModule2',8};
                   cmd4 = {'ValveModule3',8};                    
            end            
    end
    OdorOutputActions = [cmd1,cmd2,cmd3,cmd4];
end

function OdorOutputActions = turnOffOdor(odorID,port)
    LoadSerialMessages('ValveModule1',{['C' 1],['C' 2],['C' 3],['C' 4],['C' 5],['C' 6]});
    switch port
        case 0
            cmd1 = {'ValveModule1',1}; % center control   
            cmd2 = {'ValveModule1',2}; % center control
            switch odorID
                case 0
                   cmd3 = {'ValveModule2',1};
                   cmd4 = {'ValveModule3',1};
                case 1
                   cmd3 = {'ValveModule2',2};
                   cmd4 = {'ValveModule3',2};                    
                case 2
                   cmd3 = {'ValveModule2',3};
                   cmd4 = {'ValveModule3',3};                    
                case 3
                   cmd3 = {'ValveModule2',4};
                   cmd4 = {'ValveModule3',4};                    
            end            
        case 1
            cmd1 = {'ValveModule1',3}; % left control
            cmd2 = {'ValveModule1',4}; % left control
            switch odorID
                case 0
                   cmd3 = {'ValveModule2',5};
                   cmd4 = {'ValveModule3',5};
                case 1
                   cmd3 = {'ValveModule2',6};
                   cmd4 = {'ValveModule3',6};                    
                case 2
                   cmd3 = {'ValveModule2',7};
                   cmd4 = {'ValveModule3',7};                    
                case 3
                   cmd3 = {'ValveModule2',8};
                   cmd4 = {'ValveModule3',8};                    
            end            
        case 2
            cmd1 = {'ValveModule1',5}; % right control
            cmd2 = {'ValveModule1',6}; % right control
            switch odorID
                case 0
                   cmd3 = {'ValveModule2',5};
                   cmd4 = {'ValveModule3',5};
                case 1
                   cmd3 = {'ValveModule2',6};
                   cmd4 = {'ValveModule3',6};                    
                case 2
                   cmd3 = {'ValveModule2',7};
                   cmd4 = {'ValveModule3',7};                    
                case 3
                   cmd3 = {'ValveModule2',8};
                   cmd4 = {'ValveModule3',8};                    
            end            
    end
    OdorOutputActions = [cmd1,cmd2,cmd3,cmd4];
end


function createDAQFileName()
    global BpodSystem
    global DataFolder
    DataFolder = string(fullfile(BpodSystem.Path.DataFolder,BpodSystem.Status.CurrentSubjectName,BpodSystem.Status.CurrentProtocolName));
    DateInfo = datestr(now,30);
    DateInfo(DateInfo == 'T') = '_';
    global DAQFileName
    DAQFileName = string([BpodSystem.Status.CurrentSubjectName '_' BpodSystem.Status.CurrentProtocolName '_' DateInfo 'DAQout.csv']);
end

function recordDataAvailable(src,~)
    global DataFolder
    global DAQFileName
    [data,timestamps,~] = read(src, src.ScansAvailableFcnCount, 'OutputFormat','Matrix');
    dlmwrite(strcat(DataFolder, DAQFileName), [data,timestamps],'-append');
end
