function electrode = generateChannelMap(type, exclude, drawElectrode)

if nargin < 3
    drawElectrode = false;
end
if nargin < 2
    exclude = [];
end

% Updated on 07-10-2020 with a new mappping recieved from NNx

electrodeTypes = {'poly2-5mm','poly2-6mm'};

if contains(type,'17')
    type = 'poly2-5mm';
elseif contains(type,'18')
    type = 'poly2-6mm';
end

switch lower(type)
    
    case 'poly2-5mm' % This mapping was recieved through email on 07-10-20
    %% poly2-5mm Details
    electrode.chanMap = [59,2,60,1,6,63,58,3,57,4,7,62,8,61,249,196,241,204,233,...
        212,225,220,229,224,237,216,245,208,253,200,64,5,51,10,52,9,14,...
        55,50,11,49,12,15,54,16,53,199,254,207,246,215,238,23,230,219, ...
        226,211,234,203,242,195,250,56,13,43,18,44,17,22,47,42,19,41,  ...
        20,23,46,24,45,198,255,206,247,214,239,222,231,218,227,210,235,...
        202,243,194,251,48,21,35,26,36,25,30,39,34,27,33,28,31,38,32,37,...
        197,256,205,248,213,240,221,232,217,228,209,236,201,244,193,252,...
        48,21,102,95,101,96,91,98,103,94,104,93,90,99,89,100,188,129,180,...
        137,172,145,164,153,168,157,176,149,184,141,192,133,40,29,110,87,...
        109,88,83,106,111,86,112,85,82,107,81,108,187,130,179,138,171,146,...
        163,154,167,158,175,150,183,142,191,134,97,92,118,79,117,80,75,114,...
        119,78,120,77,74,115,73,116,186,131,178,139,170,147,162,155,166,...
        159,174,151,182,143,190,135,113,76,126,71,125,72,67,122,127,70,...
        128,69,66,123,65,124,136,189,144,181,152,173,160,165,156,161,148,...
        169,140,177,132,185,121,68];

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
                electrode.kcoords(chanCount) = electrode.Shank(chanCount) + 100;
            end
            electrode.connected(chanCount) = true;
            chanCount = chanCount+1;
        end     
    end
    
    % Not 100% sure this is correct...
    electrode.Connector(1:128)   = 1;
    electrode.Connector(129:256) = 2;
       
    electrode.name = 'A8x32-poly2-5mm-20s-150-160 IH256';
    
    % sort the electrode Data to start with electrode #1
    electrode.chanMap   = electrode.chanMap(sortIndx);
    electrode.Shank     = electrode.Shank(sortIndx);
    electrode.Location  = electrode.Location(sortIndx);
    electrode.xcoords   = electrode.xcoords(sortIndx);
    electrode.ycoords   = electrode.ycoords(sortIndx);
    electrode.SiteType  = electrode.SiteType(sortIndx);
    electrode.kcoords   = electrode.kcoords(sortIndx);
    electrode.connected = electrode.connected(sortIndx);
    electrode.Connector = electrode.Connector(sortIndx);
    electrode.Intan     = electrode.Intan(sortIndx);        
    
    % Define Bad Channels - !!!! Specific to animal PMA17 !!!!
    % Identified through visual inspection and Impedence measurements - Updated 20-10-2020
    % Channels A000-A127 = 1:128, B000-B127 = 129:256; i.e. 155 = 26+1+128
    
    % Now using automatically defined bad channels throuigh impedance
    % measurements 02-12-2020
    if isempty(exclude)
        badChans = [155 176 181 190 192 222]; % B26 B52 B61 B93    
    else
        badChans = exclude;
    end
    
    electrode.connected(badChans) = false;
    
    
    
    
    % Draw the electrode here
    if drawElectrode
        electrodePlot = scatter(electrode.xcoords,electrode.ycoords,...
            30,electrode.kcoords,'filled');
        % Colours signify groups for spike sorting
        hold on
        for j = 1:length(electrode.xcoords)
            if mod(electrode.xcoords(j),150) < 10
                electrode.xlabel(j) = electrode.xcoords(j) + 15;
            else
                electrode.xlabel(j) = electrode.xcoords(j) - 50;
            end
            electrode.ylabel(j) = electrode.ycoords(j);
        end
        text(electrode.xlabel, electrode.ylabel,cellstr(num2str(electrode.Intan')))

        hold off
    end
    
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
%     electrode.xcoords = [8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,   ...
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
%     electrode.ycoords = [35,45,55,65,75,85,95,105,115,125,135,145,155,  ...
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
    
        % Not 100% sure this is correct...
    electrode.Connector(1:128)   = 1;
    electrode.Connector(129:256) = 2;
       
    electrode.name = 'A8x32-poly2-6mm-30s-200-121 IH256';
    
    % sort the electrode Data to start with electrode #1
    electrode.chanMap   = electrode.chanMap(sortIndx);
    electrode.Shank     = electrode.Shank(sortIndx);
    electrode.Location  = electrode.Location(sortIndx);
    electrode.xcoords   = electrode.xcoords(sortIndx);
    electrode.ycoords   = electrode.ycoords(sortIndx);
    electrode.SiteType  = electrode.SiteType(sortIndx);
    electrode.kcoords   = electrode.kcoords(sortIndx);
    electrode.connected = electrode.connected(sortIndx);
    electrode.Connector = electrode.Connector(sortIndx);
    electrode.Intan     = electrode.Intan(sortIndx);
    
    % Define Bad Channels - !!!! Specific to animal PMA18 !!!   
    % Now using automatically defined bad channels throuigh impedance
    % measurements
    if isempty(exclude)
        badChans = [78 79 80 113 161]; % A77 A78 A79 A112 B32
    else
        badChans = exclude;
    end
    
    electrode.connected(badChans) = false;
    

   % Draw the electrode here
    if drawElectrode
        electrodePlot = scatter(electrode.xcoords,electrode.ycoords,...
            30,electrode.kcoords,'filled');
        % Colours signify groups for spike sorting
        hold on
        for j = 1:length(electrode.xcoords)
            if mod(electrode.xcoords(j),200) < 25
                electrode.xlabel(j) = electrode.xcoords(j) + 15;
            else
                electrode.xlabel(j) = electrode.xcoords(j) - 50;
            end
            electrode.ylabel(j) = electrode.ycoords(j);
        end
        text(electrode.xlabel, electrode.ylabel,cellstr(num2str(electrode.Intan')))

        hold off
    end
    
    
    
    %%
%     case 'poly2-5mm' - This is based on the original physical mapping we
%     recieved, after emailing NNx we recieved a new one... this is what is
%     currently used 07-10-20
%     %% poly2-5mm Details� 
%     electrode.chanMap = [108,99,106,97,107,100,110,101,112,103,109,102, ...
%         111,104,209,218,193,202,177,186,161,170,169,162,185,178,201,194,...
%         217,210,98,105,124,115,122,113,123,116,126,117,128,119,125,118, ...
%         127,120,211,220,195,204,179,188,163,172,171,164,187,180,203,196,...
%         219,212,114,121,12,3,10,1,11,4,14,5,16,7,13,6,15,8,213,222,197, ...
%         206,181,190,165,174,173,166,189,182,205,198,221,214,2,9,28,19,  ...
%         26,17,27,20,30,21,32,23,29,22,31,24,216,223,200,207,184,191,168,...
%         175,176,167,192,183,208,199,224,215,18,25,43,36,41,34,44,35,45,  ...
%         38,47,40,46,37,48,39,234,225,250,241,138,129,154,145,146,153,130,   ...
%         137,242,249,226,233,33,42,59,52,57,50,60,51,61,54,63,56,62,53,  ...
%         64,55,235,228,251,244,139,132,155,148,147,156,131,140,243,252,  ...
%         227,236,49,58,75,68,73,66,76,67,77,70,79,72,78,69,80,71,237,230,...
%         253,246,141,134,157,150,149,158,133,142,245,254,229,238,65,74,  ...
%         91,84,89,82,92,83,93,86,95,88,94,85,96,87,239,232,255,248,143,  ...
%         136,159,152,151,160,135,144,247,256,231,240,81,90];
% 
%     % Programmaticly generate coordinate, location and shank data
%     chanCount = 1;
%     
%     for shankI = 1:8
%         for chanI = 1:32
% 
%             electrode.Shank(chanCount)    = shankI; % shanks are numbered left to right
%             electrode.Location(chanCount) = chanCount; % locations are numbered tip to top
% 
%             % Electrode Geometry - Tip of shank 1 is origin, x-values increase
%             % to right (along with shank numbers), y-values increase up the shank
%             % This Probe has 150 um spacing between shanks
%             % Contacts checkerboard up the probe with 20um between contacts in
%             % a row (10 um between alternating sides), contacts are spaced
%             % 17.32 um apart from each other, i.e. 8.66 um either side oh shank centre
% 
%             if chanI < 31
%                 electrode.xcoords(chanCount)  = (shankI-1)*150 - ...
%                     (( ((mod(chanI,2)) * - 2) + 1) * 8.66 ); 
%                 % this just adds 8.66 if odd and subtracts if even
%                 electrode.ycoords(chanCount)  = 35 + (chanI-1)*10;
%                 electrode.SiteType{chanCount} = 'Normal';
%             else
%                 electrode.xcoords(chanCount)  = 0 + (shankI-1) * 150;
%                 electrode.ycoords(chanCount)  = 290 + (chanI-30) * 100 + (shankI-1) * 100;
%                 electrode.SiteType{chanCount} = 'Reference';
%             end
% 
%             % Define K-coords, meaning the grouping kilosort uses to force
%             % templates together
% 
%             if strcmp(electrode.SiteType{chanCount},'Normal')
%                 electrode.kcoords(chanCount) = electrode.Shank(chanCount);
%             else
%                 electrode.kcoords(chanCount) = electrode.Shank(chanCount) + 8;
%             end
%             electrode.connected(chanCount) = true;
%             chanCount = chanCount+1;
%         end     
%     end
%     
%     % This is not correct yet...
%     electrode.Connector(1:64)    = 1;
%     electrode.Connector(65:128)  = 2;
%     electrode.Connector(129:192) = 3;
%     electrode.Connector(193:256) = 4;
%     
%     electrode.name = 'A8x32-poly2-5mm-20s-150-160 IH256';
%     
%     % Draw the electrode here
%     if drawElectrode
%         electrodePlot = scatter(electrode.xcoords,electrode.ycoords,...
%             30,electrode.kcoords,'filled');
%         % Colours signify groups for spike sorting
%         hold on
%         electrode.xlabel(1:2:length(electrode.xcoords)) = ...
%             electrode.xcoords(1:2:end) + 15;
%         electrode.xlabel(2:2:length(electrode.xcoords)) = ...
%             electrode.xcoords(2:2:end) - 50;  
%         electrode.ylabel = electrode.ycoords;
% 
%         text(electrode.xlabel, electrode.ylabel,cellstr(num2str(electrode.chanMap')))
% 
%         hold off
%     end
%     
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
% %     electrode.xcoords = [8.66,-8.66,8.66,-8.66,8.66,-8.66,8.66,-8.66,   ...
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
% %     electrode.ycoords = [35,45,55,65,75,85,95,105,115,125,135,145,155,  ...
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
    
    otherwise 
        warning(['Provided electrode type not found...'...
            ' currently defined types are: ' ...
            strjoin(electrodeTypes,', ')]);
        
end
    