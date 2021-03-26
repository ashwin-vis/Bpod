%{
----------------------------------------------------------------------------

T

----------------------------------------------------------------------------
%}
function CenterTraining

global BpodSystem

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 1000;
    S.GUI.RewardDelay = 0.2;
    S.GUI.RewardAmount = 4; %uL
    S.GUI.ITI = 2;
end

%% Initialize plots

BpodNotebook('init');
BpodParameterGUI('init', S); % Initialize parameter GUI plugin
TotalRewardDisplay('init');

%% MAIN TRIAL LOOP

MaxTrials = S.GUI.SessionTrials;

%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
   S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
   R = GetValveTimes(S.GUI.RewardAmount, [2]);
   ValveTime = R(1);
   
   MaxTrials = S.GUI.SessionTrials;
   
    %--- Assemble state machine
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'WaitForPoke', ... % This example state does nothing, and ends after 0 seconds
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'Delay'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'Delay', ... % This example state does nothing, and ends after 0 seconds
        'Timer', S.GUI.RewardDelay,...
        'StateChangeConditions', {'Port2Out', 'WaitForPoke', 'Tup', 'Reward'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Reward', ... % This example state does nothing, and ends after 0 seconds
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup','ITI'},...
        'OutputActions', {'ValveState', 2});  
    sma = AddState(sma, 'Name', 'ITI', ... % This example state does nothing, and ends after 0 seconds
        'Timer', S.GUI.ITI,...
        'StateChangeConditions', {'Tup','>exit'},...
        'OutputActions', {});    
    
    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events
    
    %--- Package and save the trial's data, update plots
    if ~isempty(fieldnames(RawEvents)) % If you didn't stop the session manually mid-trial
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Adds raw events to a human-readable data struct
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data);
        TotalRewardDisplay('add',S.GUI.RewardAmount);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        
        %--- Typically a block of code here will update online plots using the newly updated BpodSystem.Data
        
    end
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end