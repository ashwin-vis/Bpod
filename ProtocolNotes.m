%{

FIX figures, put them all w/ GUIData, Handles, Protocol Figures within
their own fxns? Or put that for spacing w/in protocol??

Add outcome plot

FIX MAIN LOOP FLOW!! OK if change warning in trial manager object!!
Is state machine/main loop functioning correctly w/ current vs next trial type and
outcome/reward?

double check turning side odor off

BpodSystem.GUIData.ParameterGUI.ParamNames
BpodSystem.GUIData.ParameterGUI.nParams
BpodSystem.GUIData.ParameterGUI.LastParamValues
BpodSystem.GUIHandles.ParameterGUI.Labels
BpodSystem.GUIHandles.ParameterGUI.Params
BpodSystem.ProtocolFigures.ParameterGUI

S.GUIPanels
S.GUI = has the parameters


---------------


Params

ChooseLeft
ChooseRight
StimulusOutput - for now, light
CenterOdor
RewardLeft
RewardRight
RightSideOdor
LeftSideOdor
OutcomeStateLeft
OutcomeStateRight
LeftRewardDrops
RightRewardDrops

GlobalTimer1 = Odor delay
Condition7 = when it expires

For time of max drops but with no water:
GlobalCounter2 = globaltimer2 end, maxdrops

Left reward:
GlobalTimer 3 = valve time for reward drops
global counter 3 = counts those for left drops

Right reward:
4"" for right



incorrect = wrong choice, duration odor delay
nochoice = no choice, duration odor delay
both then go to timeout odor, timeout reward delay, timeout reward (global
timer 2)

outcomestate:
rightbigreward-timer 4
rightsmallreward-timer 4
incorrectright-timer 2 NEVER HAPPENS?
rightnotpresent - timer 2 NEVER HAPPENS?
%}
