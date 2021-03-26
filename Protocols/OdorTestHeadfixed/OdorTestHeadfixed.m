%{
----------------------------------------------------------------------------



----------------------------------------------------------------------------
%}
function OdorTestHeadfixed

global BpodSystem

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 1000;
    S.GUI.OdorTime = 0.2;
    S.GUI.OdorInterval = 5;
    S.GUI.OdorHeadstart = 0.500;
    S.GUI.OdorID = 3; % 1 = odor 1
end

%% DAQ

DAQ=0;
if DAQ==1
    dq = daq('ni'); 
    ch0 = addAnalogInputChannel(dq, 'Dev1', 0, 'Voltage');
    ch0.TerminalConfig = 'Differential';
    ch1 = addAnalogInputChannel(dq, 'Dev1', 1, 'Voltage');
    ch1.TerminalConfig = 'SingleEnded';
    ch2 = addAnalogInputChannel(dq, 'Dev1', 2, 'Voltage');
    ch2.TerminalConfig = 'SingleEnded';
    ch3 = addAnalogInputChannel(dq, 'Dev1', 3, 'Voltage');
    ch3.TerminalConfig = 'SingleEnded';

    
    createDAQFileName();
    dq.Rate = 100;
    dq.ScansAvailableFcn = @(src,evt) recordDataAvailable(src,evt);
    dq.ScansAvailableFcnCount = 100;
    start(dq,'continuous');
end

%% LOAD SERIAL MESSAGES

LoadSerialMessages('ValveModule1',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves before
LoadSerialMessages('ValveModule2',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves after
LoadSerialMessages('ValveModule3',{[1,2]}); % final valves before animal

modules = BpodSystem.Modules.Name;
DIOmodule = [modules(strncmp('DIO',modules,3))];
DIOmodule = DIOmodule{1};

buzzer1 = [254 1];
buzzer2 = [253 1];
LoadSerialMessages(DIOmodule, {buzzer1, buzzer2,...
    [11 1], [11 0], [12 1], [12 0], [13 1], [13 0]});
%% Initialize plots

BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% MAIN TRIAL LOOP

MaxTrials = S.GUI.SessionTrials;

%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
    modules = BpodSystem.Modules.Name;
    DIOmodule = [modules(strncmp('DIO',modules,3))];
    DIOmodule = DIOmodule{1};    

    MaxTrials = S.GUI.SessionTrials;
    odor = S.GUI.OdorID; % logic here to cycle odors

    %--- Assemble state machine
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'PreloadOdor', ...
        'Timer', S.GUI.OdorHeadstart,...
        'StateChangeConditions', {'Tup', 'OdorOn'},...
        'OutputActions', PreloadOdor(odor));    
    sma = AddState(sma, 'Name', 'OdorOn', ...
        'Timer', S.GUI.OdorTime,...
        'StateChangeConditions', {'Tup', 'OdorOff'},...
        'OutputActions', [PresentOdor(), {DIOmodule,1}]);
    sma = AddState(sma, 'Name', 'OdorOff', ...
        'Timer', S.GUI.OdorInterval,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', [PresentOdor(),PreloadOdor(odor)]);    

    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events

    %--- Package and save the trial's data, update plots
    if ~isempty(fieldnames(RawEvents)) % If you didn't stop the session manually mid-trial
        TurnOffAllOdors();
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Adds raw events to a human-readable data struct
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file

        %--- Typically a block of code here will update online plots using the newly updated BpodSystem.Data

    end

    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        TurnOffAllOdors();
        return
    end
end
end


%% ODOR CONTROL

% to preload, turn off control and turn on other odor (still going to
% exhaust)
% function actions = OdorTest(odor)
%     actions = {'ValveModule1',odor};
% end

% function actions = OdorTest(odor)
%     cmd1 = {'ValveModule1',odor};
%     cmd2 = {'ValveModule2',odor};
%     actions = [cmd1,cmd2];
% end

function Actions = PreloadOdor(odorID)          
    cmd1 = {'ValveModule1',odorID};
    cmd2 = {'ValveModule2',odorID}; 
    Actions = [cmd1,cmd2];
end

function Actions = PresentOdor()
    Actions = {'ValveModule3',1};
end

function TurnOffAllOdors()
    for v = 1:8
        ModuleWrite('ValveModule1',['C' v]);
        ModuleWrite('ValveModule2',['C' v]);
    end
    for v = 1:2
        ModuleWrite('ValveModule3',['C' v]);
    end    
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


