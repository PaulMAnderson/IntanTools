function electrode = generateChannelMap(varargin)
% Code to generate electrode channel maps for use with kilosort and other
% purposes
% All inputs are optional, if none are provided dialog will allow selection
% of probe type
% 'Electrode' : string describing electrode type: 
%               can be 'poly2-5mm','poly2-6mm' or 'Buzsaki64'
% 'Animal'    : string giving known animal number, allows automated
% selection based on recording names: can be 'PMA17,18,33,36,37
% 'Exclude'   : logical index of channels to registed as 'unconnected' i.e. bad
% 'Draw'      : generate a figure of the electrode, default = true
% 'Handle'    : Handle to draw in; default = newFigure
% 'Labels'    : Whether to label channels when drawing

% Updated on 07-10-2020 with a new mappping recieved from NNx
% 64 Channel Buzsaki64 probe added on 06-11-2021, fixed (correct) on
% 21-12-2021


%% Parse variable input arguments

p = inputParser; % Create object of class 'inputParser'
% define validation functions
valString = @(x) validateattributes(x, {'char','string','cell'},...
    {'nonempty'});

% validation functions
addParameter(p, 'Electrode', [], valString);
addParameter(p, 'Animal', [], valString);

addParameter(p, 'Exclude', [], @isnumeric);
addParameter(p, 'Draw', false, @islogical);
addParameter(p, 'Labels', true, @islogical);
addParameter(p, 'Handle',[], @ishandle);
addParameter(p, 'ZeroIndex',false, @islogical);
addParameter(p, 'Interactive', true, @islogical);

parse(p, varargin{:});

% unpack parser and convert units
electrodeType   = p.Results.Electrode;
animal          = p.Results.Animal; 
exclude         = p.Results.Exclude;
drawElectrode   = p.Results.Draw;
labels          = p.Results.Labels;
handle          = p.Results.Handle;
zeroIndex       = p.Results.ZeroIndex;
interactive     = p.Results.Interactive;

clear p

% Check animal 

if ~isempty(animal)
    if contains(animal,'PMA17')
        electrodeType = 'poly2-5mm';
    elseif contains(animal,'PMA18')
        electrodeType = 'poly2-6mm';
    elseif contains(animal,'PMA33')
        electrodeType = 'poly2-6mm';
    elseif contains(animal,'PMA36')
        electrodeType = 'poly2-5mm';
    elseif contains(animal,'PMA37')
        electrodeType = 'Buzsaki64';
    elseif contains(animal,'PMA41')
        electrodeType = 'Buzsaki64';
    end
end

% Check electrode 
electrodeTypes = {'poly2-5mm','poly2-6mm','Buzsaki64'};
if isempty(electrodeType)
    if interactive
        [indx,tf] = listdlg('PromptString','Choose an electrode type',...
        'ListString',electrodeTypes, 'SelectionMode','single');
        if tf
            electrodeType = electrodeTypes{indx};
        else
            assert(tf,'No electrode type chosen, cannot proceed.');
            electrode = [];
            return             
        end
    else
        warning('No electrode type found...');
        electrode = [];
        return
    end
end

% Check for longer string
for elecI = 1:length(electrodeTypes)
    if contains(electrodeType, electrodeTypes{elecI})
        electrodeType = electrodeTypes{elecI};
    end
end

electrodeType  = validatestring(electrodeType,electrodeTypes);

switch lower(electrodeType)
    
    case 'poly2-5mm' % This mapping was recieved through email on 07-10-20
        % Updated on 6-0-21 found several missing values...
    %% poly2-5mm Details    
    electrode.chanMap = [59,2,60,1,6,63,58,3,57,4,7,62,8,61,249,196,241,204,...
       233,212,225,220,229,224,237,216,245,208,253,200,64,5,51,10,52,9,14,...
       55,50,11,49,12,15,54,16,53,199,254,207,246,215,238,223,230,219,226,...
       211,234,203,242,195,250,56,13,43,18,44,17,22,47,42,19,41,20,23,46,...
       24,45,198,255,206,247,214,239,222,231,218,227,210,235,202,243,194,...
       251,48,21,35,26,36,25,30,39,34,27,33,28,31,38,32,37,197,256,205,248,...
       213,240,221,232,217,228,209,236,201,244,193,252,40,29,102,95,101,96,...
       91,98,103,94,104,93,90,99,89,100,188,129,180,137,172,145,164,153,...
       168,157,176,149,184,141,192,133,97,92,110,87,109,88,83,106,111,86,...
       112,85,82,107,81,108,187,130,179,138,171,146,163,154,167,158,175,...
       150,183,142,191,134,105,84,118,79,117,80,75,114,119,78,120,77,74,...
       115,73,116,186,131,178,139,170,147,162,155,166,159,174,151,182,143,...
       190,135,113,76,126,71,125,72,67,122,127,70,128,69,66,123,65,124,136,...
       189,144,181,152,173,160,165,156,161,148,169,140,177,132,185,121,68];
    electrode.Number = electrode.chanMap; % Only in 128/256 channel count electrode are the channel numbers and electrode numbers the same    
    electrode.Intan = electrode.chanMap - 1;
    
    [~, sortIndx] = sort(electrode.chanMap);
    % Programmaticly generate coordinate, location and shank data
    chanCount = 1;
    
    for shankI = 1:8
        for chanI = 1:32

            electrode.Shank(chanCount)    = shankI; % shanks are numbered left to right
            electrode.Location(chanCount) = chanCount; % locations are numbered tip to top

            % Electrode Geometry - Tip of shank 1 is origin, x-values increase
            % to right (along with shank numbers), y-values increase up the shank
            % This Probe has 150 um spacing between shanks
            % Contacts checkerboard up the probe with 20um between contacts in
            % a row (10 um between alternating sides), contacts are spaced
            % 17.32 um apart from each other, i.e. 8.66 um either side oh shank centre

            if chanI < 31
                electrode.xcoords(chanCount)  = (shankI-1)*150 - ...
                    (( ((mod(chanI,2)) * - 2) + 1) * 8.66 ); 
                % this just adds 8.66 if odd and subtracts if even
                electrode.ycoords(chanCount)  = 35 + (chanI-1)*10;
                electrode.SiteType{chanCount} = 'Normal';
            else
                electrode.xcoords(chanCount)  = 0 + (shankI-1) * 150;
                electrode.ycoords(chanCount)  = 290 + (chanI-30) * 100 + (shankI-1) * 100;
                electrode.SiteType{chanCount} = 'Reference';
            end

            % Define K-coords, meaning the grouping kilosort uses to force
            % templates together

            if strcmp(electrode.SiteType{chanCount},'Normal')
                electrode.kcoords(chanCount) = electrode.Shank(chanCount);
            else
                electrode.kcoords(chanCount) = electrode.Shank(chanCount) + 10;
            end
            electrode.connected(chanCount) = true;
            chanCount = chanCount+1;
        end     
    end
    
    electrode.name = 'A8x32-poly2-5mm-20s-150-160 IH256';
    
    % sort the electrode Data to start with electrode #1
    electrode.chanMap   = electrode.chanMap(sortIndx);
    electrode.Number    = electrode.Number(sortIndx);
    electrode.Shank     = electrode.Shank(sortIndx);
    electrode.Location  = electrode.Location(sortIndx);
    electrode.xcoords   = electrode.xcoords(sortIndx);
    electrode.ycoords   = electrode.ycoords(sortIndx);
    electrode.SiteType  = electrode.SiteType(sortIndx);
    electrode.kcoords   = electrode.kcoords(sortIndx);
    electrode.connected = electrode.connected(sortIndx);
    % Not 100% sure this is correct...
    electrode.Connector(1:128)   = 1;
    electrode.Connector(129:256) = 2;
    electrode.Intan     = electrode.Intan(sortIndx);        
    
    % Define Bad Channels - !!!! Specific to animal PMA17 !!!!
    % Identified through visual inspection and Impedence measurements - Updated 20-10-2020
    % Channels A000-A127 = 1:128, B000-B127 = 129:256; i.e. 155 = 26+1+128
    
%     % Now using automatically defined bad channels throuigh impedance
%     % measurements 02-12-2020
%     if isempty(exclude)
%         badChans = []; % [155 176 181 190 192 222]; % B26 B52 B61 B93    
%     else
%         badChans = exclude;
%     end
    
    electrode.connected(exclude) = false;
    
    % Hard coded values - can be used for verification
%     electrode.Shank = [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, ...
%         1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,...
%         2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,...
%         3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,...
%         4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,...
%         5,5,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,...
%         6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,...
%         7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,...
%         8,8,8,8,8,8,8,8];
%     electrode.Location = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,...
%         19,20,21,22,23,24,25,26,27,28,29,30,31,32,1,2,3,4,5,6,7,8,9,10, ...
%         11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31, ...
%         32,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23, ...
%         24,25,26,27,28,29,30,31,32,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15, ...
%         16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,1,2,3,4,5,6, ...
%         7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28, ...
%         29,30,31,32,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20, ...
%         21,22,23,24,25,26,27,28,29,30,31,32,1,2,3,4,5,6,7,8,9,10,11,12, ...
%         13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,1,2,...
%         3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,  ...
%         26,27,28,29,30,31,32];
%     electrode.xcoord = [8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,   ...
%         8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,    ...
%         -8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,   ...
%         0,0,158.66,141.34,158.66,141.34,158.66,141.34,158.66, 141.34,   ...
%         158.66,141.34,158.66,141.34,158.66,141.34,158.66,141.34,158.66, ...
%         141.34,158.66,141.34,158.66,141.34,158.66,141.34,158.66,141.34, ...
%         158.66,141.34,158.66,141.34,150,150,308.66,291.34,308.66,291.34,...
%         308.66,291.34,308.66,291.34,308.66,291.34,308.66,291.34,308.66, ...
%         291.34,308.66,291.34,308.66,291.34,308.66,291.34,308.66,291.34, ...
%         308.66,291.34,308.66,291.34,308.66,291.34,308.66,291.34,300,300,...
%         458.66,441.34,458.66,441.34,458.66,441.34,458.66,441.34,458.66, ...
%         441.34,458.66,441.34,458.66,441.34,458.66,441.34,458.66,441.34, ...
%         458.66,441.34,458.66,441.34,458.66,441.34,458.66,441.34,458.66, ...
%         441.34,458.66,441.34,450,450,608.66,591.34,608.66,591.34,608.66 ...
%         591.34,608.66,591.34,608.66,591.34,608.66,591.34,608.66,591.34, ...
%         608.66,591.34,608.66,591.34,608.66,591.34,608.66,591.34,608.66, ...
%         591.34,608.66,591.34,608.66,591.34,608.66,591.34,600,600,758.66,...
%         741.34,758.66,741.34,758.66,741.34,758.66,741.34,758.66,741.34, ...
%         758.66,741.34,758.66,741.34,758.66,741.34,758.66,741.34,758.66, ...
%         741.34,758.66,741.34,758.66,741.34,758.66,741.34,758.66,741.34, ...
%         758.66,741.34,750,750,908.66,891.34,908.66,891.34,908.66,891.34,...
%         908.66,891.34,908.66,891.34,908.66,891.34,908.66,891.34,908.66, ...
%         891.34,908.66,891.34,908.66,891.34,908.66,891.34,908.66,891.34, ...
%         908.66,891.34,908.66,891.34,908.66,891.34,900,900,1058.66,      ...
%         1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,...
%         1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,...
%         1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,...
%         1041.34,1058.66,1041.34,1058.66,1041.34,1050,1050];
%     electrode.ycoord = [35,45,55,65,75,85,95,105,115,125,135,145,155,  ...
%         165,175,185,195,205,215,225,235,245,255,265,275,285,295,305,315,...
%         325,425,525,35,45,55,65,75,85,95,105,115,125,135,145,155,165,175,...
%         185,195,205,215,225,235,245,255,265,275,285,295,305,315,325,525 ...
%         625,35,45,55,65,75,85,95,105,115,125,135,145,155,165,175,185,195,...
%         205,215,225,235,245,255,265,275,285,295,305,315,325,625,725,35, ...
%         45,55,65,75,85,95,105,115,125,135,145,155,165,175,185,195,205,  ...
%         215,225,235,245,255,265,275,285,295,305,315,325,725,825,35,45   ...
%         55,65,75,85,95,105,115,125,135,145,155,165,175,185,195,205,215, ...
%         225,235,245,255,265,275,285,295,305,315,325,825,925,35,45,55,65,...
%         75,85,95,105,115,125,135,145,155,165,175,185,195,205,215,225,   ...
%         235,245,255,265,275,285,295,305,315,325,925,1025,35,45,55,65,75,...
%         85,95,105,115,125,135,145,155,165,175,185,195,205,215,225,235,  ...
%         245,255,265,275,285,295,305,315,325,1025,1125,35,45,55,65,75,85,...
%         95,105,115,125,135,145,155,165,175,185,195,205,215,225,235,245, ...
%         255,265,275,285,295,305,315,325,1125,1225];
    
    
    case 'poly2-6mm'
        %% 'poly2-6mm' Details
         electrode.chanMap = [5,64,59,2,58,3,60,1,6,63,7,62,8,61,249,196,...
             241,204,233,212,225,220,229,224,237,216,245,208,253,200,57,4,...
             13,56,51,10,50,11,52,9,14,55,15,54,16,53,199,254,207,246,215,...
             238,223,230,219,226,211,234,203,242,195,250,49,12,21,48,43,...
             18,42,19,44,17,22,47,23,46,24,45,198,255,206,247,214,239,222,...
             231,218,227,210,235,202,243,194,251,41,20,29,40,35,26,34,27,...
             36,25,30,39,31,38,32,37,197,256,205,248,213,240,221,232,217,...
             228,209,236,201,244,193,252,33,28,92,97,102,95,103,94,101,96,...
             91,98,90,99,89,100,188,129,180,137,172,145,164,153,168,157,...
             176,149,184,141,192,133,104,93,84,105,110,87,111,86,109,88,...
             83,106,82,107,81,108,187,130,179,138,171,146,163,154,167,158,...
             175,150,183,142,191,134,112,85,76,113,118,79,119,78,117,80,...
             75,114,74,115,73,116,186,131,178,139,170,147,162,155,166,159,...
             174,151,182,143,190,135,120,77,68,121,126,71,127,70,125,72,...
             67,122,66,123,65,124,136,189,144,181,152,173,160,165,156,161,...
             148,169,140,177,132,185,128,69];
    electrode.Number = electrode.chanMap; % Only in 128/256 channel count electrode are the channel numbers and electrode numbers the same    

    electrode.Intan = electrode.chanMap - 1;
    
    [~, sortIndx] = sort(electrode.chanMap);
    % Programmaticly generate coordinate, location and shank data
    chanCount = 1;
    
    for shankI = 1:8
        for chanI = 1:32

            electrode.Shank(chanCount)    = shankI; % shanks are numbered left to right
            electrode.Location(chanCount) = chanCount; % locations are numbered tip to top

            % Electrode Geometry - Tip of shank 1 is origin, x-values increase
            % to right (along with shank numbers), y-values increase up the shank
            % This Probe has 200 um spacing between shanks
            % Contacts checkerboard up the probe with 30um between contacts in
            % a row (15 um between alternating sides), contacts are spaced
            % 49 um apart from each other, i.e. 24.5 um either side oh shank centre

            electrode.xcoords(chanCount)  = (shankI-1)*200 - ...
                (( ((mod(chanI,2)) * - 2) + 1) * 24.5 ); 
            % this just adds 24.5 if odd and subtracts if even
            electrode.ycoords(chanCount)  = 50 + (chanI-1)*15;
            electrode.SiteType{chanCount} = 'Normal';

            % Define K-coords, meaning the grouping kilosort uses to force
            % templates together
            electrode.kcoords(chanCount) = electrode.Shank(chanCount);
            electrode.connected(chanCount) = true;
            chanCount = chanCount+1;
        end     
    end
       
    electrode.name = 'A8x32-poly2-6mm-30s-200-121 IH256';
    
    % sort the electrode Data to start with electrode #1
    electrode.chanMap   = electrode.chanMap(sortIndx);
    electrode.Number    = electrode.Number(sortIndx);
    electrode.Shank     = electrode.Shank(sortIndx);
    electrode.Location  = electrode.Location(sortIndx);
    electrode.xcoords   = electrode.xcoords(sortIndx);
    electrode.ycoords   = electrode.ycoords(sortIndx);
    electrode.SiteType  = electrode.SiteType(sortIndx);
    electrode.kcoords   = electrode.kcoords(sortIndx);
    electrode.connected = electrode.connected(sortIndx);
    % electrode.Connector = electrode.Connector(sortIndx);
    % Not 100% sure this is correct...
    electrode.Connector(1:128)   = 1;
    electrode.Connector(129:256) = 2;
    
    electrode.Intan     = electrode.Intan(sortIndx);
    
    % Define Bad Channels - !!!! Specific to animal PMA18 !!!   
    % Now using automatically defined bad channels throuigh impedance
    % measurements
%     if isempty(exclude)
%         badChans = []; % [78 79 80 113 161]; % A77 A78 A79 A112 B32
%     else
%         badChans = exclude;
%     end
    
    electrode.connected(exclude) = false;

%     % Hard coded values - can be used for verification
% %     electrode.Shank = [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, ...
% %         1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,...
% %         2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,...
% %         3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,...
% %         4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,...
% %         5,5,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,...
% %         6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,...
% %         7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,...
% %         8,8,8,8,8,8,8,8];
% %     electrode.Location = [[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,...
% %         19,20,21,22,23,24,25,26,27,28,29,30,31,32,1,2,3,4,5,6,7,8,9,10, ...
% %         11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31, ...
% %         32,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23, ...
% %         24,25,26,27,28,29,30,31,32,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15, ...
% %         16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,1,2,3,4,5,6, ...
% %         7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28, ...
% %         29,30,31,32,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20, ...
% %         21,22,23,24,25,26,27,28,29,30,31,32,1,2,3,4,5,6,7,8,9,10,11,12, ...
% %         13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,1,2,...
% %         3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,  ...
% %         26,27,28,29,30,31,32];
% %     electrode.xcoord = [8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,   ...
% %         8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,    ...
% %         -8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,   ...
% %         0,0,158.66,141.34,158.66,141.34,158.66,141.34,158.66, 141.34,   ...
% %         158.66,141.34,158.66,141.34,158.66,141.34,158.66,141.34,158.66, ...
% %         141.34,158.66,141.34,158.66,141.34,158.66,141.34,158.66,141.34, ...
% %         158.66,141.34,158.66,141.34,150,150,308.66,291.34,308.66,291.34,...
% %         308.66,291.34,308.66,291.34,308.66,291.34,308.66,291.34,308.66, ...
% %         291.34,308.66,291.34,308.66,291.34,308.66,291.34,308.66,291.34, ...
% %         308.66,291.34,308.66,291.34,308.66,291.34,308.66,291.34,300,300,...
% %         458.66,441.34,458.66,441.34,458.66,441.34,458.66,441.34,458.66, ...
% %         441.34,458.66,441.34,458.66,441.34,458.66,441.34,458.66,441.34, ...
% %         458.66,441.34,458.66,441.34,458.66,441.34,458.66,441.34,458.66, ...
% %         441.34,458.66,441.34,450,450,608.66,591.34,608.66,591.34,608.66 ...
% %         591.34,608.66,591.34,608.66,591.34,608.66,591.34,608.66,591.34, ...
% %         608.66,591.34,608.66,591.34,608.66,591.34,608.66,591.34,608.66, ...
% %         591.34,608.66,591.34,608.66,591.34,608.66,591.34,600,600,758.66,...
% %         741.34,758.66,741.34,758.66,741.34,758.66,741.34,758.66,741.34, ...
% %         758.66,741.34,758.66,741.34,758.66,741.34,758.66,741.34,758.66, ...
% %         741.34,758.66,741.34,758.66,741.34,758.66,741.34,758.66,741.34, ...
% %         758.66,741.34,750,750,908.66,891.34,908.66,891.34,908.66,891.34,...
% %         908.66,891.34,908.66,891.34,908.66,891.34,908.66,891.34,908.66, ...
% %         891.34,908.66,891.34,908.66,891.34,908.66,891.34,908.66,891.34, ...
% %         908.66,891.34,908.66,891.34,908.66,891.34,900,900,1058.66,      ...
% %         1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,...
% %         1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,...
% %         1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,1041.34,1058.66,...
% %         1041.34,1058.66,1041.34,1058.66,1041.34,1050,1050];
% %     electrode.ycoord = [35,45,55,65,75,85,95,105,115,125,135,145,155,  ...
% %         165,175,185,195,205,215,225,235,245,255,265,275,285,295,305,315,...
% %         325,425,525,35,45,55,65,75,85,95,105,115,125,135,145,155,165,175,...
% %         185,195,205,215,225,235,245,255,265,275,285,295,305,315,325,525 ...
% %         625,35,45,55,65,75,85,95,105,115,125,135,145,155,165,175,185,195,...
% %         205,215,225,235,245,255,265,275,285,295,305,315,325,625,725,35, ...
% %         45,55,65,75,85,95,105,115,125,135,145,155,165,175,185,195,205,  ...
% %         215,225,235,245,255,265,275,285,295,305,315,325,725,825,35,45   ...
% %         55,65,75,85,95,105,115,125,135,145,155,165,175,185,195,205,215, ...
% %         225,235,245,255,265,275,285,295,305,315,325,825,925,35,45,55,65,...
% %         75,85,95,105,115,125,135,145,155,165,175,185,195,205,215,225,   ...
% %         235,245,255,265,275,285,295,305,315,325,925,1025,35,45,55,65,75,...
% %         85,95,105,115,125,135,145,155,165,175,185,195,205,215,225,235,  ...
% %         245,255,265,275,285,295,305,315,325,1025,1125,35,45,55,65,75,85,...
% %         95,105,115,125,135,145,155,165,175,185,195,205,215,225,235,245, ...
% %         255,265,275,285,295,305,315,325,1125,1225];
    
    case 'buzsaki64'
        % Updated on 21-12-2021 - was wrong previously...
    electrode.chanMap   = 1:64;
    electrode.Number    = [49	50	51	52	53	54	55	56	57	58	59	60 ...
    	61	62	63	64	37	36	39	38	40	35	42	41	43	34	45	44	46	...
        33	48	47	17	18	19	32	20	21	22	31	23	24	25	30	26	27	...
        28	29	2	1	4	3	6	5	8	7	10	9	12	11	14	13	16	15];
    % This is the numbers as used on the NeuroNexus Probe Sheet
    electrode.Shank     = [7	7	7	7	7	7	7	7	8	8	8	8	...
        8	8	8	8	5	5	5	5	5	5	6	6	6	5	6	6	6	...
        5	6	6	3	3	3	4	3	3	3	4	3	3	4	4	4	4	...
        4	4	1	1	1	1	1	1	1	1	2	2	2	2	2	2	2	2];
    electrode.Location  = [8	6	4	2	1	3	5	7	8	6	4	2	...
        1	3	5	7	1	2	5	3	7	4	6	8	4	6	1	2	3	...
        8	7	5	8	6	4	7	2	1	3	5	5	7	8	3	6	4	...
        2	1	6	8	2	4	3	1	7	5	6	8	2	4	3	1	7	5];
    electrode.xcoords   = [1179.5	1183.5	1187.5	1191.5	1200	1208.5	...
        1212.5	1216.5	1379.5	1383.5	1387.5	1391.5	1400	1408.5	1412.5	...
        1416.5	800	791.50	812.50	808.50	816.50	787.50	983.50	979.50	...
        987.50	783.50	1000	991.50	1008.5	779.50	1016.5	1012.5	379.50	...
        383.50	387.50	616.50	391.50	400	408.50	612.50	412.50	416.50	...
        579.50	608.50	583.50	587.50	591.50	600	-16.500	-20.500	-8.5000	...
        -12.500	8.5000	0	16.500	12.500	183.50	179.50	191.50	187.50	208.50	200	216.50	212.50];
    electrode.ycoords   = [162	122	82	42	22	62	102	142	162	122	82	42	...
        22	62	102	142	22	42	102	62	142	82	122	162	82	122	22	42	62	...
        162	142	102	162	122	82	142	42	22	62	102	102	142	162	62	122	82	...
        42	22	122	162	42	82	62	22	142	102	122	162	42	82	62	22	142	102];
    electrode.SiteType  = repmat({'Normal'},1,64);
    electrode.kcoords   = electrode.Shank;
    electrode.connected = true(1,64);
    electrode.connected(exclude) = false;
    electrode.Intan = electrode.chanMap - 1;
    electrode.name = 'Buzsaki64 H64LP';

    otherwise 
        warning(['Provided electrode type not found...'...
            ' currently defined types are: ' ...
            strjoin(electrodeTypes,', ')]);
        
end


% Draw the electrode here
if drawElectrode
    if isempty(handle)
        fig = figure;
        handle = axes(fig);
    end
         
    electrodePlot = scatter(handle, electrode.xcoords(electrode.connected),...
        electrode.ycoords(electrode.connected), 30, ...
        electrode.kcoords(electrode.connected),'filled');
    % Colours signify groups for spike sorting
    
    if labels
        if zeroIndex
            labelText = cellstr(num2str([electrode.Number]' - 1));
        else
            labelText = cellstr(num2str([electrode.Number]'));
        end
        hold on
        % Need to work out which are on the left of the shank and which are
        % on the right
        shanks = unique(electrode.Shank);
        for shankI = 1:length(shanks)
            shankIdx = find(electrode.Shank == shanks(shankI));
            % Find unique X Positions
            xPlaces = unique(electrode.xcoords(shankIdx));
            midX = median(xPlaces);
            for j = 1:length(shankIdx)
                if electrode.xcoords(shankIdx(j)) <= midX
                    electrode.xLabel(shankIdx(j)) = ...
                        electrode.xcoords(shankIdx(j)) - 30;
                else
                    electrode.xLabel(shankIdx(j)) = ...
                        electrode.xcoords(shankIdx(j)) + 20;
                end
                electrode.ylabel(shankIdx(j)) = electrode.ycoords(shankIdx(j));
            end
        end
        text(electrode.xLabel(electrode.connected), ...
             electrode.ylabel(electrode.connected), ...
             labelText(electrode.connected));
    end

    %     switch electrodeType
%         case 'Buzsaki64'
%             ax.YLim = [ -10 1000];
%     end

    hold off
end
    