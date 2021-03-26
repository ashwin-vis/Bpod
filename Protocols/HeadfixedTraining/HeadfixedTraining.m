
%{

NEED TO:
-plotting
-name for lick events
----------------------------------------------------------------------------

trial types: 1,2,3 (alt, left, right)

params: num trials, types, drop size, licks required, delay, ITI, odor time

states: ITI(lights on), trial start(lights off), odor, go cue(beep),
responseleft(reward,wait for licks), responseright, delay(drinking?)

for training: ITI(lights on), trial start(lights off), center odor, go cue(beep),
responseleft(wait for licks, punished or not), side odor, delay, reward

%}

function HeadfixedTraining

global BpodSystem vid

%% Create trial manager object
TrialManager = TrialManagerObject;

%% DAQ

DAQ = 0;
if DAQ==1
    daqlist;
    dq = daq('ni'); 
    ch = addinput(dq, 'Dev1', 0:4, 'Voltage');
    ch(1).TerminalConfig = 'SingleEnded';
    ch(2).TerminalConfig = 'SingleEnded';
    ch(3).TerminalConfig = 'SingleEnded';
    ch(4).TerminalConfig = 'SingleEnded';
    ch(5).TerminalConfig = 'SingleEnded';
    
    createDAQFileName();
    dq.Rate = 10;
    dq.ScansAvailableFcn = @(src,evt) recordDataAvailable(src,evt);
    dq.ScansAvailableFcnCount = 10;
    start(dq,'continuous');
end

%% SETUP VIDEO

vidOn = 0;
if vidOn == 1
    setupVideo();
end

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 10;%
    S.GUI.TrialTypes = 2;% % 1 both, 2 left, 3 right
    S.GUI.RewardAmount = 4;
    S.GUI.OdorTime = 0.5;
    S.GUI.LeftOdor = 1;
    S.GUI.RightOdor = 2;
    S.GUI.LicksRequired = 2;
    S.GUI.ITI = 2;
    S.GUI.DrinkingDelay = 2;
    
    BpodSystem.ProtocolSettings = S;
    SaveProtocolSettings(BpodSystem.ProtocolSettings); % if no loaded settings, save defaults as a settings file   
end

%% DEFINE TRIAL TYPES

S.TrialTypes = [];
S = SetTrialTypes(S); % Sets S.TrialTypes from trial 1 to maxTrials
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots

% BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
% BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]);
% TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',S.TrialTypes);

% BpodSystem.ProtocolFigures.TrialTypePlotFig = figure('Position', [50 540 1000 250],'name','Trial Type','numbertitle','off', 'MenuBar', 'none');
% BpodSystem.GUIHandles.TrialTypePlot = axes('OuterPosition', [0 0 1 1]);
% TrialTypePlotInfo(BpodSystem.GUIHandles.TrialTypePlot,'init',S.TrialTypes,min([S.GUI.SessionTrials 40])); % trial choice types  

BpodNotebook('init');
% InfoParameterGUI('init', S); % Initialize parameter GUI plugin
BpodParameterGUI('init', S); % Initialize parameter GUI plugin
TotalRewardDisplay('init');

%% INITIALIZE SERIAL MESSAGES / DIO

% 19-23 output, 2-7 input

% lick inputs 2, 3

% buzzer output = 20
buzzer1 = [254 1];
buzzer2 = [253 1];
houseLight = 21;

modules = BpodSystem.Modules.Name;
DIOmodule = [modules(strncmp('DIO',modules,3))];
DIOmodule = DIOmodule{1};

LoadSerialMessages(DIOmodule, {buzzer1, buzzer2, [houseLight 1],[houseLight 0]});
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ODOR CONTROL SERIAL MESSAGES
LoadSerialMessages('ValveModule1',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves before
LoadSerialMessages('ValveModule2',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves after
LoadSerialMessages('ValveModule3',{[1,2]}); % final valves before animal

BpodSystem.Data.EventNames = BpodSystem.StateMachineInfo.EventNames;

%% INITIALIZE STATE MACHINE

[sma,S] = PrepareStateMachine(S, 1); % Prepare state machine for trial 1 with empty "current events" variable

if vidOn == 1
    start(vid);
    trigger(vid);
end

TrialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                              % console UI, while code below proceeds in parallel.

%% MAIN TRIAL LOOP

for currentTrial = 1:S.GUI.SessionTrials
    if BpodSystem.Status.BeingUsed == 0;        
        TurnOffAllOdors();
    return; end % If user hit console "stop" button, end session     
    [sma, S] = PrepareStateMachine(S, currentTrial+1); % Prepare next state machine.
    SendStateMachine(sma, 'RunASAP'); % send the next trial's state machine while the current trial is ongoing
    RawEvents = TrialManager.getTrialData; % Hangs here until trial is over, then retrieves full trial's raw data
    if BpodSystem.Status.BeingUsed == 0;        
        TurnOffAllOdors();
    return; end % If user hit console "stop" button, end session 
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    TrialManager.startTrial(); % Start processing the next trial's events
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned from last trial, update plots and save data
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S.GUI; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = S.TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
%         UpdateOutcomePlot(TrialTypes, BpodSystem.Data);
%         TotalRewardDisplay('add',rewardAmount);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file --> POSSIBLY MOVE THIS TO SAVE TIME??
    end
end


end % end of protocol main function


%% PREPARE STATE MACHINE

function [sma, S] = PrepareStateMachine(S, nextTrial)

global BpodSystem;

modules = BpodSystem.Modules.Name;
DIOmodule = [modules(strncmp('DIO',modules,3))];
DIOmodule = DIOmodule{1};

S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin

nextTrialType = S.TrialTypes(nextTrial);

% Determine trial-specific state matrix fields
% Set trialParams (reward and odor)
% set rewardstate, rewardamount/valvetime,odor
switch nextTrialType
    case 0 % left
        % response state
        Odor = S.GUI.LeftOdor;
        RewardState = 'RewardLeft';
        
    case 1 % right
        Odor = S.GUI.RightOdor;
        RewardState = 'RewardRight';
end

OdorHeadstart = 0.500;

% Water parameters
R = GetValveTimes(S.GUI.RewardAmount, [1 3]);
% R = [0.100 0.100];
LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts

sma = NewStateMatrix(); % Assemble state matrix

sma = SetGlobalCounter(sma,1,'DIO1_2_Hi',S.GUI.LicksRequired);
sma = SetGlobalCounter(sma,2,'DIO1_3_Hi',S.GUI.LicksRequired);


% STATES
sma = AddState(sma, 'Name', 'InterTrialInterval', ...
    'Timer', S.GUI.ITI-OdorHeadstart,...
    'StateChangeConditions', {'Tup', 'StartTrial'},...
    'OutputActions', {DIOmodule,3});
sma = AddState(sma, 'Name', 'OdorPreload',...
    'Timer', OdorHeadstart,...
    'StateChangeConditions', {'Tup', 'StartTrial'},...
    'OutputActions',PreloadOdor(Odor)); %Preload odor
sma = AddState(sma, 'Name', 'StartTrial', ...
    'Timer', 0.2,...
    'StateChangeConditions', {'Tup', 'Odor'},...
    'OutputActions', {DIOmodule,4});
sma = AddState(sma, 'Name', 'Odor', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup', 'GoCue'},...
    'OutputActions',PresentOdor());
sma = AddState(sma, 'Name', 'GoCue', ...
    'Timer', 0.05,...
    'StateChangeConditions', {'Tup',RewardState},...
    'OutputActions', [{DIOmodule,2},PresentOdor(),PreloadOdor(Odor)]);

% REWARD AND LICKS
sma = AddState(sma, 'Name', 'RewardLeft', ...
    'Timer', LeftValveTime,...
    'StateChangeConditions', {'Tup','ResponseLeft'},...
    'OutputActions', {'ValveState', 1});
sma = AddState(sma, 'Name', 'ResponseLeft', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalCounter1_End','Drinking'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'RewardRight', ...
    'Timer', RightValveTime,...
    'StateChangeConditions', {'Tup','ResponseRight'},...
    'OutputActions', {'ValveState', 2});
sma = AddState(sma, 'Name', 'ResponseRight', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalCounter2_End','Drinking'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'Drinking',...
    'Timer', S.GUI.DrinkingDelay,...
    'StateChangeConditions', {'Tup','>exit'},...
    'OutputActions', {'GlobalCounterReset',1,'GlobalCounterReset',2});    
end

%% TRIAL TYPES

function S = SetTrialTypes(S)

    global BpodSystem;

    nTrials = S.GUI.SessionTrials;

    typesAvailable = S.GUI.TrialTypes;

    switch typesAvailable 
        case 1
            trialTypes = ceil(rand(1,nTrials)*2);
        case 2
            trialTypes = ones(1,nTrials);
        case 3
            trialTypes = ones(1,nTrials)*2; 
    end

    S.TrialTypes = trialTypes;   
end


%% ODOR CONTROL

% to preload, turn off control and turn on other odor (still going to
% exhaust)

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


function setupVideo()
    global BpodSystem vid
    vid = videoinput('winvideo',1,'MJPG_1920x1080');
    src = getselectedsource(vid);
    vid.FramesPerTrigger = Inf;
    triggerconfig(vid, 'manual');
    DataFolder = fullfile(BpodSystem.Path.DataFolder,BpodSystem.GUIData.SubjectName,BpodSystem.Status.CurrentProtocolName,'Session Data');
    DateInfo = datestr(now, 30); 
    DateInfo(DateInfo == 'T') = '_';
    VidName = [BpodSystem.GUIData.SubjectName '_' BpodSystem.Status.CurrentProtocolName '_' DateInfo];
    logfile = VideoWriter(fullfile(DataFolder,VidName),'Motion JPEG AVI');
    set(logfile,'FrameRate',30);
    vid.DiskLogger = logfile;
    set(vid,'LoggingMode','disk');
    figure('Toolbar','none',...
       'Menubar', 'none',...
       'NumberTitle','Off',...
       'Name','Live Feed');
    vidRes = get(vid, 'VideoResolution');
    imWidth = vidRes(1);
    imHeight = vidRes(2);
    nBands = get(vid, 'NumberOfBands');
    hImage = image( zeros(imHeight, imWidth, nBands) );    
    preview(vid,hImage);
end

function shutdownVideo()
    global vid
%         stoppreview();
%         closepreview();
        hf=findobj('Name','Live Feed');
        close(hf);
        stop(vid);
    %     while (vid.FramesAcquired ~= vid.DiskLoggerFrameCount) 
    %         pause(.1)
    %     end
        flushdata(vid);
        delete(vid);
        clear vid;

    %     setupVideo();
end

function UpdateOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Drinking(1))
        Outcomes(x) = 1;
    else
        Outcomes(x) = 3;
    end
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
end