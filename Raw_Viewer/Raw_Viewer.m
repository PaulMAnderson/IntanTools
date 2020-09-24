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

           
if getappdata(handles.figure1,'mfile')
    try
        mfiles = dir('*.mat');
        load(mfiles.name,'trial')
        setappdata(handles.figure1,'trial',trial)
        if isfield(trial,'Electrode')
            setappdata(handles.figure1,'Electrode',trial.Electrode)
        end
    end
end
setappdata(handles.figure1,'Filtered',0);
SetupAxes(handles)



function SetupAxes(handles)

EEG = getappdata(handles.figure1,'EEG');
% DroppedSamplesCheck(EEG)
XMax = EEG.xmax;
NChans = EEG.nbchan;

PlotSettings.Stats    = CalculateStats(EEG);
PlotSettings.Channels = {EEG.chanlocs.labels};
PlotSettings.ScaleFactor = str2num(get(handles.YScale,'String'));


if XMax > 20
    XWidth = 10;
elseif XMax > 10
    XWidth = 5;
else
    XWidth = XMax;
end

if NChans >= 64
    ChanHeight = 32;
elseif NChans >= 32
    ChanHeight = 16;
elseif NChans >= 16
    ChanHeight = 8;
else
    ChanHeight = NChans;
end

PlotSettings.XPosition    = 0; 
PlotSettings.XMax         = XMax;
PlotSettings.XWidth       = XWidth;
PlotSettings.ChanPosition = 1;
PlotSettings.NChans       = NChans;
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
PossibleSteps = PlotSettings.NChans - PlotSettings.ChanHeight;

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
set(handles.RecInfo_Channel_Text,'String',num2str(PlotSettings.NChans));
set(handles.RecInfo_Length_Text,'String',num2str(PlotSettings.XMax));

if isempty(EEG.event)
    set(handles.RecInfo_Event_Text,'String','NA');
else
    set(handles.RecInfo_Event_Text,'String',[num2str(length(EEG.event)) ' events of ' ...
        num2str(length(unique([EEG.event.type]))) ' types']);
    drawTimelinePlot(handles)
end

% Setup Channel Map Plots

Electrode = getappdata(handles.figure1,'Electrode');
LoadedChannels = getappdata(handles.figure1,'LoadedChannels');



if ~isempty(Electrode)
% Use the Electrode information to draw this channel plot...

ElectrodeCheckerbox(handles,Electrode)

% cables = unique(Electrode.Cable(LoadedChannels));
% 
% for cable = 1:length(cables)
%     switch cables(cable)
%         case 1
%             current_channels = find(Electrode.Cable(LoadedChannels) == 1);
%             electrode_checkerbox = generate_electrode_checkerbox(current_channels, handles);
%             pcolor(handles.ChannelSelection_Axes1, 1:17, 1:5, electrode_checkerbox);
%             set(handles.ChannelSelection_Axes1,'CLim',[0 10],'YDir','reverse','YTickLabel',[],'XTickLabel',[])
%             colormap(handles.ChannelSelection_Axes1,generate_electrode_colormap)
%             text(handles.ChannelSelection_Axes1,1.25,1.5,'1')
%         case 2
%             
%         case 3
%             
%         case 4
%     end
% end
            



%     
%     
% else
%     % Just guess? Or plot some defaults
%     
end

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
            
            
            
            
            
            
            
            

function Stats = CalculateStats(EEG)

pc = 5/100; % Remove 5% of the most extreme data
data = EEG.data(1,:); % just compute on 1 channel
zlow = quantile(data,(pc / 2));   % low  quantile
zhi  = quantile(data,1 - pc / 2); % high quantile
tndx = find((data >= zlow & data <= zhi & ~isnan(data)));
tM=mean(data(tndx)); % mean with excluded pc/2*100% of highest and lowest values
tSD=std(data(tndx)); % trimmed SD


Stats.tM  = tM;
Stats.tSD = tSD;
Stats.M   = mean(data);
Stats.SD  = std(data);



function DroppedSamplesCheck(EEG)

getappdata(handles.figure1,'PlotSettings');

trueSampleInterval = 1./EEG.srate;
SampleIntervals = diff(EEG.times);
DroppedSamples = find(SampleIntervals>2*trueSampleInterval);

if isempty(droppedSamples)
  
end


function drawTimelinePlot(handles)


EEG = getappdata(handles.figure1,'EEG');
PlotSettings = getappdata(handles.figure1,'PlotSettings');

UniqueEvents = unique([EEG.event.type]);
if length(UniqueEvents)< 3; UniqueEvents = [UniqueEvents 998 999]; end
cmap = cbrewer('div','Spectral',length(UniqueEvents));

cla(handles.Timeline_Axes)
set(handles.Timeline_Axes,'visible','on')
hold(handles.Timeline_Axes,'on')

axes(handles.Timeline_Axes)

for j = 1:length(EEG.event)
    
    line(gca, [(EEG.event(j).latency)./EEG.srate (EEG.event(j).latency)./EEG.srate],...
        [0 1],'Color',cmap(UniqueEvents==EEG.event(j).type,:),'LineWidth',0.5,'HitTest','off')
    
end

hold(handles.Timeline_Axes,'off')

set(handles.Timeline_Axes,'XLim',[0 PlotSettings.XMax],'YTick',[]);



drawTimelineMarker(handles)

function drawTimelineMarker(handles)

Xlims = get(handles.Timeline_Axes,'XLim');


PlotSettings = getappdata(handles.figure1,'PlotSettings');
cla(handles.Timeline_Marker_Axes);
set(handles.Timeline_Marker_Axes,'XLim',Xlims);

rectangle(handles.Timeline_Marker_Axes, 'Position', [PlotSettings.XPosition 0 PlotSettings.XWidth 1], 'FaceColor',[0 .5 .5 .5], 'EdgeColor','b')...   %'FaceColor', [0 .5 .5]) %[0.34,0.46,1 0.5])


    

function drawDataPlot(handles)

PlotSettings = getappdata(handles.figure1,'PlotSettings');
EEG          = getappdata(handles.figure1,'EEG');
Electrode    = getappdata(handles.figure1,'Electrode');

% Need to redo this to actually calculate it from the Chanel Selections
PlotChannelIdx = 1:size(EEG.data,1);

% Need to calculate how many lines to plot & how to scale them

XAxesStart = round(PlotSettings.XPosition.*EEG.srate+1);
XAxesSpread = round(XAxesStart + (PlotSettings.XWidth.*EEG.srate));

YSpread  = 2*PlotSettings.ScaleFactor*PlotSettings.Stats.tSD; % Calculates the YSpread for each plot as 2 * the ScaleFactor
YPadding = YSpread./4; % Units to pad the top and bottom of the display by
YAxis.Centres(1) = PlotSettings.Stats.tM; % Log the centre point for the first plot

%% Generate Data needed

data = EEG.data(PlotChannelIdx,XAxesStart:XAxesSpread);



if get(handles.RereferenceData,'Value') % Check whether to rereference the plot
    data = rereferenceData(data, handles);
end
   
    
%% begin plotting
cla(handles.DataAxes)

plot(handles.DataAxes,EEG.times(XAxesStart:XAxesSpread),data(1,:));
hold(handles.DataAxes,'on')

for chan = 2:length(PlotChannelIdx)

    plot(handles.DataAxes,EEG.times(XAxesStart:XAxesSpread),(data(chan,:) - (YSpread * (chan - 1) + 0.1)));
    YAxis.Centres(chan) = PlotSettings.Stats.tM - (YSpread * (chan - 1) + 0.1);
end

set(handles.DataAxes,'XLim',[PlotSettings.XPosition PlotSettings.XPosition+PlotSettings.XWidth],...
    'XAxisLocation','top');
hold(handles.DataAxes,'off')

%% Plot Events
if get(handles.PlotEvents_Checkbox,'Value')
    
  
    latencies = [EEG.event.latency]./EEG.srate;
    CurrentEvents = find(latencies >= EEG.times(XAxesStart) &  latencies <= EEG.times(XAxesSpread));
    UniqueEvents = unique([EEG.event.type]);
    cmap = cbrewer('div','Spectral',length(UniqueEvents));
    
    YLims = get(handles.DataAxes,'YLim');
    
    for j = 1:length(CurrentEvents)
        
        XPoint = (EEG.event(CurrentEvents(j)).latency./EEG.srate);        
        line(handles.DataAxes,[XPoint XPoint],YLims, 'Color',cmap(UniqueEvents==EEG.event(CurrentEvents(j)).type,:),...
            'LineStyle','--','LineWidth',1.5);
    end
       
    
end

%% Plot Spikes
if get(handles.ShowSpikes,'Value')
    spikes = getappdata(handles.figure1,'spikes');
    hold(handles.DataAxes,'on')
    for chan = 1:length(spikes)
        visible = find(spikes(chan).times>EEG.times(XAxesStart) & spikes(chan).times<EEG.times(XAxesSpread));
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


PlotSettings = getappdata(handles.figure1,'PlotSettings');
YValue = round(get(handles.DataAxesY_Slider,'Value'));
YMax   = get(handles.DataAxesY_Slider,'Max');
YMin   = get(handles.DataAxesY_Slider,'Min');

YLim = [PlotSettings.YAxis.Centres(YMax - YValue + PlotSettings.ChanHeight) - PlotSettings.YAxis.YSpread./2 ...
    PlotSettings.YAxis.Centres(YMax - YValue + 1) + PlotSettings.YAxis.YSpread./2];

set(handles.DataAxes,'YLim',YLim);



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
if NewChanHeight > PlotSettings.NChans
    PlotSettings.ChanHeight = PlotSettings.NChans;
    set(hObject,'String',num2str(PlotSettings.ChanHeight));
else
    PlotSettings.ChanHeight = NewChanHeight;
end
setappdata(handles.figure1,'PlotSettings',PlotSettings);
% drawDataPlot(handles);
Y_Slider_Value = get(handles.DataAxesY_Slider,'Value');
Y_Slider_Min   = get(handles.DataAxesY_Slider,'Min');
Y_Slider_Max   = get(handles.DataAxesY_Slider,'Max');
PossibleSteps = PlotSettings.NChans - PlotSettings.ChanHeight;
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
        spikes(chan) = spike_detect(EEG.data(chan,:), EEG.times, EEG.srate, 1);
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

Electrode    = getappdata(handles.figure1,'Electrode');
PlotSettings = getappdata(handles.figure1,'PlotSettings');
channels   = str2num(char(PlotSettings.Channels))';
dataChannels(channels) = 1:length(channels);
electrodes = Electrode.Cable(channels);
cables     = unique(electrodes);

switch get(handles.ReferenceSelect,'Value')
    case 1 % Use electrode mean
        for j = 1:length(cables)
            reference = mean(data(electrodes==cables(j),:),1);
            data(electrodes==cables(j),:) = bsxfun(@minus, data(electrodes==cables(j),:), reference);
        end
    case 2 % Use shank mean
        for j = 1:length(cables)
            currentChannels = channels(Electrode.Cable(channels) == cables(j));
            shanks = unique(Electrode.Shank(currentChannels));
            for k = 1:length(shanks)
                reference = mean(data(Electrode.Cable(channels)== cables(j) & Electrode.Shank(channels) == shanks(k),:),1);
                data(Electrode.Cable(channels)== cables(j) & Electrode.Shank(channels) == shanks(k),:) = ...
                    bsxfun(@minus, data(Electrode.Cable(channels)== cables(j) & Electrode.Shank(channels) == shanks(k),:), ...
                    reference);
            end
        end 
    case 3 % Use Nearest Neighbours
        refData = data;
        for j = 1:length(channels)     

            refChans = intersect(find(Electrode.Cable==Electrode.Cable(channels(j))), channels); % channels on same electrode that are loaded
            refChans = refChans(refChans~=channels(j));                      % Remove the actual channel
            neighbours = knnsearch([Electrode.X(refChans)' Electrode.Y(refChans)'], ...
            [Electrode.X(channels(j)) Electrode.Y(channels(j))],'k',3); % find the 3 closest neighbours (i.e. tetrode...)
            reference = mean(data(dataChannels(refChans(neighbours)),:),1);
            refData(j,:) = bsxfun(@minus, data(j,:),reference);

        end
        data = refData; clear refData;
end

    
    
function electrode = electrode_geometry(electrodeType)

%% PFC Details
PFC.Region(1:64) = {'PFC'};

PFC.ElectrodeNum = [9  10  8  6  13  14  16  1  7  5  12  11  4  2  15  3  25  26  24  22  29  30  32  17  23  21 ...
    28  27  20  18  31  19  41  42  40  38  45  46  48  33  39  37  44  43  36  34  47  35  57  58  56  54  61  62 ... 
    64  49  55  53  60  59  52  50  63  51];

PFC.Remap = [45	53	46	54	42	56	41	51	47	48	43	44	50	52	55	49	57	38	60	35	58	37	64	33	36	34 ...	
    40	39	63	62	59	61	29	3	30	1	26	8	25	5	31	32	27	28	2	6	7	4	14	20	11	22	9	17	...
    15	24	21	23	18	19	12	10	16	13];

PFC.Shank(1:16)  = 1;
PFC.Shank(17:32) = 2;
PFC.Shank(33:48) = 3;
PFC.Shank(49:64) = 4;

PFC.X = [0  0  0  0  0  0  0  0  0  -16.5  16.5  0  0  -16.5  16.5  0  333  333  333  333  333  333  333  333  333 ...
    316.5  349.5  333  333  316.5  349.5  333  666  666  666  666  666  666  666  666  666  649.5  682.5  666  666 ...
    649.5  682.5  666  999  999  999  999  999  999  999  999  999  982.5  1015.5  999  999  982.5  1015.5  999];
PFC.Y = [0  225  450  900  1125  1575  1800  2025  658.5  675  675  691.5  1333.5  1350  1350  1366.5  0  225  450 ...
    900  1125  1575  1800  2025  658.5  675  675  691.5  1333.5  1350  1350  1366.5  0  225  450  900  1125  1575 ...
    1800  2025  658.5  675  675  691.5  1333.5  1350  1350  1366.5  0  225  450  900  1125  1575  1800  2025  658.5 ...
    675  675  691.5  1333.5  1350  1350  1366.5];

PFC.Connector = [1  2  1  2  1  2  1  2  1  1  1  1  2  2  2  2  2  1  2  1  2  1  2  1  1  1  1  1  2  2  2  2  1  2 ...
    1  2  1  2  1  2  1  1  1  1  2  2  2  2  2  1  2  1  2  1  2  1  1  1  1  1  2  2  2  2];

PFC.X_Label = repmat([0 0 0 0 0 0 0 0 -60 -90 -10 -60 -60 -90 -10 -60], 1,4);
PFC.X_Label = PFC.X_Label + (PFC.X+15);

PFC.Y_Label = repmat([0 0 0 0 0 0 0 0 -45 0 0 +45 -45 0 0 +45], 1,4);
PFC.Y_Label = PFC.Y_Label + PFC.Y;

PFC.SiteType(1:8) = 1; PFC.SiteType(9:16) = 2; PFC.SiteType = repmat(PFC.SiteType, 1, 4);

%% PFC_A Details
PFC_A.Region(1:32) = {'PFC'};
PFC_A.ElectrodeNum = [9  8  13  16  7  5  12  11  26  22  30  17  23  21  28  27  41  40  45  48  39  37  44  43 ...
    58  54  62  49  55  53  60  59];
PFC_A.Remap        = [23	26	28	21	24	25	22	27	30	18	19	17	31	32	29	20	15	2	4	13	16	1	14	3	...
    7	6	9	5	11	12	8	10];

PFC_A.Shank(1:8)  = 1;
PFC_A.Shank(9:16) = 2;
PFC_A.Shank(17:24) = 3;
PFC_A.Shank(25:32) = 4;

PFC_A.X = [0  0  0  0  0  -16.5  16.5  0  333  333  333  333  333  316.5  349.5  333  666  666  666  666  666  649.5 ...
    682.5  666  999  999  999  999  999  982.5  1015.5  999];
PFC_A.Y = [0  450  1125  1800  658.5  675  675  691.5  225  900  1575  2025  658.5  675  675  691.5  0  450  1125 ...
    1800  658.5  675  675  691.5  225  900  1575  2025  658.5  675  675  691.5];

PFC_A.Connector = ones(1,32);

PFC_A.SiteType(1:4) = 1; PFC_A.SiteType(5:8) = 2; PFC_A.SiteType = repmat(PFC_A.SiteType, 1, 4);

%% PFC_B Details
PFC_B.Region(1:32) = {'PFC'};
PFC_B.ElectrodeNum = [10  6  14  1  4  2  15  3  25  24  29  32  20  18  31  19  42  38  46  33  36  34  47  35  57  ...
    56  61  64  52  50  63  51];
PFC_B.Remap        = [27	22	21	26	24	23	28	25	29	19	20	17	32	18	30	31	2	1	13	3	16	14	4	15	...
    10	6	5	8	11	12	9	7];

PFC_B.Shank(1:8)  = 1;
PFC_B.Shank(9:16) = 2;
PFC_B.Shank(17:24) = 3;
PFC_B.Shank(25:32) = 4;

PFC_B.X = [0  0  0  0  0  -16.5  16.5  0  333  333  333  333  333  316.5  349.5  333  666  666  666  666  666  649.5 ...
    682.5  666  999  999  999  999  999  982.5  1015.5  999];
PFC_B.Y = [225  900  1575  2025  1333.5  1350  1350  1366.5  0  450  1125  1800  1333.5  1350  1350  1366.5  225  900 ...
    1575  2025  1333.5  1350  1350  1366.5  0  450  1125  1800  1333.5  1350  1350  1366.5];

PFC_B.Connector = ones(1,32).*2;

PFC_B.SiteType(1:4) = 1; PFC_B.SiteType(5:8) = 2; PFC_B.SiteType = repmat(PFC_B.SiteType, 1, 4);

%% SC Details
SC.Region(1:64) = {'SC'};
SC.ElectrodeNum = [9  8  10  7  11  6  12  5  13  4  14  3  15  2  16  1  25  22  28  24  26  20  29  23  27  18  31  21 ...
    30  17  32  19  41  40  42  39  43  38  44  37  45  36  46  35  47  34  48  33  57  54  60  56  58  52  61  55  59 ...
    50  63  53  62  49  64  51];
SC.Remap        = [50	41	49	42	52	43	51	44	54	45	53	46	56	47	55	48	61	1	57	64	59	3	58	63	60	...
    8	2	4	62	7	6	5	40	13	39	11	38	12	37	9	36	10	35	14	34	16	33	15	24	27	21	25	23	29	...
    20	26	22	31	18	28	19	32	17	30];
    
SC.Shank(1:16)  = 1;
SC.Shank(17:32) = 2;
SC.Shank(33:48) = 3;
SC.Shank(49:64) = 4;

SC.X = [0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  333  316.5  349.5  333  333  316.5  349.5  333  333  316.5  349.5 ...
    333  333  316.5  349.5  333  666  666  666  666  666  666  666  666  666  666  666  666  666  666  666  666  999 ...
    982.5  1015.5  999  999  982.5  1015.5  999  999  982.5  1015.5  999  999  982.5  1015.5  999];
SC.Y = [0  125  250  375  500  625  750  875  1000  1125  1250  1375  1500  1625  1750  1875  -66.5  -50  -50  -33.5 ...
    533.5  550  550  566.5  1133.5  1150  1150  1166.5  1733.5  1750  1750  1766.5  0  125  250  375  500  625  750  875 ...
    1000  1125  1250  1375  1500  1625  1750  1875  -66.5  -50  -50  -33.5  533.5  550  550  566.5  1133.5  1150  1150 ...
    1166.5  1733.5  1750  1750  1766.5];

SC.X_Label = repmat([zeros(1,16) -60 -90 -10 -60 -60 -90 -10 -60 -60 -90 -10 -60 -60 -90 -10 -60 ], 1,2);
SC.X_Label = SC.X_Label + (SC.X+15);

SC.Y_Label = repmat([zeros(1,16) -45 0 0 +45 -45 0 0 +45 -45 0 0 +45 -45 0 0 +45], 1,2);
SC.Y_Label = SC.Y_Label + SC.Y;

SC.Connector = [2  1  2  1  2  1  2  1  2  1  2  1  2  1  2  1  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  1  2  1  2 ...
    1  2  1  2  1  2  1  2  1  2  1  2  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1];

SC.SiteType(1:16) = 1; SC.SiteType(17:32) = 2; SC.SiteType = repmat(SC.SiteType, 1, 2);

%% SC_A Details
SC_A.Region(1:32) = {'SC'};
SC_A.ElectrodeNum = [8  7  6  5  4  3  2  1  41  42  43  44  45  46  47  48  57  54  60  56  58  52  61  55  59  50 ...
    63  53  62  49  64  51];
SC_A.Remap        = [21	28	22	27	23	26	24	25	29	20	30	19	31	18	32	17	5	14	11	13	12	15	7	4	...
    6	16	8	3	10	1	9	2];

SC_A.Shank(1:8)  = 1;
SC_A.Shank(9:16) = 3;
SC_A.Shank(17:32) = 4;

SC_A.X = [0  0  0  0  0  0  0  0  666  666  666  666  666  666  666  666  999  982.5  1015.5  999  999  982.5  1015.5 ...
    999  999  982.5  1015.5  999  999  982.5  1015.5  999];
SC_A.Y = [125  375  625  875  1125  1375  1625  1875  0  250  500  750  1000  1250  1500  1750  -66.5  -50  -50  -33.5 ...
    533.5  550  550  566.5  1133.5  1150  1150  1166.5  1733.5  1750  1750  1766.5];

SC_A.Connector = ones(1,32);

SC_A.SiteType(1:16) = 1; SC_A.SiteType(17:32) = 2;

%% SC_B Details
SC_B.Region(1:32) = {'SC'};
SC_B.ElectrodeNum = [9  10  11  12  13  14  15  16  25  22  28  24  26  20  29  23  27  18  31  21  30  17  32  19  40 ...
    39  38  37  36  35  34  33];
SC_B.Remap        = [24	25	23	26	22	27	21	28	31	1	29	17	30	2	20	32	19	13	16	15	18	4	14	3	7	...
    6	11	5	12	10	9	8];

SC_B.Shank(1:8)  = 1;
SC_B.Shank(9:24) = 2;
SC_B.Shank(25:32) = 3;

SC_B.X = [0  0  0  0  0  0  0  0  333  316.5  349.5  333  333  316.5  349.5  333  333  316.5  349.5  333  333  316.5 ...
    349.5  333  666  666  666  666  666  666  666  666];
SC_B.Y = [0  250  500  750  1000  1250  1500  1750  -66.5  -50  -50  -33.5  533.5  550  550  566.5  1133.5  1150  1150 ...
    1166.5  1733.5  1750  1750  1766.5  125  375  625  875  1125  1375  1625  1875];

SC_B.Connector = ones(1,32).*2;

SC_B.SiteType(1:8) = 1; SC_B.SiteType(9:24) = 2; SC_B.SiteType(25:32) = 1;
%% PRC Details
PRC.Region(1:64) = {'PRC'};
PRC.ElectrodeNum = [9  8  10  7  11  6  12  5  13  4  14  3  15  2  16  1  25  22  28  24  26  20  29  23  27  18  31  21 ...
    30  17  32  19  41  40  42  39  43  38  44  37  45  36  46  35  47  34  48  33  57  54  60  56  58  52  61  55  59 ...
    50  63  53  62  49  64  51];
PRC.Remap        = [50	41	49	42	52	43	51	44	54	45	53	46	56	47	55	48	61	1	57	64	59	3	58	63	60	8	...
    2	4	62	7	6	5	40	13	39	11	38	12	37	9	36	10	35	14	34	16	33	15	24	27	21	25	23	29	20	26	...
    22	31	18	28	19	32	17	30];
    
PRC.Shank(1:16)  = 1;
PRC.Shank(17:32) = 2;
PRC.Shank(33:48) = 3;
PRC.Shank(49:64) = 4;

PRC.X = [0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  333  316.5  349.5  333  333  316.5  349.5  333  333  316.5  349.5 ...
    333  333  316.5  349.5  333  666  666  666  666  666  666  666  666  666  666  666  666  666  666  666  666  999 ...
    982.5  1015.5  999  999  982.5  1015.5  999  999  982.5  1015.5  999  999  982.5  1015.5  999];
PRC.Y = [0  125  250  375  500  625  750  875  1000  1125  1250  1375  1500  1625  1750  1875  483.5  500  500  516.5 ...
    783.5  800  800  816.5  1083.5  1100  1100  1116.5  1383.5  1400  1400  1416.5  0  125  250  375  500  625  750  875 ...
    1000  1125  1250  1375  1500  1625  1750  1875  483.5  500  500  516.5  783.5  800  800  816.5  1083.5  1100  1100 ...
    1116.5  1383.5  1400  1400  1416.5];

PRC.Connector = [2  1  2  1  2  1  2  1  2  1  2  1  2  1  2  1  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  1  2  1  2 ...
    1  2  1  2  1  2  1  2  1  2  1  2  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1];

PRC.SiteType(1:16) = 1; PRC.SiteType(17:32) = 2; PRC.SiteType = repmat(PRC.SiteType, 1, 2);

%% PRC_A Details
PRC_A.Region(1:32) = {'PRC'};
PRC_A.ElectrodeNum = [8  7  6  5  4  3  2  1  41  42  43  44  45  46  47  48  57  54  60  56  58  52  61  55  59  50 ...
    63  53  62  49  64  51];
PRC_A.Remap        = [21	28	22	27	23	26	24	25	29	20	30	19	31	18	32	17	5	14	11	13	12	15	7	...
    4	6	16	8	3	10	1	9	2];

PRC_A.Shank(1:8)  = 1;
PRC_A.Shank(9:16) = 3;
PRC_A.Shank(17:32) = 4;

PRC_A.X = [0  0  0  0  0  0  0  0  666  666  666  666  666  666  666  666  999  982.5  1015.5  999  999  982.5  1015.5 ...
    999  999  982.5  1015.5  999  999  982.5  1015.5  999];
PRC_A.Y = [125  375  625  875  1125  1375  1625  1875  0  250  500  750  1000  1250  1500  1750  483.5  500  500  516.5 ...
    783.5  800  800  816.5  1083.5  1100  1100  1116.5  1383.5  1400  1400  1416.5];

PRC_A.Connector = ones(1,32);

PRC_A.SiteType(1:16) = 1; PRC_A.SiteType(17:32) = 2;

%% PRC_B Details
PRC_B.Region(1:32) = {'PRC'};
PRC_B.ElectrodeNum = [9  10  11  12  13  14  15  16  25  22  28  24  26  20  29  23  27  18  31  21  30  17  32  19  40 ...
    39  38  37  36  35  34  33];
PRC_B.Remap        = [24	25	23	26	22	27	21	28	31	1	29	17	30	2	20	32	19	13	16	15	18	4	14	3	...
    7	6	11	5	12	10	9	8];

PRC_B.Shank(1:8)  = 1;
PRC_B.Shank(9:24) = 2;
PRC_B.Shank(25:32) = 3;

PRC_B.X = [0  0  0  0  0  0  0  0  333  316.5  349.5  333  333  316.5  349.5  333  333  316.5  349.5  333  333  316.5 ...
    349.5  333  666  666  666  666  666  666  666  666];
PRC_B.Y = [0  250  500  750  1000  1250  1500  1750  483.5  500  500  516.5  783.5  800  800  816.5  1083.5  1100  1100 ...
    1116.5  1383.5  1400  1400  1416.5  125  375  625  875  1125  1375  1625  1875];

PRC_B.Connector = ones(1,32).*2;

PRC_B.SiteType(1:8) = 1; PRC_B.SiteType(9:24) = 2; PRC_B.SiteType(25:32) = 1;

%% EType Details
EType.Region(1:64) = {'VTA'};
EType.ElectrodeNum = [26  21  35  34  33  25  24  38  37  36  28  23  41  40  39  27  22  44  43  42  30  19  20  46  45 ...
    32  29  18  17  47  50  48  12  54  53  56  4  13  14  52  51  2  3  16  15  49  1  31  8  11  61  64  63  7  10  60 ...
    59  62  6  9  55  58  57  5];
EType.Remap        = [23	28	14	15	16	24	25	11	12	13	21	26	8	9	10	22	27	5	6	7	19	30	29	3	...
    4	17	20	31	32	2	63	1	37	59	60	57	45	36	35	61	62	47	46	33	34	64	48	18	41	38	52	49	50	...
    42	39	53	54	51	43	40	58	55	56	44]; 
    
EType.Shank(1:16)  = 1;
EType.Shank(17:32) = 2;
EType.Shank(33:48) = 3;
EType.Shank(49:64) = 4;

EType.X = [0  75  5  70  10  65  15  60  20  55  25  50  30  45  35  40  250  325  255  320  260  315  265  310  270  305 ...
    275  300  280  295  285  290  500  575  505  570  510  565  515  560  520  555  525  550  530  545  535  540  750 ...
    825  755  820  760  815  765  810  770  805  775  800  780  795  785  790];
EType.Y = [0  20  40  60  80  100  120  140  160  180  200  220  240  260  280  300  0  20  40  60  80  100  120  140 ...
    160  180  200  220  240  260  280  300  0  20  40  60  80  100  120  140  160  180  200  220  240  260  280  300  0 ...
    20  40  60  80  100  120  140  160  180  200  220  240  260  280  300];

EType.Connector = [1  1  2  2  2  1  1  2  2  2  1  1  2  2  2  1  1  2  2  2  1  1  1  2  2  1  1  1  1  2  2  2  1  2 ...
    2  2  1  1  1  2  2  1  1  1  1  2  1  1  1  1  2  2  2  1  1  2  2  2  1  1  2  2  2  1];

EType.SiteType(1:64) = 1;

%% EType_A Details
EType_A.Region(1:32) = {'VTA'};
EType_A.ElectrodeNum = [26  21  25  24  28  23  27  22  30  19  20  32  29  18  17  12  4  13  14  2  3  16  15  1  31  8 ...
    11  7  10  6  9  5];
EType_A.Remap        = [12	3	5	13	11	4	6	14	10	2	15	9	7	16	1	19	23	31	18	24	26	17	32	25	8	...
    21	30	28	20	22	29	27];

EType_A.Shank = [1  1  1  1  1  1  1  2  2  2  2  2  2  2  2  3  3  3  3  3  3  3  3  3  3  4  4  4  4  4  4  4];

EType_A.X = [0  75  65  15  25  50  40  250  260  315  265  305  275  300  280  500  510  565  515  555  525  550  530 ...
    535  540  750  825  815  765  775  800  790];
EType_A.Y = [0  20  100  120  200  220  300  0  80  100  120  180  200  220  240  0  80  100  120  180  200  220  240 ...
    280  300  0  20  100  120  200  220  300];

EType_A.Connector = ones(1,32);

EType_A.SiteType(1:32) = 1;

%% EType_B Details
EType_B.Region(1:32) = {'VTA'};
EType_B.ElectrodeNum = [35  34  33  38  37  36  41  40  39  44  43  42  46  45  47  50  48  54  53  56  52  51  49  61 ...
    64  63  60  59  62  55  58  57];
EType_B.Remap        = [10	8	9	6	11	7	13	5	12	3	14	4	2	15	16	32	1	30	19	29	31	18	17	23	...
    25	24	27	22	26	20	28	21];

EType_B.Shank = [1  1  1  1  1  1  1  1  1  2  2  2  2  2  2  2  2  3  3  3  3  3  3  4  4  4  4  4  4  4  4  4];

EType_B.X = [5  70  10  60  20  55  30  45  35  325  255  320  310  270  295  285  290  575  505  570  560  520  545 ...
    755  820  760  810  770  805  780  795  785];
EType_B.Y = [40  60  80  140  160  180  240  260  280  20  40  60  140  160  260  280  300  20  40  60  140  160  260 ...
    40  60  80  140  160  180  240  260  280];

EType_B.Connector = ones(1,32).*2;

EType_B.SiteType(1:32) = 1;

%% Atlas Details
Atlas.Region(1:32) = {'VTA'};
Atlas.ElectrodeNum = [16  15  14  13  12  11  10  9  8  7  6  5  4  3  2  1 ...
    32  31  30  29  28  27  26  25  24  23  22  21  20  19  18  17];
Atlas.Remap        = [14	11	6	4	2	13	15	10	3	8	1	12	16	...
    9	5	7	22	19	29	27	20	31	23	18	25	30	21	32	24	17	26	28];

Atlas.Shank(1:16) = 1; Atlas.Shank(17:32) = 2; 

Atlas.X(1:16) = 0; Atlas.X(17:32) = 200; 
Atlas.Y = repmat(0:150:2250, 1, 2);
Atlas.Connector = ones(1,32).*1;
Atlas.SiteType(1:32) = 1;


%% EEG Details - Not actually accurate for geometry

EG.Region(1:32) = {'EEG'};
EG.ElectrodeNum = 1:32;
EG.Remap        = [9	10	11	12	13	14	15	16	17	18	19	20	21	22	23	24	...
    8	7	6	5	4	3	2	1	32	31	30	29	28	27	26	25];

EG.X(1:8)   = 0;
EG.X(9:16)  = 100;
EG.X(17:24) = 200;
EG.X(25:32) = 300;

EG.Y = repmat(0:100:700, 1, 4);

%%  parse input
switch electrodeType
    case 'PFC'
        electrode = PFC;
    case 'PFC_A'
        electrode = PFC_A;
    case 'PFC_B'
        electrode = PFC_B;
    case 'SC'
        electrode = SC;
    case 'SC_A'
        electrode = SC_A;
    case 'SC_B'
        electrode = SC_B;
    case 'EType'
        electrode = EType;
    case 'EType_A'
        electrode = EType_A;
    case 'EType_B'
        electrode = EType_B;
    case 'EG'
        electrode = EG;
end


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


