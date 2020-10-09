function varargout = Raw_Viewer(varargin)
%% A viewer GUI for quickly looking at Intan RHD recordings
% Mainly made to work out how memory mapping works
% Idea is that it should be really fast, memory map large files and do all
% processing only as needed

%% Matlab Generated Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Raw_Viewer_OpeningFcn, ...
                   'gui_OutputFcn',  @Raw_Viewer_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before Raw_Viewer is made visible.
function Raw_Viewer_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Raw_Viewer (see VARARGIN)

% Choose default command line output for Raw_Viewer
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

set(handles.FileDirectory_Box,'String',pwd)


Check_Directory(handles)



function Check_Directory(handles)
msg = '';

% Check the current directory for relevant files
matFile    = dir('*.mat');
headerFile = dir('*.rhd');

amplifierFile = dir('amplifier.dat');
timestampFile = dir('time.dat');
eventFile     = dir('digitalin.dat');


fileStruct = struct('matFile',matFile,'headerFile',headerFile,...
             'amplifierFile',amplifierFile,'timestampFile',timestampFile,...
             'eventFile',eventFile);
setappdata(handles.figure1,'fileStruct',fileStruct);


if isempty(headerFile)
    msg = 'No info.rhd file in this directory';
    set(handles.Channels_Box,'String','0')
    set(handles.Channels_Box,'Enable','off')
else
    intanRec = intanHeader(filepath(headerFile));
end

% Parse the header for useful info
recInfo.numChans   = length(intanRec.amplifier_channels);
recInfo.numSamples = amplifierFile.bytes / recInfo.numChans / 2; % Int16 data has 2 bytes per sample, per channel
recInfo.sRate      = intanRec.frequency_parameters.amplifier_sample_rate;


setappdata(handles.figure1,'intanRec',intanRec);
setappdata(handles.figure1,'recInfo',recInfo);

if isempty(matFile)
    msg = [msg sprintf('\n') 'No .mat file containing recording & electrode info in this directory'];
    setappdata(handles.figure1,'mfile',0);
else
    setappdata(handles.figure1,'mfile',1);
end


if ~isempty(amplifierFile) && ~isempty(timestampFile)
    set(handles.LoadData_Button,'enable','on')
end
set(handles.Status_Text,'String',msg);





% --- Outputs from this function are returned to the command line.
function varargout = Raw_Viewer_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in LoadData_Button.
function LoadData_Button_Callback(hObject, eventdata, handles)
% hObject    handle to LoadData_Button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

cla(handles.DataAxes);

% Get some needed variables
fileStruct = getappdata(handles.figure1,'fileStruct');
intanRec   = getappdata(handles.figure1,'intanRec');
recInfo    = getappdata(handles.figure1,'recInfo');

amplifierFilePath = [fileStruct.amplifierFile.folder filesep ...
                     fileStruct.amplifierFile.name];

                 
% Memory map the recording file 
amplifierMap = memmapfile(amplifierFilePath,...
               'Format', {
               'int16', [recInfo.numChans recInfo.numSamples], 'data'
               });
 
setappdata(handles.figure1,'amplifierMap',amplifierMap);

% Load the timestamps and events if they exist
[eventData, timestamps] = intanEventTimes(intanRec, ...
    fileStruct.eventFile, fileStruct.timestampFile, true);

setappdata(handles.figure1,'eventData',eventData);
setappdata(handles.figure1,'timestamps',timestamps);
           
recInfo.times = timestamps([1 end]);
setappdata(handles.figure1,'recInfo',recInfo);

% if getappdata(handles.figure1,'mfile')
%     try
%         mfiles = dir('*.mat');
%         load(mfiles.name,'trial')
%         setappdata(handles.figure1,'trial',trial)
%         if isfield(trial,'Electrode')
%             setappdata(handles.figure1,'Electrode',trial.Electrode)
%         end
%     end
% end

SetupAxes(handles)



function SetupAxes(handles)

intanRec  = getappdata(handles.figure1,'intanRec');
recInfo   = getappdata(handles.figure1,'recInfo');
eventData = getappdata(handles.figure1,'eventData');

XMax = recInfo.times(2);
numChans = recInfo.numChans;

PlotSettings.Stats    = CalculateStats(getappdata(handles.figure1,'amplifierMap'));
PlotSettings.Channels = {intanRec.amplifier_channels.custom_channel_name};
PlotSettings.ScaleFactor = str2num(get(handles.YScale,'String'));


if XMax > 20
    XWidth = 10;
elseif XMax > 10
    XWidth = 5;
else
    XWidth = XMax;
end

if numChans >= 64
    ChanHeight = 32;
elseif numChans >= 32
    ChanHeight = 16;
elseif numChans >= 16
    ChanHeight = 8;
else
    ChanHeight = numChans;
end

PlotSettings.XPosition    = 0; 
PlotSettings.XMax         = XMax;
PlotSettings.XWidth       = XWidth;
PlotSettings.ChanPosition = 1;
PlotSettings.numChans     = numChans;
PlotSettings.ChanHeight   = ChanHeight;

set(handles.ChannelRange_Value,'String',num2str(PlotSettings.ChanHeight));

set(handles.TimeStart_Value,'String',num2str(PlotSettings.XPosition));
set(handles.TimeRange_Value,'String',num2str(PlotSettings.XWidth));

setappdata(handles.figure1,'PlotSettings',PlotSettings);

set(handles.DataAxes,'Visible','on');
set(handles.DataAxesX_Slider,'Visible','on');
set(handles.DataAxesY_Slider,'Visible','on');

% Setup X Axis Slider
SliderMax   = PlotSettings.XMax - PlotSettings.XWidth;
SliderSteps = PlotSettings.XWidth./SliderMax;
SliderSteps(2) = SliderSteps.*10;
set(handles.DataAxesX_Slider,'max',SliderMax, 'SliderStep',SliderSteps);

% Setup Y Axis Slider
Y_Slider_Value = get(handles.DataAxesY_Slider,'Value');
PossibleSteps = PlotSettings.numChans - PlotSettings.ChanHeight;

if Y_Slider_Value > PossibleSteps
    set(handles.DataAxesY_Slider,'Value',PossibleSteps);
end   

if PossibleSteps == 0
    set(handles.DataAxesY_Slider, 'Min',0','Max',1, 'SliderStep',[0 1],'Enable','off','Value',1);
else
    set(handles.DataAxesY_Slider, 'Min', 0, 'Max', PossibleSteps, 'SliderStep', [(1/PossibleSteps) PossibleSteps],...
        'Value',PossibleSteps, 'Enable','on');
end

drawDataPlot(handles);


set(handles.RecInfo_Channel_Text,'String',num2str(PlotSettings.numChans));
set(handles.RecInfo_Length_Text,'String',num2str(PlotSettings.XMax));

if isempty(eventData)
    set(handles.RecInfo_Event_Text,'String','NA');
else
    set(handles.RecInfo_Event_Text,'String',[num2str(length(eventData.event)) ' events of ' ...
        num2str(length(unique([eventData.event.type]))) ' types']);
    drawTimelinePlot(handles)
end

% Setup Channel Map Plots

% Electrode = getappdata(handles.figure1,'Electrode');
% LoadedChannels = getappdata(handles.figure1,'LoadedChannels');
% 
% 
% 
% if ~isempty(Electrode)
% % Use the Electrode information to draw this channel plot...
% 
% ElectrodeCheckerbox(handles,Electrode)
% 
% % cables = unique(Electrode.Cable(LoadedChannels));
% % 
% % for cable = 1:length(cables)
% %     switch cables(cable)
% %         case 1
% %             current_channels = find(Electrode.Cable(LoadedChannels) == 1);
% %             electrode_checkerbox = generate_electrode_checkerbox(current_channels, handles);
% %             pcolor(handles.ChannelSelection_Axes1, 1:17, 1:5, electrode_checkerbox);
% %             set(handles.ChannelSelection_Axes1,'CLim',[0 10],'YDir','reverse','YTickLabel',[],'XTickLabel',[])
% %             colormap(handles.ChannelSelection_Axes1,generate_electrode_colormap)
% %             text(handles.ChannelSelection_Axes1,1.25,1.5,'1')
% %         case 2
% %             
% %         case 3
% %             
% %         case 4
% %     end
% % end
%             
% 
% 
% 
% %     
% %     
% % else
% %     % Just guess? Or plot some defaults
% %     
% end

function ElectrodeCheckerbox(handles,Electrode)

cables = unique(Electrode.Cable);

for cable = 1:length(cables)
    
    switch cables(cable)
        case 1
            axes(handles.ChannelSelection_Axes1);
            current_channels = find(Electrode.Cable==cables(cable));
            if length(current_channels) > 32
                electrode_checkerbox = 5.*ones(4,16)';
            else
               electrode_checkerbox = 5.*ones(2,16)';
            end
            
            imagesc(gca,electrode_checkerbox)
            colormap(gca,generate_electrode_colormap)
            set(gca,'CLim',[2 10])
            for chan = 1:length(current_channels)
                [i,j] = ind2sub(size(electrode_checkerbox),current_channels(chan));
                chan_str = pad(num2str(current_channels(chan)),3,'both');              
                text(gca,j,i-0.33,chan_str,'FontSize',8);
            end
            view(gca,[90 90])
            for j = 1:3
                line([j+.5 j+.5], [-1 17],'color','w','LineWidth',1.25)
            end
   
            for j = 1:15
                line([0 5], [j+.5 j+.5],'color','w','LineWidth',1.25)
            end
            
            set(gca,'YDir','normal','YTick',[],'XTick',[])
            
            
            
        case 2
            axes(handles.ChannelSelection_Axes2);
            current_channels = find(Electrode.Cable==cables(cable));
            if length(current_channels) > 32
                electrode_checkerbox = 5.*ones(4,16)';
            else
               electrode_checkerbox = 5.*ones(2,16)';
            end
            
            imagesc(gca,electrode_checkerbox)
            colormap(gca,generate_electrode_colormap)
            set(gca,'CLim',[2 10])
            for chan = 1:length(current_channels)
                [i,j] = ind2sub(size(electrode_checkerbox),current_channels(chan));
                chan_str = pad(num2str(current_channels(chan)),3,'both');              
                text(gca,j,i-0.33,chan_str,'FontSize',8);
            end
            view(gca,[90 90])
            
            for j = 1:3
                line([j+.5 j+.5], [-1 17],'color','w','LineWidth',1.25)
            end
   
            for j = 1:15
                line([0 5], [j+.5 j+.5],'color','w','LineWidth',1.25)
            end  
            set(gca,'YDir','normal','YTick',[],'XTick',[])
        
        case 3
            current_channels = find(Electrode.Cable==cables(cable));
            if length(current_channels) > 32
                electrode_checkerbox = 5.*ones(4,16)';
            else
               electrode_checkerbox = 5.*ones(2,16)';
            end
            
            imagesc(handles.ChannelSelection_Axes3,electrode_checkerbox)
            
        case 4
            current_channels = find(Electrode.Cable==cables(cable));
            if length(current_channels) > 32
                electrode_checkerbox = 5.*ones(4,16)';
            else
               electrode_checkerbox = 5.*ones(2,16)';
            end
            
            imagesc(handles.ChannelSelection_Axes4,electrode_checkerbox)
            
    end
end


function electrode_checkerbox = generate_electrode_checkerbox(current_channels, handles)

electrode_checkerbox = ones(4,16)';
electrode_checkerbox(current_channels) = 5; 
figure, imagesc(electrode_checkerbox)
colormap(electrode_colormap)
set(gca,'CLim',[2 10])
for chan = 1:length(current_channels)
    [i,j] = ind2sub(size(electrode_checkerbox),current_channels(chan));
    text(j,i,num2str(current_channels(chan)),'FontSize',8);
end
view([90 90])
set(gca,'YDir','normal')

for j = 1:3
    line([j+.5 j+.5], [-1 17],'color','w')
end
   
for j = 1:15
    line([0 5], [j+.5 j+.5],'color','w')
end
        

function electrode_colormap = generate_electrode_colormap

electrode_colormap = ...
[0 0 0 ; ...  %black
64 64 64; ... % Dark Grey
128 128 128; ... % medium Grey
192 192 192; ... % Light Grey
255 255 255; ... % white
0 0 255; ... % blue
0 255 0; ... % Green
255 255 0; ... % Yellow
255 0 0]./255;         %red
            
            
            
            
            
            
            
            

function Stats = CalculateStats(amplifierMap)

pc = 5/100; % Remove 5% of the most extreme data
data = single(amplifierMap.Data.data(1,:) * 0.195); % just compute on 1 channel
zlow = quantile(data,(pc / 2));   % low  quantile
zhi  = quantile(data,1 - pc / 2); % high quantile
tndx = find((data >= zlow & data <= zhi & ~isnan(data)));
tM=mean(data(tndx)); % mean with excluded pc/2*100% of highest and lowest values
tSD=std(data(tndx)); % trimmed SD


Stats.tM  = tM;
Stats.tSD = tSD;
Stats.M   = mean(data);
Stats.SD  = std(data);




function drawTimelinePlot(handles)


EEG = getappdata(handles.figure1,'EEG');
PlotSettings = getappdata(handles.figure1,'PlotSettings');

UniqueEvents = unique([eventData.event.type]);
if length(UniqueEvents)< 3; UniqueEvents = [UniqueEvents 998 999]; end
cmap = cbrewer('div','Spectral',length(UniqueEvents));

cla(handles.Timeline_Axes)
set(handles.Timeline_Axes,'visible','on')
hold(handles.Timeline_Axes,'on')

axes(handles.Timeline_Axes)

for j = 1:length(eventData.event)
    
    line(gca, [(eventData.event(j).latency)./EEG.srate (eventData.event(j).latency)./EEG.srate],...
        [0 1],'Color',cmap(UniqueEvents==eventData.event(j).type,:),'LineWidth',0.5,'HitTest','off')
    
end

hold(handles.Timeline_Axes,'off')

set(handles.Timeline_Axes,'XLim',[0 PlotSettings.XMax],'YTick',[]);



drawTimelineMarker(handles)

function drawTimelineMarker(handles)
% tic
% Xlims = get(handles.Timeline_Axes,'XLim');
% 
% PlotSettings = getappdata(handles.figure1,'PlotSettings');
% cla(handles.Timeline_Marker_Axes);
% set(handles.Timeline_Marker_Axes,'XLim',Xlims);
% 
% rectangle(handles.Timeline_Marker_Axes, 'Position', [PlotSettings.XPosition 0 PlotSettings.XWidth 1], 'FaceColor',[0 .5 .5 .5], 'EdgeColor','b')   %'FaceColor', [0 .5 .5]) %[0.34,0.46,1 0.5])
% toc

    

function drawDataPlot(handles)

PlotSettings = getappdata(handles.figure1,'PlotSettings');
recInfo      = getappdata(handles.figure1,'recInfo');
amplifierMap = getappdata(handles.figure1,'amplifierMap');
timestamps   = getappdata(handles.figure1,'timestamps');
% Electrode    = getappdata(handles.figure1,'Electrode');

% Need to redo this to actually calculate it from the Chanel Selections
PlotChannelIdx = PlotSettings.ChanPosition:PlotSettings.ChanHeight;

% Need to calculate how many lines to plot & how to scale them

XAxesStart = round(PlotSettings.XPosition.*recInfo.sRate+1);
XAxesSpread = round(XAxesStart + (PlotSettings.XWidth.*recInfo.sRate));

YSpread  = 2*PlotSettings.ScaleFactor*PlotSettings.Stats.tSD; % Calculates the YSpread for each plot as 2 * the ScaleFactor
YPadding = YSpread./4; % Units to pad the top and bottom of the display by
YAxis.Centres(1) = PlotSettings.Stats.tM; % Log the centre point for the first plot

%% Generate Data needed

data = double(amplifierMap.Data.data(PlotChannelIdx,XAxesStart:XAxesSpread));

if get(handles.RereferenceData,'Value') % Check whether to rereference the plot
    data = rereferenceData(data, handles);
end
   
if get(handles.applyFilter,'Value') % Check whether to filter the data
    data = filterData(data,handles);
end
    
%% begin plotting
tic
cla(handles.DataAxes)

plot(handles.DataAxes,timestamps(XAxesStart:XAxesSpread),data(1,:));
hold(handles.DataAxes,'on')

for chan = 2:length(PlotChannelIdx)

    plot(handles.DataAxes,timestamps(XAxesStart:XAxesSpread),(data(chan,:) - (YSpread * (chan - 1) + 0.1)));
    YAxis.Centres(chan) = PlotSettings.Stats.tM - (YSpread * (chan - 1) + 0.1);
end

set(handles.DataAxes,'XLim',[PlotSettings.XPosition PlotSettings.XPosition+PlotSettings.XWidth],...
    'XAxisLocation','top');
hold(handles.DataAxes,'off')

%% Plot Events
if get(handles.PlotEvents_Checkbox,'Value')
    
  
    latencies = [eventData.event.latency]./recInfo.sRate;
    CurrentEvents = find(latencies >= timestamps(XAxesStart) &  latencies <= timestamps(XAxesSpread));
    UniqueEvents = unique([eventData.event.type]);
    cmap = cbrewer('div','Spectral',length(UniqueEvents));
    
    YLims = get(handles.DataAxes,'YLim');
    
    for j = 1:length(CurrentEvents)
        
        XPoint = (eventData.event(CurrentEvents(j)).latency./recInfo.sRate);        
        line(handles.DataAxes,[XPoint XPoint],YLims, 'Color',cmap(UniqueEvents==eventData.event(CurrentEvents(j)).type,:),...
            'LineStyle','--','LineWidth',1.5);
    end
       
    
end

%% Plot Spikes
if get(handles.ShowSpikes,'Value')
    spikes = getappdata(handles.figure1,'spikes');
    hold(handles.DataAxes,'on')
    for chan = 1:length(spikes)
        visible = find(spikes(chan).times>timestamps(XAxesStart) & spikes(chan).times<timestamps(XAxesSpread));
        for spike = 1:length(visible)
            scatter(handles.DataAxes, spikes(chan).times(visible(spike)), YAxis.Centres(chan)-YSpread*.15,'r*')
        end
    end
    hold(handles.DataAxes,'off')
end


%% Update Settings Data
YAxis.YSpread = YSpread;
YAxis.YPadding = YPadding;
PlotSettings.YAxis = YAxis;
setappdata(handles.figure1,'PlotSettings',PlotSettings);


%% Update sliders

DataAxesY_Slider_Callback(handles.DataAxesY_Slider, [], handles)

% set(handles.DataAxes,'YLim',[(PlotSettings.Stats.tM - PlotSettings.ScaleFactor*PlotSettings.Stats.tSD) - ((PlotSettings.ChanHeight-1)*YSpread) - YPadding ...
%     (PlotSettings.Stats.tM + PlotSettings.ScaleFactor*PlotSettings.Stats.tSD) + YPadding ]);
% Set a Y-Axes Limit based on 
set(handles.DataAxes,'YTick',fliplr(YAxis.Centres),'YTickLabels',fliplr(PlotSettings.Channels));
hold(handles.DataAxes,'off')


toc



function DownSampleFactor_Box_Callback(hObject, eventdata, handles)
% hObject    handle to DownSampleFactor_Box (see GCBO) 
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of DownSampleFactor_Box as text
%        str2double(get(hObject,'String')) returns contents of DownSampleFactor_Box as a double


% --- Executes during object creation, after setting all properties.
function DownSampleFactor_Box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to DownSampleFactor_Box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Channels_Box_Callback(hObject, eventdata, handles)
% hObject    handle to Channels_Box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Channels_Box as text
%        str2double(get(hObject,'String')) returns contents of Channels_Box as a double


% --- Executes during object creation, after setting all properties.
function Channels_Box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Channels_Box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ADCChannels_Box_Callback(hObject, eventdata, handles)
% hObject    handle to ADCChannels_Box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ADCChannels_Box as text
%        str2double(get(hObject,'String')) returns contents of ADCChannels_Box as a double


% --- Executes during object creation, after setting all properties.
function ADCChannels_Box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ADCChannels_Box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ProcessSpikes_Checkbox.
function ProcessSpikes_Checkbox_Callback(hObject, eventdata, handles)
% hObject    handle to ProcessSpikes_Checkbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ProcessSpikes_Checkbox


% --- Executes on button press in FileDirectory_Button.
function FileDirectory_Button_Callback(hObject, eventdata, handles)
% hObject    handle to FileDirectory_Button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

directoryName= uigetdir(pwd, 'Pick a Directory Containing OpenEphys Files');

if directoryName
    cd(directoryName)
    Check_Directory(handles)
    set(handles.FileDirectory_Box,'String',directoryName)
else
    cd(pwd)
    Check_Directory(handles)
    set(handles.FileDirectory_Box,'String',pwd)
end
    


function FileDirectory_Box_Callback(hObject, eventdata, handles)
% hObject    handle to FileDirectory_Box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of FileDirectory_Box as text
%        str2double(get(hObject,'String')) returns contents of FileDirectory_Box as a double

try 
    cd(get(hObject,'String'))
    Check_Directory(handles)
catch
    set(handles.Status_Text,'String','Not a Valid Directory...')
end
    

% --- Executes during object creation, after setting all properties.
function FileDirectory_Box_CreateFcn(hObject, eventdata, handles)
% hObject    handle to FileDirectory_Box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function DataAxesX_Slider_Callback(hObject, eventdata, handles)
% hObject    handle to DataAxesX_Slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

PlotSettings = getappdata(handles.figure1,'PlotSettings');
PlotSettings.XPosition = get(hObject,'Value');
set(handles.TimeStart_Value,'String',num2str(get(hObject,'Value')));
setappdata(handles.figure1,'PlotSettings',PlotSettings);
TimeStart_Value_Callback(handles.TimeStart_Value, [], handles);

% --- Executes during object creation, after setting all properties.
function DataAxesX_Slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to DataAxesX_Slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function DataAxesY_Slider_Callback(hObject, eventdata, handles)
% hObject    handle to DataAxesY_Slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

% 
% PlotSettings = getappdata(handles.figure1,'PlotSettings');
% YValue = round(get(handles.DataAxesY_Slider,'Value'));
% YMax   = get(handles.DataAxesY_Slider,'Max');
% YMin   = get(handles.DataAxesY_Slider,'Min');
% 
% YLim = [PlotSettings.YAxis.Centres(YMax - YValue + PlotSettings.ChanHeight) - PlotSettings.YAxis.YSpread./2 ...
%     PlotSettings.YAxis.Centres(YMax - YValue + 1) + PlotSettings.YAxis.YSpread./2];
% 
% set(handles.DataAxes,'YLim',YLim);



% --- Executes during object creation, after setting all properties.
function DataAxesY_Slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to DataAxesY_Slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end




function ChannelRange_Value_Callback(hObject, eventdata, handles)
% hObject    handle to ChannelRange_Value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ChannelRange_Value as text
%        str2double(get(hObject,'String')) returns contents of ChannelRange_Value as a double

PlotSettings = getappdata(handles.figure1,'PlotSettings');
NewChanHeight = str2num(get(hObject,'String'));
if NewChanHeight > PlotSettings.numChans
    PlotSettings.ChanHeight = PlotSettings.numChans;
    set(hObject,'String',num2str(PlotSettings.ChanHeight));
else
    PlotSettings.ChanHeight = NewChanHeight;
end
setappdata(handles.figure1,'PlotSettings',PlotSettings);
% drawDataPlot(handles);
Y_Slider_Value = get(handles.DataAxesY_Slider,'Value');
Y_Slider_Min   = get(handles.DataAxesY_Slider,'Min');
Y_Slider_Max   = get(handles.DataAxesY_Slider,'Max');
PossibleSteps = PlotSettings.numChans - PlotSettings.ChanHeight;
Y_Value = PossibleSteps - (Y_Slider_Max - Y_Slider_Value);




% Setup Y Axis Slider
if Y_Value > PossibleSteps
    set(handles.DataAxesY_Slider,'Value',PossibleSteps);
elseif Y_Value < 0
    Y_Value = 0;
end

if PossibleSteps == 0
    set(handles.DataAxesY_Slider, 'SliderStep',[1 1000],'Enable','off','Value',0,'Min',0,'Max',0);
else
    set(handles.DataAxesY_Slider, 'Min', 0, 'Max', PossibleSteps, 'SliderStep', [(1/PossibleSteps) PossibleSteps],...
        'Enable','on','Value',Y_Value);
end

% if Y_Slider_Value == 0
%     set(handles.DataAxesY_Slider,'Value',get(handles.DataAxesY_Slider,'Max'));
% end

DataAxesY_Slider_Callback(handles.DataAxesY_Slider,[], handles);


% --- Executes during object creation, after setting all properties.
function ChannelRange_Value_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ChannelRange_Value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function TimeStart_Value_Callback(hObject, eventdata, handles)
% hObject    handle to TimeStart_Value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of TimeStart_Value as text
%        str2double(get(hObject,'String')) returns contents of TimeStart_Value as a double

PlotSettings = getappdata(handles.figure1,'PlotSettings');
newXPosition = get(hObject,'String');

try 
    newXPosition = str2num(newXPosition);
catch
    set(handles.Status_Text,'String','Value not valid')
    set(hObject,'String',PlotSettings.XPosition);
end

if newXPosition + PlotSettings.XWidth <= PlotSettings.XMax
    PlotSettings.XPosition = newXPosition;
    setappdata(handles.figure1,'PlotSettings',PlotSettings);
elseif newXPosition < PlotSettings.XMax
    PlotSettings.XPosition = newXPosition;
    PlotSettings.XWidth = PlotSettings.XMax - PlotSettings.XPosition;
    set(hObject,'String',PlotSettings.XPosition);
    set(handles.TimeRange_Value,'String',PlotSettings.XWidth);
else
    set(handles.Status_Text,'String','Value not valid')
    set(hObject,'String',PlotSettings.XPosition);
end

% Update Slider Steps
SliderMax   = PlotSettings.XMax - PlotSettings.XWidth;
SliderSteps = PlotSettings.XWidth./SliderMax;
SliderSteps(2) = SliderSteps.*10;


set(handles.DataAxesX_Slider,'max',SliderMax, 'SliderStep',SliderSteps,'Value',PlotSettings.XPosition);
setappdata(handles.figure1,'PlotSettings',PlotSettings)
drawDataPlot(handles)
drawTimelineMarker(handles)





% --- Executes during object creation, after setting all properties.
function TimeStart_Value_CreateFcn(hObject, eventdata, handles)
% hObject    handle to TimeStart_Value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function TimeRange_Value_Callback(hObject, eventdata, handles)
% hObject    handle to TimeRange_Value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of TimeRange_Value as text
%        str2double(get(hObject,'String')) returns contents of TimeRange_Value as a double

PlotSettings = getappdata(handles.figure1,'PlotSettings');
newXWidth = get(hObject,'String');
if newXWidth == 0
    newXWidth = 1;
end

try 
    newXWidth = str2num(newXWidth);
catch
    set(handles.Status_Text,'String','Value not valid')
    set(hObject,'String',PlotSettings.XWidth);
end

if newXWidth <= PlotSettings.XMax
    PlotSettings.XWidth = newXWidth;
    if PlotSettings.XPosition + newXWidth > PlotSettings.XMax
        PlotSettings.XPosition = PlotSettings.XMax - newXWidth;
        set(handles.TimeStart_Value,'String',num2str(PlotSettings.XPosition));
    end
    setappdata(handles.figure1,'PlotSettings',PlotSettings);
else
    set(handles.Status_Text,'String','Value not valid')
    set(hObject,'String',PlotSettings.XWidth);
end

% Update Slider Steps
SliderMax   = PlotSettings.XMax - PlotSettings.XWidth;
SliderSteps = PlotSettings.XWidth./SliderMax;
SliderSteps(2) = SliderSteps.*10;

set(handles.DataAxesX_Slider,'max',SliderMax, 'SliderStep',SliderSteps);


drawDataPlot(handles)
drawTimelineMarker(handles)


% --- Executes during object creation, after setting all properties.
function TimeRange_Value_CreateFcn(hObject, eventdata, handles)
% hObject    handle to TimeRange_Value (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on mouse press over axes background.
function Timeline_Axes_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to Timeline_Axes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


xy = get(handles.Timeline_Axes,'Currentpoint');
if xy(1,1) > 0
    set(handles.TimeStart_Value,'String',num2str(xy(1,1)));
    TimeStart_Value_Callback(handles.TimeStart_Value, [], handles);
end


% --- Executes on button press in PlotEvents_Checkbox.
function PlotEvents_Checkbox_Callback(hObject, eventdata, handles)
% hObject    handle to PlotEvents_Checkbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of PlotEvents_Checkbox

PlotSettings = getappdata(handles.figure1,'PlotSettings');
drawDataPlot(handles)




function YScale_Callback(hObject, eventdata, handles)
% hObject    handle to YScale (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of YScale as text
%        str2double(get(hObject,'String')) returns contents of YScale as a double

PlotSettings = getappdata(handles.figure1,'PlotSettings');
PlotSettings.ScaleFactor = str2num(get(handles.YScale,'String'));
setappdata(handles.figure1,'PlotSettings',PlotSettings);
drawDataPlot(handles)


% --- Executes during object creation, after setting all properties.
function YScale_CreateFcn(hObject, eventdata, handles)
% hObject    handle to YScale (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in RereferenceData.
function RereferenceData_Callback(hObject, eventdata, handles)
% hObject    handle to RereferenceData (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of RereferenceData
drawDataPlot(handles)

% --- Executes on selection change in ReferenceSelect.
function ReferenceSelect_Callback(hObject, eventdata, handles)
% hObject    handle to ReferenceSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ReferenceSelect contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ReferenceSelect
drawDataPlot(handles)

% --- Executes during object creation, after setting all properties.
function ReferenceSelect_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ReferenceSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in HighPassFilter.
function HighPassFilter_Callback(hObject, eventdata, handles)
% hObject    handle to HighPassFilter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~getappdata(handles.figure1,'Filtered')
    
    set(handles.HighPassFilter,'String','Filtering...')
    drawnow
    
    EEG = getappdata(handles.figure1,'EEG');
    EEG = pop_eegfilt(EEG, 300, 0,0,0,0,0,'fir1',0);
    EEG = pop_eegfilt(EEG, 0, 6000,0,0,0,0,'fir1',0);
    setappdata(handles.figure1,'EEG',EEG);
    
    setappdata(handles.figure1,'Filtered',1);
    set(handles.HighPassFilter,'String','High Pass Filter Data','enable','off')
    set(handles.SpikeDetect,'enable','on')
    drawDataPlot(handles)
else
    warning('Already Filtered')
    set(handles.SpikeDetect,'enable','on')
end



    


% --- Executes on button press in SpikeDetect.
function SpikeDetect_Callback(hObject, eventdata, handles)
% hObject    handle to SpikeDetect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if getappdata(handles.figure1,'Filtered')
    
    set(handles.SpikeDetect,'String','Running')
    drawnow
    EEG = getappdata(handles.figure1,'EEG');   
    
    if get(handles.RereferenceData,'Value')
        EEG.data = rereferenceData(EEG.data, handles);
    end
    
    for chan = 1:EEG.nbchan
        spikes(chan) = spike_detect(EEG.data(chan,:), timestamps, EEG.srate, 1);
    end
    setappdata(handles.figure1,'spikes',spikes);
    set(handles.SpikeDetect,'String','Run Spike Detection')
else
    warning('Data needs to be filtered first')
end


% --- Executes on button press in ShowSpikes.
function ShowSpikes_Callback(hObject, eventdata, handles)
% hObject    handle to ShowSpikes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ShowSpikes

spikes = getappdata(handles.figure1,'spikes');
if ~isempty(spikes)
    drawDataPlot(handles)
end
    
function data = rereferenceData(data, handles)

PlotSettings = getappdata(handles.figure1,'PlotSettings');

switch get(handles.ReferenceSelect,'Value')
    case 1 % Use electrode mean
        data = bsxfun(@minus, data, median(data,1));
    case 2 % Use shank mean
%         for j = 1:length(cables)
%             currentChannels = channels(Electrode.Cable(channels) == cables(j));
%             shanks = unique(Electrode.Shank(currentChannels));
%             for k = 1:length(shanks)
%                 reference = mean(data(Electrode.Cable(channels)== cables(j) & Electrode.Shank(channels) == shanks(k),:),1);
%                 data(Electrode.Cable(channels)== cables(j) & Electrode.Shank(channels) == shanks(k),:) = ...
%                     bsxfun(@minus, data(Electrode.Cable(channels)== cables(j) & Electrode.Shank(channels) == shanks(k),:), ...
%                     reference);
%             end
%         end 
    case 3 % Use Nearest Neighbours
%         refData = data;
%         for j = 1:length(channels)     
% 
%             refChans = intersect(find(Electrode.Cable==Electrode.Cable(channels(j))), channels); % channels on same electrode that are loaded
%             refChans = refChans(refChans~=channels(j));                      % Remove the actual channel
%             neighbours = knnsearch([Electrode.X(refChans)' Electrode.Y(refChans)'], ...
%             [Electrode.X(channels(j)) Electrode.Y(channels(j))],'k',3); % find the 3 closest neighbours (i.e. tetrode...)
%             reference = mean(data(dataChannels(refChans(neighbours)),:),1);
%             refData(j,:) = bsxfun(@minus, data(j,:),reference);
% 
%         end
%         data = refData; clear refData;
end

function data = filterData(data,handles)

loFreq = str2num(get(handles.lowFreqBox,'String'));
hiFreq = str2num(get(handles.hiFreqBox,'String'));
recInfo = getappdata(handles.figure1,'recInfo');
data = eegfilt(data, recInfo.sRate,loFreq, hiFreq);

   

% --- Executes on selection change in remapElectrodeType.
function remapElectrodeType_Callback(hObject, eventdata, handles)
% hObject    handle to remapElectrodeType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns remapElectrodeType contents as cell array
%        contents{get(hObject,'Value')} returns selected item from remapElectrodeType


% --- Executes during object creation, after setting all properties.
function remapElectrodeType_CreateFcn(hObject, eventdata, handles)
% hObject    handle to remapElectrodeType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in remapChannels.
function remapChannels_Callback(hObject, eventdata, handles)
% hObject    handle to remapChannels (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if get(handles.remapElectrodeType,'Value') ~= 0
    electrodeStrings = get(handles.remapElectrodeType,'String');
    electrodeType = electrodeStrings{get(handles.remapElectrodeType,'Value')};
    electrode = electrode_geometry(electrodeType);
end

EEG = getappdata(handles.figure1,'EEG');
EEG.data = EEG.data(electrode.Remap,:,:);
setappdata(handles.figure1,'EEG',EEG);
drawDataPlot(handles)

function completePath = filepath(fileStruct)

completePath = [fileStruct.folder filesep fileStruct.name];



function lowFreqBox_Callback(hObject, eventdata, handles)
% hObject    handle to lowFreqBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of lowFreqBox as text
%        str2double(get(hObject,'String')) returns contents of lowFreqBox as a double


% --- Executes during object creation, after setting all properties.
function lowFreqBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lowFreqBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in applyFilter.
function applyFilter_Callback(hObject, eventdata, handles)
% hObject    handle to applyFilter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of applyFilter



function hiFreqBox_Callback(hObject, eventdata, handles)
% hObject    handle to hiFreqBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of hiFreqBox as text
%        str2double(get(hObject,'String')) returns contents of hiFreqBox as a double


% --- Executes during object creation, after setting all properties.
function hiFreqBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to hiFreqBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in notchCheck.
function notchCheck_Callback(hObject, eventdata, handles)
% hObject    handle to notchCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of notchCheck



function sampleRateBox_Callback(hObject, eventdata, handles)
% hObject    handle to sampleRateBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of sampleRateBox as text
%        str2double(get(hObject,'String')) returns contents of sampleRateBox as a double


% --- Executes during object creation, after setting all properties.
function sampleRateBox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sampleRateBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in applyResampling.
function applyResampling_Callback(hObject, eventdata, handles)
% hObject    handle to applyResampling (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of applyResampling


% --- Executes on button press in baselineCheck.
function baselineCheck_Callback(hObject, eventdata, handles)
% hObject    handle to baselineCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of baselineCheck


