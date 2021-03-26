%{
----------------------------------------------------------------------------

This code runs a 2AFC Information Seeking assay. The mouuse initiatess a
trial by poking the center port to receive an odor directing to right or
left port or free choice between the two. The mouse chooses side port by
poking there and there receives either informative or un-
informative odor, then after a delay, reward outcome at the same side port.

The mouse only receives water if he is present in the corret chosen port
at the outcome tiime.
----------------------------------------------------------------------------

Three valve control modules control airflow in the custom dilution
olfactometer.

One Teensy 3.2 connected as a module with the Bpod Teensy Shield controls
a buzzer and lick sensor.

%}
function InfoSeekDoors

global BpodSystem vid

%% Create trial manager object
TrialManager = TrialManagerObject;

%% DAQ

daqlist;
DAQ=1;
if DAQ==1
    dq = daq('ni'); 
    addinput(dq, 'Dev1', 'ai0', 'Voltage');
    addinput(dq, 'Dev1', 'ai1', 'Voltage');
    createDAQFileName();
    dq.Rate = 100;
    dq.ScansAvailableFcn = @(src,evt) recordDataAvailable(src,evt);
    dq.ScansAvailableFcnCount = 100;
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
    S.GUI.SessionTrials = 1000;%
    S.GUI.TrialTypes = 2;%
    S.GUI.InfoSide = 0;%
    S.GUI.InfoOdor = 2;
    S.GUI.RandOdor = 0;
    S.GUI.ChoiceOdor = 3;
    S.GUI.OdorA = 3;
    S.GUI.OdorB = 2;
    S.GUI.OdorC = 0;
    S.GUI.OdorD = 1;
    S.GUI.CenterDelay = 0;
    S.GUI.CenterOdorTime = 0.2;
    S.GUI.StartDelay = 0;
    S.GUI.OdorDelay = 1.2;
    S.GUI.OdorTime = 1;
    S.GUI.RewardDelay = 3;
    S.GUI.InfoBigDrops = 1;
    S.GUI.InfoSmallDrops = 1;
    S.GUI.RandBigDrops = 1;
    S.GUI.RandSmallDrops = 1;
    S.GUI.InfoRewardProb = 0;%
    S.GUI.RandRewardProb = 0;%
    S.GUI.GracePeriod = 100000000; 
    S.GUI.Interval = 1;
    S.GUI.DoorsOn = 0;
    S.GUI.OptoFlag = 0;
    S.GUI.OptoType = 0;
    S.GUI.ImageFlag = 0;
    S.GUI.ImageType = 0;
    
    BpodSystem.ProtocolSettings = S;
    SaveProtocolSettings(BpodSystem.ProtocolSettings); % if no loaded settings, save defaults as a settings file   
end

%% Set up trial types and rewards

S.TrialTypes = [];
S.RewardTypes = [];
S.RandOdorTypes = [];
S = SetTrialTypes(S,1); % Sets S.TrialTypes from trial 1 to maxTrials
S = SetRewardTypes(S,1); % Sets S.RewardTypes, S.RandOdorTypes from trial 1 to maxTrials

%% SET INITIAL TYPE COUNTS

BpodSystem.Data.TrialCounts = [0,0,0,0];
BpodSystem.Data.PlotOutcomes = [];

%% SAVE EVENT NAMES AND NUMBER

BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
BpodSystem.Data.Outcomes = [];

BpodSystem.Data.OrigTrialTypes = S.TrialTypes; % take out if working?
BpodSystem.Data.OrigRewardTypes = S.RewardTypes; % take out if working?
BpodSystem.Data.EventNames = BpodSystem.StateMachineInfo.EventNames;
SaveBpodSessionData;

%% Initialize plots

BpodSystem.ProtocolFigures.TrialTypePlotFig = figure('Position', [50 540 1000 250],'name','Trial Type','numbertitle','off', 'MenuBar', 'none');
BpodSystem.GUIHandles.TrialTypePlot = axes('OuterPosition', [0 0 1 1]);
TrialTypePlotInfo(BpodSystem.GUIHandles.TrialTypePlot,'init',S.TrialTypes,min([S.GUI.SessionTrials 40])); % trial choice types  
% EventsPlot('init', getStateColors(S.GUI.InfoSide)); % events within trial

BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 100 600 400],'name','TrialOutcomes','numbertitle','off', 'MenuBar', 'none');
BpodSystem.GUIHandles.OutcomePlot = axes('OuterPosition', [0 0 1 1]);
InfoOutcomesPlot(BpodSystem.GUIHandles.OutcomePlot,'init');

BpodNotebook('init');
InfoParameterGUI('init', S); % Initialize parameter GUI plugin
TotalRewardDisplay('init');

%% INITIALIZE SERIAL MESSAGES / DIO

ResetSerialMessages();

% lick inputs 2, 3, 4
% door outputs 5,6,7
% buzzer output 8
buzzer1 = [254 1];
buzzer2 = [253 1];
openSpeed = 5;
closeSpeed = 30;
leftDoorOpen = [251 openSpeed]; %3
leftDoorClose = [252 closeSpeed]; %4
centerDoorOpen = [249 openSpeed]; %5
centerDoorClose = [250 closeSpeed]; %6
rightDoorOpen = [247 openSpeed]; %7
rightDoorClose = [248 closeSpeed]; %8

modules = BpodSystem.Modules.Name;
DIOmodule = [modules(strncmp('DIO',modules,3))];
DIOmodule = DIOmodule{1};

% MINISCOPE
% miniscope has 4 I/O BNC Pins, and scope sync and trig
% scope sync connects to Bpod IN BNC
% scope trig to Bpod OUT BNC 1
% Bpod out BNC 2 at center odor start

LoadSerialMessages(DIOmodule, {buzzer1, buzzer2, leftDoorOpen, leftDoorClose,...
    centerDoorOpen, centerDoorClose, rightDoorOpen, rightDoorClose,...
    [9 1], [9 0], [10 1], [10 0], [11 1],[11,0],[14 1],[14 0],[15 1],[15 0],...
    [16 1],[16 0],[17 1],[17 0]});
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ODOR CONTROL SERIAL MESSAGES
LoadSerialMessages('ValveModule1',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves before
LoadSerialMessages('ValveModule2',{[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8]}); % switch control and odor 1-7, valves after
LoadSerialMessages('ValveModule3',{[1,2],[3,4],[5,6]}); % final valves switch control and odor, left, center, right
LoadSerialMessages('ValveModule4',{[1,2],[3,2]}); % turn on right, turn on left

%% START WITH DOORS OPEN

openDoors();

%% INITIALIZE STATE MACHINE

[sma,S,nextRewardLeft,nextRewardRight] = PrepareStateMachine(S, 1, []); % Prepare state machine for trial 1 with empty "current events" variable

if vidOn == 1
    start(vid);
    trigger(vid);
end

TrialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                              % console UI, while code below proceeds in parallel.
RewardLeft = nextRewardLeft; RewardRight = nextRewardRight;

%% MAIN TRIAL LOOP

for currentTrial = 1:S.GUI.SessionTrials
    currentS = S;
    currentTrialEvents = TrialManager.getCurrentEvents({'WaitForOdorLeft','WaitForOdorRight','NoChoice','Incorrect'}); % Hangs here until Bpod enters one of the listed trigger states, then returns current trial's states visited + events captured to this point                       
    if BpodSystem.Status.BeingUsed == 0;        
        TurnOffAllOdors();
        if vidOn==1
            shutdownVideo();
        end        
        openDoors();
        return; end % If user hit console "stop" button, end session
    [sma, S, nextRewardLeft,nextRewardRight] = PrepareStateMachine(S, currentTrial+1, currentTrialEvents); % Prepare next state machine.
    SendStateMachine(sma, 'RunASAP'); % send the next trial's state machine while the current trial is ongoing
    RawEvents = TrialManager.getTrialData; % Hangs here until trial is over, then retrieves full trial's raw data
    if BpodSystem.Status.BeingUsed == 0;        
        TurnOffAllOdors();
        openDoors();
        return; end % If user hit console "stop" button, end session 
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    TrialManager.startTrial(); % Start processing the next trial's events
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned from last trial, update plots and save data
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        [rewardAmount,outcome] = UpdateOutcome(currentTrial,currentS,RewardLeft,RewardRight); 
        BpodSystem.Data.TrialSettings(currentTrial) = currentS.GUI; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = currentS.TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        BpodSystem.Data.Outcomes(currentTrial) = outcome;
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        TotalRewardDisplay('add',rewardAmount);
        RewardLeft = nextRewardLeft; RewardRight = nextRewardRight;
        TrialTypePlotInfo(BpodSystem.GUIHandles.TrialTypePlot,'update',currentTrial,S.TrialTypes);
        InfoOutcomesPlot(BpodSystem.GUIHandles.OutcomePlot,'update');
%         EventsPlot('update');
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file --> POSSIBLY MOVE THIS TO SAVE TIME??
    end
end


end % end of protocol main function


%% PREPARE STATE MACHINE

function [sma, S, RewardLeft, RewardRight] = PrepareStateMachine(S, nextTrial, currentTrialEvents)

global BpodSystem;

modules = BpodSystem.Modules.Name;
DIOmodule = [modules(strncmp('DIO',modules,3))];
DIOmodule = DIOmodule{1};

lastS = S;
S = InfoParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin


if S.GUI.TrialTypes ~= lastS.GUI.TrialTypes
   S = SetTrialTypes(S,nextTrial);
end

if (S.GUI.InfoRewardProb ~= lastS.GUI.InfoRewardProb | S.GUI.RandRewardProb ~= lastS.GUI.RandRewardProb)
    S = SetRewardTypes(S,nextTrial);
end

% DETERMINE TRIAL TYPE
if nextTrial>1
    previousStates = currentTrialEvents.StatesVisited;
    if sum(contains(previousStates,'NoChoice') | contains(previousStates,'Incorrect'))>0
        S = UpdateTrialTypes(nextTrial,S);
    end
end

nextTrialType = S.TrialTypes(nextTrial);

infoSide = S.GUI.InfoSide;
TrialCounts = BpodSystem.Data.TrialCounts;

% Determine trial-specific state matrix fields
% Set trialParams (reward and odor)
switch nextTrialType
    case 1 % CHOICE
        ChooseLeft = 'WaitForOdorLeft'; ChooseRight = 'WaitForOdorRight';
        ThisCenterOdor = S.GUI.ChoiceOdor;
        CenterDIOmsg1 = 9; CenterDIOmsg2 = 10;
        if infoSide == 0 % INFO LEFT            
            RewardLeft = S.RewardTypes(TrialCounts(1)+1,1); RewardRight = S.RewardTypes(TrialCounts(2)+1,2);
            RightSideOdorFlag = S.RandOdorTypes((TrialCounts(2)+TrialCounts(4))+1,1);
            if RightSideOdorFlag == 0
                RightSideOdor = S.GUI.OdorC;
                SideOdorStateRight = 'OdorCRight';
                SideDIOmsg1 = 19; SideDIOmsg2 = 20;
            else
                RightSideOdor = S.GUI.OdorD;
                SideOdorStateRight = 'OdorDRight';
                SideDIOmsg1 = 21; SideDIOmsg2 = 22;
            end
            if RewardLeft == 1
                OutcomeStateLeft = 'LeftBigReward';
                LeftRewardDrops = S.GUI.InfoBigDrops;
                LeftSideOdor = S.GUI.OdorA;
                SideOdorStateLeft = 'OdorALeft';
                SideDIOmsg1 = 15; SideDIOmsg2 = 16;
            else
                OutcomeStateLeft = 'LeftSmallReward';
                LeftRewardDrops = S.GUI.InfoSmallDrops;
                LeftSideOdor = S.GUI.OdorB;
                SideOdorStateLeft = 'OdorBLeft';
                SideDIOmsg1 = 17; SideDIOmsg2 = 18;
            end
            if RewardRight == 1
                OutcomeStateRight = 'RightBigReward';
                RightRewardDrops = S.GUI.RandBigDrops;
            else
                OutcomeStateRight = 'RightSmallReward';
                RightRewardDrops = S.GUI.RandSmallDrops;
            end
        else
            RewardLeft = S.RewardTypes(TrialCounts(2)+1,2); RewardRight = S.RewardTypes(TrialCounts(1)+1,1);
            LeftSideOdorFlag = S.RandOdorTypes((TrialCounts(2)+TrialCounts(4))+1,1);
            if LeftSideOdorFlag == 0
                LeftSideOdor = S.GUI.OdorC;
                SideOdorStateLeft = 'OdorCLeft';
                SideDIOmsg1 = 19; SideDIOmsg2 = 20;
            else
                LeftSideOdor = S.GUI.OdorD;
                SideOdorStateLeft = 'OdorDLeft';
                SideDIOmsg1 = 21; SideDIOmsg2 = 22;
            end            
            if RewardLeft == 1
                OutcomeStateLeft = 'LeftBigReward';
                LeftRewardDrops = S.GUI.RandBigDrops;
            else
                OutcomeStateLeft = 'LeftSmallReward';
                LeftRewardDrops = S.GUI.RandSmallDrops;
            end
            if RewardRight == 1
                OutcomeStateRight = 'RightBigReward';
                RightRewardDrops = S.GUI.InfoBigDrops;
                RightSideOdor = S.GUI.OdorA;
                SideOdorStateRight = 'OdorARight';
                SideDIOmsg1 = 15; SideDIOmsg2 = 16;
            else
                OutcomeStateRight = 'RightSmallReward';
                RightRewardDrops = S.GUI.InfoSmallDrops;
                RightSideOdor = S.GUI.OdorB;
                SideOdorStateRight = 'OdorBRight';
                SideDIOmsg1 = 17; SideDIOmsg2 = 18;
            end            
        end
             
    case 2 % INFO FORCED
        ThisCenterOdor = S.GUI.InfoOdor;
        CenterDIOmsg1 = 11; CenterDIOmsg2 = 12;
        if infoSide == 0
            % info on left
            RewardLeft = S.RewardTypes(TrialCounts(3)+1,3); RewardRight = 0;
            ChooseLeft = 'WaitForOdorLeft'; ChooseRight = 'Incorrect';
            RightSideOdor = 0;
            if RewardLeft == 1
                OutcomeStateLeft = 'LeftBigReward';
                LeftRewardDrops = S.GUI.InfoBigDrops;
                LeftSideOdor = S.GUI.OdorA;
                SideOdorStateLeft = 'OdorALeft';
                SideDIOmsg1 = 15; SideDIOmsg2 = 16;
            else
                OutcomeStateLeft = 'LeftSmallReward';
                LeftRewardDrops = S.GUI.InfoSmallDrops;
                LeftSideOdor = S.GUI.OdorB;
                SideOdorStateLeft = 'OdorBLeft';
                SideDIOmsg1 = 17; SideDIOmsg2 = 18;
            end
            OutcomeStateRight = 'TimeoutOutcome';
            SideOdorStateRight = 'TimeoutOdor';
            RightRewardDrops = 0;
        else
            RewardLeft = 0; RewardRight = S.RewardTypes(TrialCounts(3)+1,3);
            ChooseLeft = 'Incorrect'; ChooseRight = 'WaitForOdorRight';
            LeftSideOdor = 0;            
            if RewardRight == 1
                OutcomeStateRight = 'RightBigReward';
                RightRewardDrops = S.GUI.InfoBigDrops;
                RightSideOdor = S.GUI.OdorA;
                SideOdorStateRight = 'OdorARight';
                SideDIOmsg1 = 15; SideDIOmsg2 = 16;
            else
                OutcomeStateRight = 'RightSmallReward';
                RightRewardDrops = S.GUI.InfoSmallDrops;
                RightSideOdor = S.GUI.OdorB;
                SideOdorStateRight = 'OdorBRight';
                SideDIOmsg1 = 17; SideDIOmsg2 = 18;
            end
            OutcomeStateLeft = 'TimeoutOutcome';
            SideOdorStateLeft = 'TimeoutOdor';
            LeftRewardDrops = 0;
        end
    case 3 % RAND FORCED
        ThisCenterOdor = S.GUI.RandOdor;
        CenterDIOmsg1 = 13; CenterDIOmsg2 = 14;
        if infoSide == 0 % INFO ON LEFT
            RewardLeft = 0; RewardRight = S.RewardTypes(TrialCounts(4)+1,4);
            ChooseLeft = 'Incorrect'; ChooseRight = 'WaitForOdorRight';
            RightSideOdorFlag = S.RandOdorTypes((TrialCounts(2)+TrialCounts(4))+1,1);           
            if RightSideOdorFlag == 0
                RightSideOdor = S.GUI.OdorC;
                SideOdorStateRight = 'OdorCRight';
                SideDIOmsg1 = 19; SideDIOmsg2 = 20;
            else
                RightSideOdor = S.GUI.OdorD;
                SideOdorStateRight = 'OdorDRight';
                SideDIOmsg1 = 21; SideDIOmsg2 = 22;
            end            
            LeftSideOdor = 0;
            if RewardRight == 1
                OutcomeStateRight = 'RightBigReward';
                RightRewardDrops = S.GUI.RandBigDrops;
            else
                OutcomeStateRight = 'RightSmallReward';
                RightRewardDrops = S.GUI.RandSmallDrops;
            end
            OutcomeStateLeft = 'TimeoutOutcome';
            SideOdorStateLeft = 'TimeoutOdor';
            LeftRewardDrops = 0;
        else
            RewardLeft = S.RewardTypes(TrialCounts(4)+1); RewardRight = 0;
            ChooseLeft = 'WaitForOdorLeft'; ChooseRight = 'Incorrect';
            LeftSideOdorFlag = S.RandOdorTypes((TrialCounts(2)+TrialCounts(4))+1,1);           
            if LeftSideOdorFlag == 0
                LeftSideOdor = S.GUI.OdorC;
                SideOdorStateLeft = 'OdorCLeft';
                SideDIOmsg1 = 19; SideDIOmsg2 = 20;
            else
                LeftSideOdor = S.GUI.OdorD;
                SideOdorStateLeft = 'OdorDLeft';
                SideDIOmsg1 = 21; SideDIOmsg2 = 22;
            end             
            RightSideOdor = 0;
            if RewardLeft == 1
                OutcomeStateLeft = 'LeftBigReward';
                LeftRewardDrops = S.GUI.RandBigDrops;
            else
                OutcomeStateLeft = 'LeftSmallReward';
                LeftRewardDrops = S.GUI.RandSmallDrops;
            end
            OutcomeStateRight = 'TimeoutOutcome';
            SideOdorStateRight = 'TimeoutOdor';
            RightRewardDrops = 0;
        end
end

% DOORS
if S.GUI.DoorsOn == 1
    doorOpen = [{DIOmodule,3,DIOmodule,7}];
    doorClose = [{DIOmodule,4,DIOmodule,8}];
else
    doorOpen = [];
    doorClose  = [];
end
doorOpenGrace = 0.3;

% Water parameters
R = GetValveTimes(4, [1 3]);
% R = [0.100 0.100];
LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
MaxValveTime = max(R);
maxDrops = max([S.GUI.InfoBigDrops,S.GUI.InfoSmallDrops,S.GUI.RandBigDrops,S.GUI.RandSmallDrops]);
RewardPauseTime = 0.05;

sma = NewStateMatrix(); % Assemble state matrix

sma = SetCondition(sma, 1, 'Port1', 1); % Condition 1: Port 1 high (is in) (left)
sma = SetCondition(sma, 2, 'Port2', 1); % Condition 2: Port 2 high (is in) (center)
sma = SetCondition(sma, 3, 'Port3', 1); % Condition 3: Port 3 high (is in) (right)
sma = SetCondition(sma, 4, 'Port1', 0); % Condition 4: Port 1 low (is out) (left)
sma = SetCondition(sma, 5, 'Port2', 0); % Condition 5: Port 2 low (is out) (center)
sma = SetCondition(sma, 6, 'Port3', 0); % Condition 6: Port 3 low (is out) (right)

% TIMERS
sma = SetCondition(sma, 7, 'GlobalTimer1', 0);

% sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', S.GUI.OdorDelay+0.05); % ODOR DELAY + GO CUE
sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', S.GUI.OdorDelay+0.05,...
    'OnsetDelay', 0, 'Channel', 'SoftCode', 'OnMessage', 0, 'OffMessage', 0,...
    'Loop', 0, 'SendEvents', 1, 'LoopInterval', 0,'OnsetTrigger','010000'); %also turn on timer 5

% TIMER 2 FOR MAX REWARD
if maxDrops > 1
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', MaxValveTime,...
        'OnsetDelay', 0, 'Channel', 'SoftCode', 'OnMessage',0, 'OffMessage', 0,...
        'Loop', maxDrops, 'SendEvents', 1, 'LoopInterval', RewardPauseTime); % timer to stay in reward state
else
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', MaxValveTime,...
        'OnsetDelay', 0, 'Channel', 'SoftCode', 'OnMessage', 0, 'OffMessage', 0,...
        'Loop', 0, 'SendEvents', 1, 'LoopInterval', 0); % timer to stay in reward state    
end
sma = SetGlobalCounter(sma, 2, 'GlobalTimer2_End', maxDrops);

% TIMERS TO PRELOAD ODORS
OdorHeadstart = 0.500;
sma = SetGlobalTimer(sma,'TimerID',5,'Duration',S.GUI.OdorDelay+0.05-OdorHeadstart,'OnsetDelay',0,...
   'Channel','SoftCode','OnMessage', 0, 'OffMessage', 0);
sma = SetCondition(sma, 8, 'GlobalTimer5', 0);

sma = SetGlobalTimer(sma,'TimerID',6,'Duration',S.GUI.Interval-OdorHeadstart,'OnsetDelay',0,...
   'Channel','SoftCode','OnMessage', 0, 'OffMessage', 0);
sma = SetCondition(sma, 9, 'GlobalTimer6', 0);

% reward states all wait for timers to end
% set multiple timers for each outcome--one for drops, one for blanks
% get rid of reward states

% Timers for delivering reward drops
if LeftRewardDrops > 1
   sma = SetGlobalTimer(sma,'TimerID',3,'Duration',LeftValveTime,'OnsetDelay',0,...
       'Channel', 'Valve1', 'OnMessage', 1, 'OffMessage', 0, 'Loop',...
       LeftRewardDrops, 'SendEvents', 1, 'LoopInterval', RewardPauseTime,'OnsetTrigger', '10');
   sma = SetGlobalCounter(sma, 3, 'GlobalTimer3_End', LeftRewardDrops);
elseif LeftRewardDrops == 1
   sma = SetGlobalTimer(sma,'TimerID',3,'Duration',LeftValveTime,'OnsetDelay',0,...
       'Channel','Valve1','OnMessage', 1, 'OffMessage', 0, 'Loop', 0, 'SendEvents', 1,'LoopInterval',0,'OnsetTrigger', '10');
   sma = SetGlobalCounter(sma, 3, 'GlobalTimer3_End', 1);
else
   sma = SetGlobalTimer(sma,'TimerID',3,'Duration',0,'OnsetDelay',0,...
       'Channel','Valve1','OnMessage', 0, 'OffMessage', 0, 'Loop', 0, 'SendEvents', 1,'LoopInterval',0,'OnsetTrigger', '10');
   sma = SetGlobalCounter(sma, 3, 'GlobalTimer3_End', 1);
end

if RightRewardDrops > 1
    sma = SetGlobalTimer(sma,'TimerID',4,'Duration', RightValveTime,'OnsetDelay',0,...
        'Channel', 'Valve3', 'OnMessage', 1, 'OffMessage', 0, 'Loop',...
        RightRewardDrops, 'SendEvents', 1, 'LoopInterval', RewardPauseTime,'OnsetTrigger', '10');
    sma = SetGlobalCounter(sma, 4, 'GlobalTimer4_End', RightRewardDrops);
elseif RightRewardDrops == 1
    sma = SetGlobalTimer(sma,'TimerID',4,'Duration',RightValveTime,'OnsetDelay',0,...
        'Channel', 'Valve3', 'OnMessage', 1, 'OffMessage', 0, 'Loop', 0, 'SendEvents', 1,'LoopInterval',0,'OnsetTrigger', '10');
    sma = SetGlobalCounter(sma, 4, 'GlobalTimer4_End', 1);
else
    sma = SetGlobalTimer(sma,'TimerID',4,'Duration',0,'OnsetDelay',0,...
        'Channel', 'Valve3', 'OnMessage', 0, 'OffMessage', 0, 'Loop', 0, 'SendEvents', 1,'LoopInterval',0,'OnsetTrigger', '10');
    sma = SetGlobalCounter(sma, 4, 'GlobalTimer4_End', 1);
end


% STATES
sma = AddState(sma, 'Name', 'InterTrialInterval', ...
    'Timer', S.GUI.Interval,...
    'StateChangeConditions', {'Tup', 'StartTrial','Condition9', 'CenterOdorPreload'},...
    'OutputActions', {'GlobalTimerTrig', 6});
sma = AddState(sma, 'Name', 'CenterOdorPreload',...
    'Timer', OdorHeadstart,...
    'StateChangeConditions', {'Tup', 'StartTrial'},...
    'OutputActions',PreloadOdor(ThisCenterOdor,0)); %Preloadcenter odor
sma = AddState(sma, 'Name', 'StartTrial', ...
    'Timer', 0.2,...
    'StateChangeConditions', {'Tup', 'WaitForCenter'},...
    'OutputActions', {DIOmodule,5});
sma = AddState(sma, 'Name', 'WaitForCenter', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port2In', 'CenterDelay','Condition2','CenterDelay'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'CenterDelay', ...
    'Timer', S.GUI.CenterDelay,...
    'StateChangeConditions', {'Tup', 'CenterOdor','Port2Out','WaitForCenter'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'CenterOdor', ...
    'Timer', S.GUI.CenterOdorTime,...
    'StateChangeConditions', {'Port2Out', 'CenterOdorOff', 'Tup', 'CenterPostOdorDelay'},...
    'OutputActions',[{'BNC2',1,DIOmodule,CenterDIOmsg1},PresentOdor(0)]);
sma = AddState(sma, 'Name', 'CenterOdorOff',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','WaitForCenter'},...
    'OutputActions', [{DIOmodule,CenterDIOmsg2},PresentOdor(0),...
    PreloadOdor(ThisCenterOdor,0)]);
sma = AddState(sma, 'Name', 'CenterPostOdorDelay', ...
    'Timer', S.GUI.StartDelay,...
    'StateChangeConditions', {'Port2Out','WaitForCenter','Tup','GoCue'},...
    'OutputActions', [{DIOmodule,CenterDIOmsg2},PresentOdor(0),...
    PreloadOdor(ThisCenterOdor,0)]);
sma = AddState(sma, 'Name', 'GoCue', ...
    'Timer', 0.05,...
    'StateChangeConditions', {'Tup','Response'},...
    'OutputActions', {'GlobalTimerTrig', 1,DIOmodule,2});

% RESPONSE (CHOICE) --> MAKE SURE STAY IN SIDE FOR AT LEAST A SMALL TIME TO INDICATE CHOICE?
sma = AddState(sma, 'Name', 'Response', ...
    'Timer', S.GUI.OdorDelay,...
    'StateChangeConditions', {'Tup','GracePeriod','Port1In',ChooseLeft,'Port3In',ChooseRight},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'GracePeriod',...
    'Timer', S.GUI.GracePeriod,...
    'StateChangeConditions', {'Tup','NoChoice','Port1In',ChooseLeft,'Port3In',ChooseRight},...
    'OutputActions', {});    

% AFTER CHOICE

% LEFT
sma = AddState(sma, 'Name', 'WaitForOdorLeft', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer5_End','PreloadOdorLeft','Condition8','PreloadOdorLeft'},...
    'OutputActions', {DIOmodule,6});
sma = AddState(sma, 'Name', 'PreloadOdorLeft', ...
    'Timer', OdorHeadstart,...
    'StateChangeConditions', {'Tup',SideOdorStateLeft},...
    'OutputActions', PreloadOdor(LeftSideOdor,1)); % preload left side odor
sma = AddState(sma, 'Name', 'OdorALeft', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayLeft'},...
    'OutputActions', [{DIOmodule,SideDIOmsg1}, PresentOdor(1)]);
sma = AddState(sma, 'Name', 'OdorBLeft', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayLeft'},...
    'OutputActions', [{DIOmodule,SideDIOmsg1}, PresentOdor(1)]);
sma = AddState(sma, 'Name', 'OdorCLeft', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayLeft'},...
    'OutputActions', [{DIOmodule,SideDIOmsg1}, PresentOdor(1)]);
sma = AddState(sma, 'Name', 'OdorDLeft', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayLeft'},...
    'OutputActions', [{DIOmodule,SideDIOmsg1}, PresentOdor(1)]);
sma = AddState(sma, 'Name', 'RewardDelayLeft', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup','DoorOpenCueLeft'},...
    'OutputActions', [{DIOmodule,SideDIOmsg2},doorClose,PresentOdor(1),PreloadOdor(LeftSideOdor,1)]);
sma = AddState(sma, 'Name', 'DoorOpenCueLeft', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','DoorOpenGraceLeft'},...
    'OutputActions', {DIOmodule,1});
sma = AddState(sma, 'Name', 'DoorOpenGraceLeft', ...
    'Timer',doorOpenGrace,...
    'StateChangeConditions', {'Tup','LeftPortCheck'},...
    'OutputActions', {doorOpen});

% LEFT REWARD
sma = AddState(sma, 'Name', 'LeftPortCheck',...
    'Timer',0,...
    'StateChangeConditions',{'Condition4','LeftNotPresent','Condition1',OutcomeStateLeft},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'LeftBigReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery','Condition4','LeftNotPresent'},...
    'OutputActions', {'GlobalTimerTrig', 3}); %, 'GlobalTimerTrig', 3
sma = AddState(sma, 'Name', 'LeftSmallReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery','Condition4','LeftNotPresent'},...
    'OutputActions', {'GlobalTimerTrig', 3}); %, 'GlobalTimerTrig', 3
sma = AddState(sma, 'Name', 'LeftNotPresent', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 2});


% CHOOSE RIGHT
sma = AddState(sma, 'Name', 'WaitForOdorRight', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer5_End','PreloadOdorRight','Condition8','PreloadOdorRight'},...
    'OutputActions', {DIOmodule,6});
sma = AddState(sma, 'Name', 'PreloadOdorRight', ...
    'Timer', OdorHeadstart,...
    'StateChangeConditions', {'Tup',SideOdorStateRight},...
    'OutputActions', PreloadOdor(RightSideOdor,2)); % preload left side odor
sma = AddState(sma, 'Name', 'OdorARight', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayRight'},...
    'OutputActions', [{DIOmodule,SideDIOmsg1}, PresentOdor(2)]);
sma = AddState(sma, 'Name', 'OdorBRight', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayRight'},...
    'OutputActions', [{DIOmodule,SideDIOmsg1}, PresentOdor(2)]);
sma = AddState(sma, 'Name', 'OdorCRight', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayRight'},...
    'OutputActions', [{DIOmodule,SideDIOmsg1}, PresentOdor(2)]);
sma = AddState(sma, 'Name', 'OdorDRight', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','RewardDelayRight'},...
    'OutputActions', [{DIOmodule,SideDIOmsg1}, PresentOdor(2)]);
sma = AddState(sma, 'Name', 'RewardDelayRight', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup','DoorOpenCueRight'},...
    'OutputActions', [{DIOmodule,SideDIOmsg2},doorClose,PresentOdor(2),...
    PreloadOdor(RightSideOdor,2)]);
sma = AddState(sma, 'Name', 'DoorOpenCueRight', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','DoorOpenGraceRight'},...
    'OutputActions', {DIOmodule,1});
sma = AddState(sma, 'Name', 'DoorOpenGraceRight', ...
    'Timer', doorOpenGrace,...
    'StateChangeConditions', {'Tup','RightPortCheck'},...
    'OutputActions', {doorOpen});

% RIGHT REWARD
sma = AddState(sma, 'Name', 'RightPortCheck',...
    'Timer',0,...
    'StateChangeConditions',{'Condition6','RightNotPresent','Condition3',OutcomeStateRight},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'RightBigReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery','Condition6','RightNotPresent'},...
    'OutputActions', {'GlobalTimerTrig', 4});
sma = AddState(sma, 'Name', 'RightSmallReward', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery','Condition6','RightNotPresent'},...
    'OutputActions', {'GlobalTimerTrig', 4});
sma = AddState(sma, 'Name', 'RightNotPresent', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','OutcomeDelivery'},...
    'OutputActions', {'GlobalTimerTrig', 2});

% Waits for max drops time
sma = AddState(sma, 'Name','OutcomeDelivery','Timer',0,...
    'StateChangeConditions',{'GlobalCounter2_End','EndTrial'},...
    'OutputActions',{});

% if no choice during response
sma = AddState(sma, 'Name', 'NoChoice', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer1_End', 'TimeoutOdor', 'Condition7', 'TimeoutOdor'},...
    'OutputActions', {});

% For incorrect choices (left/right on forced trials)
sma = AddState(sma, 'Name', 'Incorrect', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer1_End','TimeoutOdor','Condition7', 'TimeoutOdor'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'TimeoutOdor', ...
    'Timer', S.GUI.OdorTime,...
    'StateChangeConditions', {'Tup','TimeoutRewardDelay'},...
    'OutputActions', {DIOmodule,6});
sma = AddState(sma, 'Name', 'TimeoutRewardDelay', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup','TimeoutOutcome'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'TimeoutOutcome', ...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalCounter2_End','EndTrial'},...
    'OutputActions', {'GlobalTimerTrig', 2});

sma = AddState(sma, 'Name', 'EndTrial', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {'GlobalTimerCancel', 2});

end

%% TRIAL TYPES

function S = UpdateTrialTypes(i,S)
    TrialTypes = S.TrialTypes;
    S.TrialTypes = [TrialTypes(1:i-1); TrialTypes(i-1); TrialTypes(i:end-1)];
    S.RewardTypes = [S.RewardTypes(1:i-1,:); S.RewardTypes(i-1,:); S.RewardTypes(i:end-1,:)];
    S.RandOdorTypes = [S.RandOdorTypes(1:i-1); S.RandOdorTypes(i-1); S.RandOdorTypes(i:end-1)];
end

function S = SetTrialTypes(S,currentTrial)

    global BpodSystem;

    %% Define trial choice types

    maxTrials = S.GUI.SessionTrials;

    typesAvailable = S.GUI.TrialTypes;

    blockSize = 12;
    typeBlockSize = 8;
    choicePercent = 0; infoPercent = 0; randPercent = 0;

    switch typesAvailable 
        case 1
            choicePercent = 1; infoPercent = 0; randPercent = 0;
        case 2
            choicePercent = 0; infoPercent = 1; randPercent = 0;
        case 3
            choicePercent = 0; infoPercent = 0; randPercent = 1;
        case 4
            choicePercent = 0; infoPercent = 0.5; randPercent = 0.5;
        case 5
            choicePercent = 0.334; infoPercent = 0.334; randPercent = 0.334;        
        case 6
            choicePercent = 0; infoPercent = 0.85; randPercent = 0.15;
        case 7
            choicePercent = 0.5; infoPercent = 0.5; randPercent = 0;
        case 8
            choicePercent = 0.5; infoPercent = 0; randPercent = 0.5;        
    end

    % set trial type arrays based on TrialTypes
    choiceBlockSize = round(choicePercent * blockSize);
    infoBlockSize = round(infoPercent * blockSize);
    randBlockSize = round(randPercent * blockSize);

    blockToShuffle = zeros(blockSize,1);

    if choiceBlockSize > 0
        blockToShuffle(1:choiceBlockSize) = 1;
    end

    if infoBlockSize > 0
        if choiceBlockSize > 0
            blockToShuffle(choiceBlockSize+1:choiceBlockSize + infoBlockSize) = 2;
        else
            blockToShuffle(1:infoBlockSize) = 2;
        end
    end
    if randBlockSize > 0
        blockToShuffle(choiceBlockSize + infoBlockSize + 1:end) = 3;
    end

    blocks = ceil(maxTrials/blockSize);
    TrialTypes = zeros(blocks*blockSize,1);

    block=blockToShuffle;

    for n = 1:blocks
        for m = 1:blockSize
            i = randi(blockSize);
            temp = block(m);
            block(m) = block(i);
            block(i) = temp;
        end
        if n == 1
           TrialTypes(1:blockSize) = block; 
        else
            TrialTypes((n-1)*blockSize+1:n*blockSize) = block;
        end
    end

%     TrialTypes = [2; 2; 3; 3; 2; 2; 3; 3; TrialTypes];
    TrialTypes=TrialTypes(1:maxTrials);
    if currentTrial==1
        S.TrialTypes = TrialTypes;
    else
        S.TrialTypes = [S.TrialTypes(1:currentTrial-1); TrialTypes(1:end-currentTrial+1)];
        TrialTypePlotInfo(BpodSystem.GUIHandles.TrialTypePlot,'update',currentTrial,S.TrialTypes);
    end
    

end

function S = SetRewardTypes(S,currentTrial)

    maxTrials = S.GUI.SessionTrials;
    typeBlockSize = 8;    
    
    %% SET REWARD BLOCKS

    infoBigCount = round(S.GUI.InfoRewardProb*typeBlockSize);
    randBigCount = round(S.GUI.RandRewardProb*typeBlockSize);

    infoBlockShuffle = zeros(typeBlockSize,1);
    randBlockShuffle = zeros(typeBlockSize,1);
    randOdorBlockShuffle = zeros(typeBlockSize,1);

    infoBlockShuffle(1:infoBigCount) = 1;
    randBlockShuffle(1:randBigCount) = 1;
    
    if S.GUI.RandRewardProb == 0 | S.GUI.RandRewardProb == 1
        randOdorBigCount = ceil(typeBlockSize/2);
    else
        randOdorBigCount = randBigCount;
    end
    randOdorBlockShuffle(1:randOdorBigCount) = 1;

    typeBlockCount = ceil(maxTrials/typeBlockSize);
    RewardTypes = zeros(typeBlockCount*typeBlockSize,4);
    RandOdorTypes = zeros(typeBlockCount*typeBlockSize,1);

    infoBlock = infoBlockShuffle;
    randBlock = randBlockShuffle;
    randOdorBlock = randOdorBlockShuffle;

    % info choice
    for n = 1:typeBlockCount
        for m = 1:typeBlockSize
            i = randi(typeBlockSize);
            temp = infoBlock(m);
            infoBlock(m) = infoBlock(i);
            infoBlock(i) = temp;
        end
        if n == 1
           RewardTypes(1:typeBlockSize,1) = infoBlock'; 
        else
            RewardTypes((n-1)*typeBlockSize+1:n*typeBlockSize,1) = infoBlock';
        end
    end

    % rand choice
    for n = 1:typeBlockCount
        for m = 1:typeBlockSize
            i = randi(typeBlockSize);
            temp = randBlock(m);
            randBlock(m) = randBlock(i);
            randBlock(i) = temp;
        end
        if n == 1
           RewardTypes(1:typeBlockSize,2) = randBlock'; 
        else
            RewardTypes((n-1)*typeBlockSize+1:n*typeBlockSize,2) = randBlock';
        end
    end

    % info forced
    for n = 1:typeBlockCount
        for m = 1:typeBlockSize
            i = randi(typeBlockSize);
            temp = infoBlock(m);
            infoBlock(m) = infoBlock(i);
            infoBlock(i) = temp;
        end
        if n == 1
           RewardTypes(1:typeBlockSize,3) = infoBlock'; 
        else
            RewardTypes((n-1)*typeBlockSize+1:n*typeBlockSize,3) = infoBlock';
        end
    end

    % rand forced
    for n = 1:typeBlockCount
        for m = 1:typeBlockSize
            i = randi(typeBlockSize);
            temp = randBlock(m);
            randBlock(m) = randBlock(i);
            randBlock(i) = temp;
        end
        if n == 1
           RewardTypes(1:typeBlockSize,4) = randBlock'; 
        else
            RewardTypes((n-1)*typeBlockSize+1:n*typeBlockSize,4) = randBlock';
        end
    end

    % rand odors
    for n = 1:typeBlockCount
        for m = 1:typeBlockSize
            i = randi(typeBlockSize);
            temp = randOdorBlock(m);
            randOdorBlock(m) = randOdorBlock(i);
            randOdorBlock(i) = temp;
        end
        if n == 1
           RandOdorTypes(1:typeBlockSize) = randOdorBlock'; 
        else
            RandOdorTypes((n-1)*typeBlockSize+1:n*typeBlockSize) = randOdorBlock';
        end
    end

    % Trial types (rewards) to pull from
    RewardTypes = RewardTypes(1:maxTrials,:);


    % Rand Odors to pull from
    % RandOdorTypes = repmat(RandOdorTypes,1,4);
    RandOdorTypes = RandOdorTypes(1:maxTrials);

    if currentTrial == 1
        S.RandOdorTypes = RandOdorTypes;
        S.RewardTypes = RewardTypes;
    else
        S.RandOdorTypes = [S.RandOdorTypes(1:currentTrial); RandOdorTypes(1:end-currentTrial)];
        S.RewardTypes = [S.RewardTypes(1:currentTrial,:); RewardTypes(1:end-currentTrial,:)];
    end
end

%% ODOR CONTROL

% to preload, turn off control and turn on other odor (still going to
% exhaust)

function Actions = PreloadOdor(odorID,port)
    switch port
        case 0            
            cmd1 = {'ValveModule1',odorID};
            cmd2 = {'ValveModule2',odorID}; 
            Actions = [cmd1,cmd2];
        case 1
            cmd1 = {'ValveModule1',odorID};
            cmd2 = {'ValveModule2',odorID};
            cmd3 = {'ValveModule4',1};
            Actions = [cmd1,cmd2,cmd3];
        case 2
            cmd1 = {'ValveModule1',odorID};
            cmd2 = {'ValveModule2',odorID};
            cmd3 = {'ValveModule4',2};
            Actions = [cmd1,cmd2,cmd3];            
    end
end

function Actions = PresentOdor(port)
    switch port
        case 0 % center
            Actions = {'ValveModule3',2};
        case 1 % left
            Actions = {'ValveModule3',1};
        case 2 % right
            Actions = {'ValveModule3',3};
    end
end

function TurnOffAllOdors()
    for v = 1:8
        ModuleWrite('ValveModule1',['C' v]);
        ModuleWrite('ValveModule2',['C' v]);
        ModuleWrite('ValveModule3',['C' v]);
    end
    for v = 1:3
        ModuleWrite('ValveModule4',['C' v]);
    end    
end


%% OUTCOME

function [rewardAmount, Outcome] = UpdateOutcome(currentTrial,S,RewardLeft,RewardRight)

    global BpodSystem
    % BpodSystem.Data.RawEvents(currentTrial)
    TrialData = BpodSystem.Data.RawEvents.Trial{currentTrial};
    TrialCounts = BpodSystem.Data.TrialCounts;
    PlotOutcomes = BpodSystem.Data.PlotOutcomes;
    
    trialType = S.TrialTypes(currentTrial);
    infoSide = S.GUI.InfoSide;
    infoBigReward = S.GUI.InfoBigDrops*4;
    infoSmallReward = S.GUI.InfoSmallDrops*4;
    randBigReward = S.GUI.RandBigDrops*4;
    randSmallReward = S.GUI.RandSmallDrops*4;
    rewardAmount = 0;
    x = currentTrial;
    newTrialCounts = TrialCounts;
    newPlotOutcomes = PlotOutcomes;
    
    % Plot outcomes: 2 = no choice, incorrect, info correct, rand correct,
    % not present
    
    % change to no choice, incorrect, info correct big info correct small
    % rand correct big/ not present info big not present info small
    
    if infoSide == 0
        switch trialType
            case 1
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 10;
                    Outcome = 1; % choice no choice
                elseif ~isnan(TrialData.States.WaitForOdorLeft(1))
                    newTrialCounts(1) = TrialCounts(1) + 1; % infochoice
                    
                    if RewardLeft == 1
                        if ~isnan(TrialData.States.LeftBigReward(1))
                            Outcome = 2; % choice info big
                            rewardAmount = infoBigReward;
                            newPlotOutcomes(x) = 1;
                        else
                            newPlotOutcomes(x) = 3;
                            Outcome = 3; % choice info big NP
                        end
                    else
                        if ~isnan(TrialData.States.LeftSmallReward(1))
                            Outcome = 4; % choice info small
                            rewardAmount = infoSmallReward;
                            newPlotOutcomes(x) = 2;
                        else
                            newPlotOutcomes(x) = 4;
                            Outcome = 5; % choice info small NP
                        end
                    end
                else
                   newTrialCounts(2) = TrialCounts(2) + 1; % randChoice
                   newPlotOutcomes(x) = 0;
                   if RewardRight == 1
                        if ~isnan(TrialData.States.RightBigReward(1))
                            Outcome = 6; % choice rand big
                            rewardAmount = randBigReward;
                            newPlotOutcomes(x) = 5;
                        else
                            newPlotOutcomes(x) = 7;
                            Outcome = 7; % choice rand big NP
                        end                       
                   else
                        if ~isnan(TrialData.States.RightSmallReward(1))
                            Outcome = 8; % choice rand small
                            rewardAmount = randSmallReward;
                            newPlotOutcomes(x) = 6;
                        else
                            newPlotOutcomes(x) = 8;
                            Outcome = 9; % choice rand small NP
                        end                       
                   end
                end
                
            case 2
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 10;
                    Outcome = 10; % info no choice
                elseif ~isnan(TrialData.States.WaitForOdorLeft(1))
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                    if RewardLeft == 1
                        if ~isnan(TrialData.States.LeftBigReward(1))
                            Outcome = 11; % info big
                            rewardAmount = infoBigReward;
                            newPlotOutcomes(x) = 1;
                        else
                            newPlotOutcomes(x) = 3;
                            Outcome = 12; % info big NP
                        end
                    else
                        if ~isnan(TrialData.States.LeftSmallReward(1))
                            Outcome = 13; % info small
                            rewardAmount = infoSmallReward;
                            newPlotOutcomes(x) = 2;
                        else
                            newPlotOutcomes(x) = 4;
                            Outcome = 14; % info small NP
                        end
                    end
                else
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                    newPlotOutcomes(x) = 9;
                    Outcome = 15; % info incorrect
                end
                
            case 3
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 10;
                    Outcome = 16; % rand no choice
                elseif ~isnan(TrialData.States.WaitForOdorRight(1))
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                    if RewardRight == 1
                        if ~isnan(TrialData.States.RightBigReward(1))
                            Outcome = 17; % rand big
                            rewardAmount = randBigReward;
                            newPlotOutcomes(x) = 5;
                        else
                            newPlotOutcomes(x) = 7;
                            Outcome = 18; % rand big NP
                        end
                    else
                        if ~isnan(TrialData.States.RightSmallReward(1))
                            Outcome = 19; % rand small
                            rewardAmount = randSmallReward;
                            newPlotOutcomes(x) = 6;
                        else
                            newPlotOutcomes(x) = 8;
                            Outcome = 20; % rand small NP
                        end
                    end
                else
                    newPlotOutcomes(x) = 9;
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                    Outcome = 21; % rand incorrect
                end
        end
        
    else
        switch trialType
            case 1
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 10;
                    Outcome = 1; % choice no choice
                elseif ~isnan(TrialData.States.WaitForOdorRight(1))
                    newTrialCounts(1) = TrialCounts(1) + 1; % infochoice
                    if RewardRight == 1
                        if ~isnan(TrialData.States.RightBigReward(1))
                            Outcome = 2; % choice info big
                            rewardAmount = infoBigReward;
                            newPlotOutcomes(x) = 1;
                        else
                            newPlotOutcomes(x) = 3;
                            Outcome = 3; % choice info big NP
                        end
                    else
                        if ~isnan(TrialData.States.RightSmallReward(1))
                            Outcome = 4; % choice info small
                            rewardAmount = infoSmallReward;
                            newPlotOutcomes(x) = 2;
                        else
                            newPlotOutcomes(x) = 4;
                            Outcome = 5; % choice info small NP
                        end
                    end
                else
                    newTrialCounts(2) = TrialCounts(2) + 1; % randChoice
                   if RewardLeft == 1
                        if ~isnan(TrialData.States.LeftBigReward(1))
                            Outcome = 6; % choice rand big
                            rewardAmount = randBigReward;
                            newPlotOutcomes(x) = 5;
                        else
                            newPlotOutcomes(x) = 7;
                            Outcome = 7; % choice rand big NP
                        end                       
                   else
                        if ~isnan(TrialData.States.LeftSmallReward(1))
                            Outcome = 8; % choice rand small
                            rewardAmount = randSmallReward;
                            newPlotOutcomes(x) = 6;
                        else
                            newPlotOutcomes(x) = 8;
                            Outcome = 9; % choice rand small NP
                        end                       
                   end
                end
                
            case 2
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 10;
                    Outcome = 10; % info no choice
                elseif ~isnan(TrialData.States.WaitForOdorRight(1))
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                    if RewardRight == 1
                        if ~isnan(TrialData.States.RightBigReward(1))
                            Outcome = 11; % info big
                            rewardAmount = infoBigReward;
                            newPlotOutcomes(x) = 1;
                        else
                            newPlotOutcomes(x) = 3;
                            Outcome = 12; % info big NP
                        end
                    else
                        if ~isnan(TrialData.States.RightSmallReward(1))
                            Outcome = 13; % info small
                            rewardAmount = infoSmallReward;
                            newPlotOutcomes(x) = 2;
                        else
                            newPlotOutcomes(x) = 4;
                            Outcome = 14; % info small NP
                        end
                    end
                else
                    newTrialCounts(3) = TrialCounts(3) + 1; % infoforced
                    newPlotOutcomes(x) = 9;
                    Outcome = 15; % info incorrect
                end
                
            case 3
                if ~isnan(TrialData.States.NoChoice(1))
                    newPlotOutcomes(x) = 10;
                    Outcome = 16; % rand no choice
                elseif ~isnan(TrialData.States.WaitForOdorLeft(1))
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                    if RewardLeft == 1
                        if ~isnan(TrialData.States.LeftBigReward(1))
                            Outcome = 17; % rand big
                            rewardAmount = randBigReward;
                            newPlotOutcomes(x) = 5;
                        else
                            newPlotOutcomes(x) = 7;
                            Outcome = 18; % rand big NP
                        end
                    else
                        if ~isnan(TrialData.States.LeftSmallReward(1))
                            Outcome = 19; % rand small
                            rewardAmount = randSmallReward;
                            newPlotOutcomes(x) = 6;
                        else
                            newPlotOutcomes(x) = 8;
                            Outcome = 20; % rand small NP
                        end
                    end
                else
                    newTrialCounts(4) = TrialCounts(4) + 1; % randforced
                    newPlotOutcomes(x) = 9;
                    Outcome = 21; % rand incorrect
                end
        end            
    end    
    BpodSystem.Data.TrialCounts = newTrialCounts;
    BpodSystem.Data.PlotOutcomes = newPlotOutcomes;
end
        
%% TRIAL EVENT PLOTTING COLORS

function state_colors = getStateColors(thisInfoSide)
    if thisInfoSide == 0
        state_colors = struct( ...
            'InterTrialInterval',[0.8 0.8 0.8],...
            'CenterOdorPreload',[0.8 0.8 0.8],...
            'StartTrial', [0 0 0],...
            'WaitForCenter',[255 240 245]./255,...
            'CenterDelay', [255	255 102]./255,...
            'CenterOdor',[255 255 102]./255,...
            'CenterOdorOff',[255 255 102]./255,...
            'CenterPostOdorDelay',[255 255 102]./255,...
            'GoCue',[0 1 0],...
            'Response',[1 1 0.8],...
            'GracePeriod',[1 1 0.8],...
            'WaitForOdorLeft',[216 191 216]./255,...
            'PreloadOdorLeft',[216 191 216]./255,...            
            'OdorALeft',[128 0 128]./255,...
            'OdorBLeft',[128 0 128]./255,...
            'OdorCLeft',[128 0 128]./255,...
            'OdorDLeft',[128 0 128]./255,...
            'RewardDelayLeft',[216 191 216]./255,...
            'DoorOpenCueLeft',[216 191 216]./255,...
            'DoorOpenGraceLeft',[216 191 216]./255,...
            'LeftPortCheck',[216 191 216]./255,...
            'LeftBigReward',[0 1 0],...
            'LeftSmallReward',[1 0 1],...
            'IncorrectLeft',[0 0 0],...
            'LeftNotPresent',[1 1 1],...
            'WaitForOdorRight',[1 0.8 0],... % 1 0.8 0 [255 228 189]./255
            'PreloadOdorRight',[1 0.8 0],...
            'OdorARight',[255 140 0]./255,...
            'OdorBRight',[255 140 0]./255,...
            'OdorCRight',[255 140 0]./255,...
            'OdorDRight',[255 140 0]./255,...
            'RewardDelayRight',[1 0.8 0],...
            'DoorOpenCueRight',[1 0.8 0],...
            'DoorOpenGraceRight',[1 0.8 0],...
            'RightPortCheck',[1 0.8 0],...
            'RightBigReward',[0 1 0],...
            'RightSmallReward',[1 0 1],...
            'IncorrectRight',[0 0 0],...    
            'RightNotPresent',[1 1 1],...
            'OutcomeDelivery',[0 0 1],...
            'NoChoice',[0 1 1],...
            'Incorrect',[1 0 0],...
            'TimeoutOdor',[0.4 0.4 0.4],...
            'TimeoutRewardDelay',[0.2 0.2 0.2],...
            'TimeoutOutcome',[0.4 0.4 0.4],...
            'EndTrial',[0 0 0]);
    else
        state_colors = struct( ...
            'InterTrialInterval',[0.8 0.8 0.8],...
            'CenterOdorPreload',[0.8 0.8 0.8],...            
            'StartTrial', [0 0 0],...
            'WaitForCenter',[255 240 245]./255,...
            'CenterDelay', [255	255 102]./255,...
            'CenterOdor',[255 255 102]./255,...
            'CenterOdorOff',[255 255 102]./255,...
            'CenterPostOdorDelay',[255 255 102]./255,...
            'GoCue',[0 1 0],...
            'Response',[1 1 0.8],...
            'GracePeriod',[1 1 0.8],...
            'WaitForOdorLeft',[1 0.8 0],...
            'PreloadOdorLeft',[1 0.8 0],...
            'OdorALeft',[255 140 0]./255,...
            'OdorBLeft',[255 140 0]./255,...
            'OdorCLeft',[255 140 0]./255,...
            'OdorDLeft',[255 140 0]./255,...
            'RewardDelayLeft',[1 0.8 0],...
            'DoorOpenCueLeft',[1 0.8 0],...
            'DoorOpenGraceLeft',[1 0.8 0],...
            'LeftPortCheck',[1 0.8 0],...
            'LeftBigReward',[0 1 0],...
            'LeftSmallReward',[1 0 1],...
            'IncorrectLeft',[0 0 0],...
            'LeftNotPresent',[1 1 1],...
            'WaitForOdorRight',[216 191 216]./255,...
            'PreloadOdorRight',[216 191 216]./255,...            
            'OdorARight',[128 0 128]./255,...
            'OdorBRight',[128 0 128]./255,...
            'OdorCRight',[128 0 128]./255,...
            'OdorDRight',[128 0 128]./255,...
            'RewardDelayRight',[216 191 216]./255,...
            'DoorOpenCueRight',[216 191 216]./255,...
            'DoorOpenGraceRight',[216 191 216]./255,...
            'RightPortCheck',[216 191 216]./255,...
            'RightBigReward',[0 1 0],...
            'RightSmallReward',[1 0 1],...
            'IncorrectRight',[0 0 0],...    
            'RightNotPresent',[1 1 1],...
            'OutcomeDelivery',[0 0 1],...
            'NoChoice',[0 1 1],...
            'Incorrect',[1 0 0],...
            'TimeoutOdor',[0.4 0.4 0.4],...
            'TimeoutRewardDelay',[0.2 0.2 0.2],...
            'TimeoutOutcome',[0.4 0.4 0.4],...
            'EndTrial',[0 0 0]);        
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

function closeDoors()
    global BpodSystem
    modules = BpodSystem.Modules.Name;
    DIOmodule = [modules(strncmp('DIO',modules,3))];
    DIOmodule = DIOmodule{1};
    ModuleWrite(DIOmodule,[252 30]);
    ModuleWrite(DIOmodule,[250 30]);
    ModuleWrite(DIOmodule,[248 30]);
end

function openDoors()
    global BpodSystem
    modules = BpodSystem.Modules.Name;
    DIOmodule = [modules(strncmp('DIO',modules,3))];
    DIOmodule = DIOmodule{1};
    ModuleWrite(DIOmodule,[251 5]);
    ModuleWrite(DIOmodule,[249 5]);
    ModuleWrite(DIOmodule,[247 5]);
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