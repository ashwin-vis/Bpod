%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
function EventsPlot(varargin)

global BpodSystem
    
action = varargin{1};

switch action

    %% init    
    case 'init'
        
        state_colors = varargin{2};
%         poke_colors = varargin{3};

        BpodSystem.ProtocolFigures.EventsPlot = figure('Position', [50 50 1000 500],'name','TrialEvents','numbertitle','off', 'MenuBar', 'none', 'Resize', 'on');

        BpodSystem.GUIHandles.EventsPlot.StateColors= state_colors;
%         BpodSystem.GUIHandles.EventsPlot.PokeColors= poke_colors;

        
        BpodSystem.GUIHandles.EventsPlot.AlignOnLabel = uicontrol('Style', 'text','String','align on:', 'Position', [30 70 60 20], 'FontWeight', 'normal', 'FontSize', 10,'FontName', 'Arial');
        BpodSystem.GUIHandles.EventsPlot.AlignOnMenu = uicontrol('Style', 'popupmenu','Value',7, 'String', fields(state_colors), 'Position', [95 70 150 20], 'FontWeight', 'normal', 'FontSize', 10, 'BackgroundColor','white', 'FontName', 'Arial','Callback', {@EventsPlot, 'alignon'});
        
        BpodSystem.GUIHandles.EventsPlot.LeftEdgeLabel = uicontrol('Style', 'text','String','start', 'Position', [30 35 40 20], 'FontWeight', 'normal', 'FontSize', 10,'FontName', 'Arial');
        BpodSystem.GUIHandles.EventsPlot.LeftEdge = uicontrol('Style', 'edit','String',-2, 'Position', [75 35 40 20], 'FontWeight', 'normal', 'FontSize', 10, 'BackgroundColor','white', 'FontName', 'Arial','Callback', {@EventsPlot, 'time_axis'});
        
        BpodSystem.GUIHandles.EventsPlot.LeftEdgeLabel = uicontrol('Style', 'text','String','end', 'Position', [30 10 40 20], 'FontWeight', 'normal', 'FontSize', 10, 'FontName', 'Arial');
        BpodSystem.GUIHandles.EventsPlot.RightEdge = uicontrol('Style', 'edit','String',14, 'Position', [75 10 40 20], 'FontWeight', 'normal', 'FontSize', 10, 'BackgroundColor','white', 'FontName', 'Arial','Callback', {@EventsPlot, 'time_axis'});
         
        BpodSystem.GUIHandles.EventsPlot.LastnLabel = uicontrol('Style', 'text','String','N trials', 'Position', [130 33 50 20], 'FontWeight', 'normal', 'FontSize', 10, 'FontName', 'Arial');
        BpodSystem.GUIHandles.EventsPlot.Lastn = uicontrol('Style', 'edit','String',5, 'Position', [185 35 40 20], 'FontWeight', 'normal', 'FontSize', 10, 'BackgroundColor','white', 'FontName', 'Arial','Callback', {@EventsPlot, 'time_axis'});
        
        BpodSystem.GUIHandles.EventsPlot.EventsPlotAxis = axes('Position', [0.1 0.38 0.8 0.54],'Color', 0.3*[1 1 1]);

        
        fnames = fieldnames(state_colors);
        for j=1:str2double(get(BpodSystem.GUIHandles.EventsPlot.Lastn, 'String'))
            for i=1:length(fnames)
                BpodSystem.GUIHandles.EventsPlot.StateHandle(j).(fnames{i}) = fill([(i-1) (i-1)+2 (i-1) (i-1)],[(j-1) (j-1) (j-1)+1 (j-1)+1],state_colors.(fnames{i}),'EdgeColor','none');
                set(BpodSystem.GUIHandles.EventsPlot.StateHandle(j).(fnames{i}),'Visible','off');
                hold on;
            end
        end
        
        axis([str2double(get(BpodSystem.GUIHandles.EventsPlot.LeftEdge,'String')) str2double(get(BpodSystem.GUIHandles.EventsPlot.RightEdge,'String')) 0 length(fnames)-1])
        
        BpodSystem.GUIHandles.EventsPlot.ColorAxis = axes('Position', [0.15 0.29 0.7 0.03]);
         
        % plot reference colors
        fnames = fieldnames(state_colors);
        for i=1:length(fnames)
            fill([i-0.9 i-0.9 i-0.1 i-0.1], [0 1 1 0], state_colors.(fnames{i}),'EdgeColor','none');
            if length(fnames{i})< 10
                legend = fnames{i};
            else
                legend = fnames{i}(1:10);
            end
            hold on; t = text(i-0.5, -0.5, legend);
            set(t, 'Interpreter', 'none', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'Rotation', 45);
            set(gca, 'Visible', 'off');
        end
        ylim([0 1]); xlim([0 length(fnames)]);
        
        
  %% update    
  case 'update'      
    figure(BpodSystem.ProtocolFigures.EventsPlot);axes(BpodSystem.GUIHandles.EventsPlot.EventsPlotAxis)
    current_trial = BpodSystem.Data.nTrials;
    last_n = str2double(get(BpodSystem.GUIHandles.EventsPlot.Lastn,'String'));
%    fnames = fieldnames(BpodSystem.Data.RawEvents.Trial{1,BpodSystem.Data.nTrials}.States);
        
    for j=1:last_n
        
        fnames = fieldnames(BpodSystem.Data.RawEvents.Trial{1,BpodSystem.Data.nTrials}.States);
        trial_toplot = current_trial-j+1;
        
        if trial_toplot>0
            thisTrialStateNames = get(BpodSystem.GUIHandles.EventsPlot.AlignOnMenu,'String');
            thisStateName = thisTrialStateNames{get(BpodSystem.GUIHandles.EventsPlot.AlignOnMenu, 'Value')};
            aligning_time = BpodSystem.Data.RawEvents.Trial{trial_toplot}.States.(thisStateName)(1);            
            for i=1:length(fnames)
%                 tic
                t = BpodSystem.Data.RawEvents.Trial{trial_toplot}.States.(fnames{i})-aligning_time;
%                 toc
                if t(2)-t(1)<0.0001
                    x_vertices = [t(1)-0.1 t(2)+0.1 t(2)+0.1 t(1)-0.1]';
                else
                    x_vertices = [t(1) t(2) t(2) t(1)]';
                end
                y_vertices = [repmat(last_n-j,1,2)+0.1 repmat(last_n-j+1,1,2)-0.1]';
                
                if size(BpodSystem.GUIHandles.EventsPlot.StateHandle,2)<last_n % if the number of trial to plot (last_n) is changed from the gui.
                    BpodSystem.GUIHandles.EventsPlot.StateHandle(last_n).(fnames{i}) = fill([0 0 0 0],[0 0 0 0],BpodSystem.GUIHandles.EventsPlot.StateColors.(fnames{i}),'EdgeColor','none');
                end        
                
                if ~isfield(BpodSystem.GUIHandles.EventsPlot.StateHandle(last_n-j+1),fnames{i}) %if the field was not initialized, paint it white
                    BpodSystem.GUIHandles.EventsPlot.StateHandle(last_n-j+1).(fnames{i}) = fill([0 0 0 0],[0 0 0 0],[1 1 1],'EdgeColor','none');
                    set(BpodSystem.GUIHandles.EventsPlot.StateHandle(last_n-j+1).(fnames{i}), 'Vertices', [x_vertices y_vertices]);
                end
                
                if isempty(BpodSystem.GUIHandles.EventsPlot.StateHandle(last_n-j+1).(fnames{i})) % if the number of trial to plot (last_n) is changed from the gui.
                    BpodSystem.GUIHandles.EventsPlot.StateHandle(last_n-j+1).(fnames{i}) = fill([0 0 0 0],[0 0 0 0],BpodSystem.GUIHandles.EventsPlot.StateColors.(fnames{i}),'EdgeColor','none');
                end                
                set(BpodSystem.GUIHandles.EventsPlot.StateHandle(last_n-j+1).(fnames{i}),'Vertices', [x_vertices y_vertices],'Visible', 'on');
            end
        end
    end    
    set(BpodSystem.GUIHandles.EventsPlot.EventsPlotAxis, 'XLim', [str2double(get(BpodSystem.GUIHandles.EventsPlot.LeftEdge,'String')), str2double(get(BpodSystem.GUIHandles.EventsPlot.RightEdge,'String'))]);
    set(BpodSystem.GUIHandles.EventsPlot.EventsPlotAxis,'YLim', [0 last_n]);    
end
