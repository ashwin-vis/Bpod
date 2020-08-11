%{
----------------------------------------------------------------------------

T

----------------------------------------------------------------------------
%}
function ControlTest

global BpodSystem

%% Define parameters

S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SessionTrials = 1000;
    S.GUI.OdorTime = 3;
    S.GUI.OdorInterval = 4;
    S.GUI.OdorID = 0;
end

%% Initialize plots

BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% MAIN TRIAL LOOP

MaxTrials = S.GUI.SessionTrials;


%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
   S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
   
   MaxTrials = S.GUI.SessionTrials;
   odor = S.GUI.OdorID; % logic here to cycle odors
   
   % SETUP ODORS
%    cmd = [{'ValveModule1',1},{'ValveModule1',2}];
   LoadSerialMessages('ValveModule1',{[1 2],[3 4],[5 6]});
   
   switch odor
       case 0
           msg = 1;
       case 1
           msg = 2;
       case 2
           msg = 3;
   end
   
    %--- Assemble state machine
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'OdorOn', ...
        'Timer', S.GUI.OdorTime,...
        'StateChangeConditions', {'Tup', 'OdorOff'},...
        'OutputActions',{'ValveModule1',msg});            
%         'OutputActions', [{'PWM2',255}, turnOnOdor(odor)]);  
    sma = AddState(sma, 'Name', 'OdorOff', ...
        'Timer', S.GUI.OdorInterval,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {'ValveModule1',msg}); 
%         'OutputActions', turnOnOdor(odor));      
    
    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMatrix; % Run the trial and return events
    
    %--- Package and save the trial's data, update plots
    if ~isempty(fieldnames(RawEvents)) % If you didn't stop the session manually mid-trial
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Adds raw events to a human-readable data struct
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        
        %--- Typically a block of code here will update online plots using the newly updated BpodSystem.Data
        
    end
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        ModuleWrite('ValveModule1',['C' 1]);
        ModuleWrite('ValveModule1',['C' 2]);
        ModuleWrite('ValveModule1',['C' 3]);
        ModuleWrite('ValveModule1',['C' 4]);
        ModuleWrite('ValveModule1',['C' 5]);
        ModuleWrite('ValveModule1',['C' 6]);
        return
    end
end


end

%% ODOR CONTROL

%% GENERAL ODOR

function OdorOutputActions = turnOnOdor(odorID)
    switch odorID
        case 0
            cmd1 = {'ValveModule1',1}; % before center control
            cmd2 = {'ValveModule1',2}; % after center control  
        case 1
            cmd1 = {'ValveModule1',3}; % before left control
            cmd2 = {'ValveModule1',4}; % after left control              
        case 2
            cmd1 = {'ValveModule1',5}; % before right control
            cmd2 = {'ValveModule1',6}; % after right control  
    end
    OdorOutputActions = [cmd1, cmd2];
end

