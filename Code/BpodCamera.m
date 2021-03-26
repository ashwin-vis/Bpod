info=imaqhwinfo('winvideo');
dev_info = info.DeviceInfo(1);
dev_info.SupportedFormats;

vid = videoinput('winvideo',1,'MJPG_1920x1080');
src = getselectedsource(vid);
% src.AcquisitionFrameRateEnable = 'True';
% src.AcquisitionFrameRateAbs = 30;
vid.FramesPerTrigger = Inf;
triggerconfig(vid, 'manual');

%BpodSystem.Path.DataFolder;
% DataPath = fullfile(BpodSystem.Path.DataFolder,subjectName);
% mkdir(DataPath, protocolName);
% mkdir(fullfile(DataPath,protocolName,'Session Data'))
% mkdir(fullfile(DataPath,protocolName,'Session Settings'))
% DateInfo = datestr(now, 30); 
% DateInfo(DateInfo == 'T') = '_';
% FileName = [subjectName '_' protocolName '_' DateInfo '.mat'];
% DataFolder = fullfile(BpodSystem.Path.DataFolder,subjectName,protocolName,'Session Data');
% if ~exist(DataFolder)
%     mkdir(DataFolder);
% end
% BpodSystem.Path.CurrentDataFile = fullfile(DataFolder, FileName);

logfile = VideoWriter('testvid.avi','Motion JPEG AVI');
set(logfile,'FrameRate',30);
vid.DiskLogger = logfile;
set(vid,'LoggingMode','disk');
% imaqmem(4e9);

vidRes = get(vid, 'VideoResolution');
imWidth = vidRes(1);
imHeight = vidRes(2);
nBands = get(vid, 'NumberOfBands');
hImage = image( zeros(imHeight, imWidth, nBands) );

preview(vid,hImage);

start(vid);
trigger(vid);

pause(30);

stop(vid);

flushdata(vid);
delete(vid);
clear vid;


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% global vid
% 
% makeVidObject;
% generatePreviewInGui;
% 
% figSize = get(gca,'Position');
% figWidth = figSize(3);
% figHeight = figSize(4);
% vidRes = get(vid, 'VideoResolution');
% imWidth = vidRes(1);
% imHeight = vidRes(2);
% % set(gca,'unit','pixels',...
% %         'position',[ (335+(figWidth - imWidth)/2)...
% %                      (330+(figHeight - imHeight)/2)...
% %                        imWidth imHeight ]);
% set(gca,'unit','pixels',...
%     'position',[ (1100+(figWidth - imWidth)/2)...
%     (200+(figHeight - imHeight)/2)...
%     imWidth imHeight ]);
% 
% function generatePreviewInGui
% global vid
% 
% % Create the text label for the timestamp
% %hTextLabel = uicontrol('style','text','String','Timestamp', ...
% %    'Units','normalized','fontsize',16,...
% %    'Position',[0.05 .04 .15 .08]); %[0.85 -.04 .15 .08]);
% 
% % Create the image object in which you want to
% % display the video preview data.
% vidRes = get(vid, 'VideoResolution');
% imWidth = vidRes(1);
% imHeight = vidRes(2);
% nBands = get(vid, 'NumberOfBands');
% hImage = image( zeros(imHeight, imWidth, nBands) );
%           
% % Set up the update preview window function.
% %setappdata(hImage,'UpdatePreviewWindowFcn',@mypreview_fcn);
% 
% % Make handle to text label available to update function.
% %setappdata(hImage,'HandleToTimestampLabel',hTextLabel);
% 
% preview(vid, hImage);
% 
% function startVid
% global trialParams vid fileStruct trialCounter logfile vidCounter
% 
% fileStruct.fileName = strcat(fileStruct.folder,fileStruct.genotype,'_exp_',fileStruct.expNum,'_',char(fileStruct.thisTrialState),'_vid_',num2str(vidCounter)) ;
% %logfile = VideoWriter(fileStruct.fileName, 'Motion JPEG AVI');
% %set(logfile,'FrameRate',25);
% %vid.DiskLogger = logfile;
% 
% % vid = videoinput('gige', 1, 'Mono8');
% % src = getselectedsource(vid);
% % src.AcquisitionFrameRateEnable = 'True';
% % src.AcquisitionFrameRateAbs = 25;
% % vid.FramesPerTrigger = 100;
% % triggerconfig(vid, 'manual');
% logfile = VideoWriter(fileStruct.fileName, 'Motion JPEG AVI'); %'Uncompressed AVI'); %
% set(logfile,'FrameRate',25);
% vid.DiskLogger = logfile;
% set(vid,'LoggingMode','disk');
% %vid.ROIPosition = [593 1011 596 114];
% start(vid);
% trigger(vid);
% trialCounter = 0; %number of manually started trials
% fileStruct.trueCStimes = [];
% fileStruct.trueUStimes = [];
% fileStruct.trueStartTimes = [];
% trialParams.presentedOdor = [];
% trialParams.isAversiveTrial = [];
% 
% function makeVidObject
% global vid vidCounter fileStruct logfile
% 
% 
% 
% % -- BASLER GigE CAMERA ----------------
% vid = videoinput('gige', 1, 'Mono8');
% src = getselectedsource(vid);
% %src.AcquisitionFrameRateAbs = 25;
% src.AcquisitionFrameRateEnable = 'True';
% src.AcquisitionFrameRateAbs = 25;
% vid.FramesPerTrigger = Inf;
% triggerconfig(vid, 'manual');
% 
% vid.ROIPosition = [930 350 360 1100]; 
% %vid.ROIPosition = [760 420 427 1100]; %[760 720 425 800];
% 
% vidCounter = vidCounter+1;
% fileStruct.thisTrialState = fileStruct.trialStructure{1}; 
% %folder = ('C:\2014_02_04\'); %I changed this
% fileStruct.fileName = strcat(fileStruct.folder,fileStruct.genotype,'_exp_',fileStruct.expNum,'_',char(fileStruct.thisTrialState),'_vid_',num2str(vidCounter)) ;
% logfile = VideoWriter([fileStruct.folder,'Edit Text_exp_1_testing_vid_2.avi'],'Motion JPEG AVI');
% set(logfile,'FrameRate',25);
% vid.DiskLogger = logfile;
% set(vid,'LoggingMode','disk');
% imaqmem(4e9);
% 
% function stopVid
% global trialParams vid trialCounter
% 
% stop(vid)
% trialParams.numTrials = trialCounter;
% %[fileStruct.flyvid, fileStruct.timeStamp] = getdata(vid);
% %annotateVideo;
% saveFile;
% flushdata(vid);
% delete(vid);
% clear vid;
% makeVidObject;
% generatePreviewInGui;