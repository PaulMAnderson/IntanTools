function intanRec = intan2Matlab(recPath, portion)
%% Code to quickly load a (section of) Intan Recording
% based on Intan provided code and examples from Cortex lab https://github.com/cortex-lab/spikes

%% Step 1 - Intan Recording IO

% If data is recorded in single-file per channel-type format we can just
% directly load the channel data into kilosort

if nargin == 0
    [file, recPath, filterindex] = ...
    uigetfile('*.rhd', 'Select an RHD2000 Header File', 'MultiSelect', 'off');
else 
    [fileParts, ~] = strsplit(recPath,filesep);
    file = fileParts{end};
    recPath = strjoin(fileParts(1:end-1) , filesep);
    recPath = [recPath filesep];
end

rawDataFile    = dir([recPath 'amplifier.dat']);
eventDataFile   = dir([recPath 'digitalin.dat']);
timestampsFile  = dir([recPath 'time.dat']);

if isempty(rawDataFile)
    error('Couldn''t find channel data in this directory...')
elseif isempty(eventDataFile)
    error('Couldn''t find event data in this directory...')
elseif isempty(timestampsFile)
    error('Couldn''t find timestamps in this directory...')
end



%% Step 2 - Load the data

% Load the header data
intanRec = intanHeader([recPath file]);

fid = fopen([rawDataFile.folder filesep rawDataFile.name], 'r');

% Decide whether to load all the data
channelCount = length(intanRec.amplifier_channels);
dat = fread(fid, [channelCount inf], '*int16');


% Load Event and Time info
[eventData, timestamps] = intanEventTimes(intanRec, eventDataFile, timestampsFile);

% Load Channel Info
channelMap.Num = readNPY('channel_map.npy');
channelMap.Pos = readNPY('channel_positions.npy');

% Load Matlab file with recording info

mfile = dir('*OptoTagging*.mat');
try
    load(mfile.name)
catch
    warning('Unable to load matlab file containing recording session parameters');
end


%% Process event data 
% For this specific analysis we know that there is just a single event channel
% that represents laser activity, we will parse the times and interpret the
% results

allEvents      = [eventData.Time] * 1000; % Event Times in ms
eventIntervals = round(diff(allEvents),2); % Event intervals in ms with 0.01 ms precision

trialStarts = find(eventIntervals > 1000) + 1; 
% All laser intervals are less than 1 sec, this finds all events that had a
% more than 1000 ms gap before them, i,e. start of new trials
if eventIntervals(1) < 1000
    trialStarts = [1 trialStarts];
end

% Check that recorded number of trials and identified match
numTrials = length(trialStarts);

if numTrials ~= length(session.Params)
    warning('Detected trials does not match recorded parameters')
end

% Parse parameters from recording session file;

if ~isfield(session,'trialTypes')
% if session struct doesn't describe trialTypes we can make this

    freqs  = unique([session.Params.freq]);
    powers = unique([session.Params.power]);
    pulses = unique([session.Params.pulseLength]);

    trialType = 0;
    
    for freqI = 1:length(freqs)
        for powerI = 1:length(powers)
            for pulseI = 1:length(pulses)
                
                trialType = trialType + 1;
                trialTypes(trialType).freq        = freqs(freqI);
                trialTypes(trialType).power       = powers(powerI);
                trialTypes(trialType).pulseLength = pulses(pulseI);                   
                
                for trialI = 1:length(session.Params)
                    
                    if session.Params(trialI).freq        == freqs(freqI)...
                    && session.Params(trialI).power       == powers(powerI)...
                    && session.Params(trialI).pulseLength == pulses(pulseI)
                        
                        session.Params(trialI).trialType  = trialType;
                
                    end
                end

            end
        end
    end
    session.trialTypes = trialTypes;
    save(mfile.name,'session','-append')
end


% Calculate stim frequency per trial
samplingInterval = 1000 / intanRec.frequency_parameters.board_dig_in_sample_rate;

for trialI = 1:numTrials
   
    if trialI == numTrials % Special handling for final trial;
        currentEventIdx = trialStarts(trialI):length(eventData);
        currentEvents   = eventData(currentEventIdx);
    else
        currentEventIdx = trialStarts(trialI):trialStarts(trialI+1) - 1;
        currentEvents   = eventData(currentEventIdx);
    end
       
    % median laser interval for this trial
    currentInterval  = median(round(diff([currentEvents.Time]) .* 1000, 2));  
    currentFrequency = round(1000 ./ currentInterval); 
    currentDuration  = round(median([eventData(currentEventIdx).Duration]));
    
    % check if this matches saved parametrs
    matchesSavedParams = currentFrequency == session.Params(trialI).freq;
    
    for j = 1:length(currentEventIdx)
        if j == 1
            eventData(currentEventIdx(j)).Type   = 2;
        end
        eventData(currentEventIdx(j)).Trial     = trialI;
        eventData(currentEventIdx(j)).Frequency = currentFrequency;
        eventData(currentEventIdx(j)).Duration  = currentDuration;

        if matchesSavedParams
            eventData(currentEventIdx(j)).Power     = session.Params(trialI).power;
            eventData(currentEventIdx(j)).trialType = session.Params(trialI).trialType;
        end
    end    
end

eventTypes = [eventData.Type];
eventTimes = [eventData.Time];
powerType  = [eventData.Power];
stimLength = [eventData.Duration];
stimFreq   = [eventData.Frequency];
trialType  = [eventData.trialType];

% % convert power values into integers
% 
% uniqueEventTypes = unique(powerType);
% for j = 1:length(uniqueEventTypes)
%     powerType(powerType == uniqueEventTypes(j)) = j;
% end


end % End main intan2Matlab function 


%% Helper Functions

function ops = kilosortOptions(intanRec, recPath)

ops.chanMap = 'D:\Clustering Inlet\Paul\Code\Optotagging\Analysis\HugoA128_4shankPoly2_kilosortChanMap.mat';
% ops.chanMap = '/Users/Paul/Library/Mobile Documents/com~apple~CloudDocs/Documents/MedUni Wien/Code/Optotagging/Analysis/Filetype Checks/filePerType_200714_103426/chanMap.mat';
% ops.chanMap = 1:ops.Nchan; % treated as linear probe if no chanMap file

% Make a working directory and save the path
if ~exist([recPath 'Kilosort WD'],'dir')
    mkdir(recPath, 'Kilosort WD')
end
ops.fproc   = [recPath 'Kilosort WD' filesep 'temp_wh.dat']; % Path to working directory

% % Make a results directory and save the path
% if ~exist([path 'Kilosort Results' filesep],'dir')
%     mkdir(path, 'Kilosort Results')
% end
% ops.resultsDir   = [path 'Kilosort Results' filesep]; % Path to working directory
ops.resultsDir = recPath; % save the results in the recording folder, otrherwise Phy gets unhappy

% sample rate
ops.fs = intanRec.frequency_parameters.amplifier_sample_rate;

ops.NchanTOT = length(intanRec.amplifier_channels); % total number of channels in your recording

% frequency for high pass filtering (150)
ops.fshigh = 150;  

% minimum firing rate on a "good" channel (0 to skip)
ops.minfr_goodchannels = 0; 

% threshold on projections (like in Kilosort1, can be different for last pass like [10 4])
ops.Th = [10 4];  

% how important is the amplitude penalty (like in Kilosort1, 0 means not used, 10 is average, 50 is a lot) 
ops.lam = 10;  

% splitting a cluster at the end requires at least this much isolation for each sub-cluster (max = 1)
ops.AUCsplit = 0.9; 

% minimum spike rate (Hz), if a cluster falls below this for too long it gets removed
ops.minFR = 1/50; 

% number of samples to average over (annealed from first to second value) 
ops.momentum = [20 400]; 

% spatial constant in um for computing residual variance of spike
ops.sigmaMask = 30; 

% threshold crossings for pre-clustering (in PCA projection space)
ops.ThPre = 8; 

% Time range to examine
ops.trange = [0 Inf]; % time range to sort

% options for determining PCs
%%% danger, changing these settings can lead to fatal errors &&&
ops.spkTh           = -6;      % spike threshold in standard deviations (-6)
ops.reorder         = 1;       % whether to reorder batches for drift correction. 
ops.nskip           = 25;  % how many batches to skip for determining spike PCs

ops.GPU                 = 1; % has to be 1, no CPU version yet, sorry
% ops.Nfilt               = 1024; % max number of clusters
ops.nfilt_factor        = 4; % max number of clusters per good channel (even temporary ones)
ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection
ops.NT                  = 64*1024+ ops.ntbuff; % must be multiple of 32 + ntbuff. This is the batch size (try decreasing if out of memory). 
ops.whiteningRange      = 32; % number of channels to use for whitening each channel
ops.nSkipCov            = 25; % compute whitening matrix from every N-th batch
ops.scaleproc           = 200;   % int16 scaling of whitened data
ops.nPCs                = 3; % how many PCs to project the spikes into
ops.useRAM              = 0; % not yet available

end


function rez = runKilosort(channelData, recPath, ops)

% Things I don't think I need
    % rootH = path;
    % pathToYourConfigFile = 'D:\GitHub\KiloSort2\configFiles'; % take from Github folder and put it somewhere else (together with the master_file)
    % chanMapFile = 'neuropixPhase3A_kilosortChanMap.mat';
    % ops.chanMap = fullfile(path, 'chanMap.mat');
  
   
    %% Algorithim is run here
    fprintf('Looking for data inside %s \n', recPath)

    % is there a channel map file in this folder?
    fs = dir(fullfile(recPath, 'chan*.mat'));
    if ~isempty(fs)
        ops.chanMap = fullfile(recPath, fs(1).name);
    end

    % find the binary file
    ops.fbinary = fullfile(recPath, channelData.name);

    % preprocess data to create temp_wh.dat
    rez = preprocessDataSub(ops);

    % time-reordering as a function of drift
    rez = clusterSingleBatches(rez);

    % saving here is a good idea, because the rest can be resumed after loading rez
    save(fullfile(ops.resultsDir, 'rez.mat'), 'rez', '-v7.3');

    % main tracking and template matching algorithm
    rez = learnAndSolve8b(rez);

    % final merges
    rez = find_merges(rez, 1);

    % final splits by SVD
    rez = splitAllClusters(rez, 1);

    % final splits by amplitudes
    rez = splitAllClusters(rez, 0);

    % decide on cutoff
    rez = set_cutoff(rez);

    fprintf('found %d good units \n', sum(rez.good>0))

    % write to Phy
    fprintf('Saving results to Phy  \n')
    rezToPhy(rez, ops.resultsDir);

    %% if you want to save the results to a Matlab file...

    % discard features in final rez file (too slow to save)
    rez.cProj = [];
    rez.cProjPC = [];

    % final time sorting of spikes, for apps that use st3 directly
    [~, isort]   = sortrows(rez.st3);
    rez.st3      = rez.st3(isort, :);

    % save final results as rez2
    fprintf('Saving final results in rez2  \n')
    fname = fullfile(ops.resultsDir, 'rez2.mat');
    save(fname, 'rez', '-v7.3');
    
    %% Clear the working directory
    
    delete(ops.fproc); % deletes temp whitening matrix
    rmdir([recPath 'Kilosort WD']); % deletes working directory 
    

end
