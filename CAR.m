function CAR(varargin)
% Subtracts median of each channel, then subtracts median of each time
% point and can also high-pass filte
% Does so in chunks, users buffers to avoid artefacts at edges
% Uses the GPU to do this quickly
% Can be provided with noisy periods to zero out
% Can create an anti-aliased filtered downsampled LFP file


%% Parse inputs
p = inputParser; % Create object of class 'inputParser'

addRequired(p, 'inPath', @ischar);
addParameter(p, 'outPath',[], @ischar);
addParameter(p, 'Combine', true, @islogical);

addParameter(p, 'badChans', [], @isnumeric);

addParameter(p, 'RemoveNoise',true,@islogical);
addParameter(p, 'NoiseEvents', [], @isstruct);
addParameter(p, 'NoiseFile', [], @ischar);

addParameter(p, 'Filter', false, @islogical);
addParameter(p, 'LoFreq', 150, @isnumeric); % Filter Frequency 0 means low pass
addParameter(p, 'HiFreq', 0, @isnumeric); % Filter Frequency 0 means high pass
% Rec parameters 
addParameter(p, 'Header',[], @isstruct);
addParameter(p, 'sRate',[], @isnumeric);
addParameter(p, 'numChans',[], @isnumeric);

addParameter(p, 'chunkSize',2^20, @isnumeric);
addParameter(p, 'bufferSize',2^10, @isnumeric);

addParameter(p, 'LFP', false, @islogical);
addParameter(p, 'LFPFreq', 2500, @isnumeric);

parse(p, varargin{:});

inPath   = p.Results.inPath;
outPath  = p.Results.outPath;
combine  = p.Results.Combine;
badChans = p.Results.badChans;

rmNoise     = p.Results.RemoveNoise;
noiseEvents = p.Results.NoiseEvents;
noiseFile   = p.Results.NoiseFile;

runFilter   = p.Results.Filter;
loF      = p.Results.LoFreq;
hiF      = p.Results.HiFreq;

header   = p.Results.Header;
sRate    = p.Results.sRate;
numChans = p.Results.numChans;

chunkSize  = p.Results.chunkSize;
bufferSize = p.Results.bufferSize;

LFP        = p.Results.LFP;
lfpFreq    = p.Results.LFPFreq;

%% First thing we need is the number of channels
if isempty(numChans)
    if isempty(header)
        error('Need to specify the number of channels...');
    else
        try
            numChans = length(header.amplifier_channels);
        catch
            [header, ~, ~] = ...
            uigetfile('*.rhd', 'Select an RHD2000 Header File', 'MultiSelect', 'off');
            numChans = length(header.amplifier_channels);
        end
    end
end

% Also need sample rate if we're going to filter things....
if isempty(sRate) && runFilter
    if isempty(header)
        error('Need to specify the sample rate if filtering data...');
    else
        try
            numChans = length(header.amplifier_channels);
        catch
            [header, ~, ~] = ...
            uigetfile('*.rhd', 'Select an RHD2000 Header File', 'MultiSelect', 'off');
            numChans = length(header.amplifier_channels);
        end
    end
end


%% Look for noise events
if rmNoise
    if isempty(noiseEvents)
        if ~isempty(noiseFile)
            noiseEvents = loadNoiseEvents(noiseFile,sRate);
        else
            rmNoise = false;
        end
    end
end
    
%% Channels to ignore
if isempty(badChans)
    goodChans = true(1,numChans);
    connected = ones(size(goodChans));
else
    goodChans = ~badChans;
    connected = ones(size(goodChans));
end

%% Check files

fileDataStruct = dir(inPath);

numSamples  = fileDataStruct.bytes/numChans/2; % samples = bytes/channels/2 (2 bits per int16 sample)
numChunks   = ceil(numSamples./chunkSize);

if isempty(outPath)
    if runFilter
        outPath = [amplifierDataStruct.folder filesep ...
                      amplifierDataStruct.name(1:end-4) '_CAR_HP.dat'];
    else
        outPath = [amplifierDataStruct.folder filesep ...
                      amplifierDataStruct.name(1:end-4) '_CAR.dat'];
    end
end

if exist(outPath,"file") && ~combine
    error('Outputfile exists, but not set to concatenate files... Specify a different path');
end
    
fid    = fopen(inPath,'r');
fidOut = fopen(outPath,'a');

% Similar file checks for LFP data
if LFP
    if isempty(outPath)
        lfpPath = [amplifierDataStruct.folder filesep 'LFP.dat'];
    else
        lfpPath = [fileparts(outPath) filesep 'LFP.dat'];
    end


    if exist(lfpPath,"file") && ~combine
        error('LFP Outputfile exists, but not set to concatenate files... Specify a different path');
    end
    lfp_fid = fopen(lfpPath,'a');   

    % Calculate ratios
    downRatio = sRate / lfpFreq;
end

amplifierMap = memmapfile(inPath,...
'Format', {
'int16', [numChans numSamples], 'data'
});

disp(['Running common average referencing on ' inPath]);

%% Loop through the chunks
progress = 1;
for chunkI = 1:numChunks
    tic
    % Progress Counter
    if floor((chunkI/numChunks)*10) == progress
        fprintf('%d%',progress*10)
        fprintf('\n');
        progress = progress + 1;
    else
        fprintf('.')
    end
        
    if chunkI == 1
        startPoint = 1;
        endPoint   = chunkSize+bufferSize;
        chunk = amplifierMap.Data.data(:,1:chunkSize+bufferSize);
        chunk = [zeros(numChans,bufferSize,'int16') chunk];
    elseif chunkI == numChunks
        startPoint = (chunkSize * (chunkI-1)) + 1 - bufferSize;
        endPoint   = numSamples;
        chunk      =  amplifierMap.Data.data(:,...
            chunkSize * (chunkI-1) + 1 - bufferSize : numSamples);
        lastChunkSize = size(chunk,2);
        if lastChunkSize < chunkSize + 2 * bufferSize
            chunk = [chunk zeros(numChans, ...
            (chunkSize + 2 * bufferSize) - lastChunkSize,'int16')];
        end
    elseif (chunkSize*chunkI  + bufferSize >  length(amplifierMap.Data.data))
        startPoint = (chunkSize * (chunkI-1)) + 1 - bufferSize;
        endPoint   = numSamples;
        chunk      =  amplifierMap.Data.data(:,...
            chunkSize * (chunkI-1) + 1 - bufferSize : numSamples);
        lastChunkSize = size(chunk,2);
        if lastChunkSize < chunkSize + 2 * bufferSize
            chunk = [chunk zeros(numChans, ...
            (chunkSize + 2 * bufferSize) - lastChunkSize,'int16')];
        end
    else        
        chunk = amplifierMap.Data.data(:,...
            chunkSize * (chunkI-1) + 1 - bufferSize : ...
             chunkSize*chunkI  + bufferSize);
        startPoint = (chunkSize * (chunkI-1)) + 1 - bufferSize;
        endPoint   = chunkSize * (chunkI) + bufferSize;
    end
              
    %% Send data to GPU
    % Using GPU to common average reference and baseline (subtract per channel mean)
    dataGPU = gpuArray(chunk); % move int16 data to GPU
    dataGPU = dataGPU';
    dataGPU = single(dataGPU); % convert to float32 so GPU operations are fast

    %% Extract LFP
    if LFP
       % We need to first filter the data
       % Using an 8th order Chebyshev Type I lowpass filter with cutoff 
       % frequency .8*(Fs/2)/R (as used by decimate function)              
        [b,a] = cheby1(8, .05, .8/downRatio);
        % 8th order, .05 db ripple bassband 0.8 

       % next four lines should be equivalent to filtfilt (which cannot be used because it requires float64)
        dataLFP = filter(b, a, dataGPU); % causal forward filter
        dataLFP = flipud(dataLFP); % reverse time
        dataLFP = filter(b, a, dataLFP); % causal forward filter again
        dataLFP = flipud(dataLFP); % reverse time back

        datLFP  = gather(int16(dataLFP))';
        %% Write out the data
        if chunkI == numChunks 
            fwrite(lfp_fid,datLFP(:,bufferSize+1:downRatio:lastChunkSize),'int16');   
        else    
            fwrite(lfp_fid,datLFP(:,bufferSize+1:downRatio:end-bufferSize),'int16');    
        end

    end

    %% Test here for if this batch is in noise period
    if rmNoise == true
        possibleNoise = find(startPoint <= [noiseEvents.end_sample]);
        confirmedNoise = possibleNoise( endPoint >= [noiseEvents(possibleNoise).start_sample] );

        if ~isempty(confirmedNoise)
            for j = 1:length(confirmedNoise)                
                channels = intersect(find(goodChans),...
                noiseEvents(confirmedNoise(j)).channels);
                samples = startPoint:endPoint;
                blank = samples >= noiseEvents(confirmedNoise(j)).start_sample ...
                    & samples <= noiseEvents(confirmedNoise(j)).end_sample;
                if chunkI == 1
                    blank = [zeros(1,bufferSize) blank];
                end
                dataGPU(blank,channels) = 0;
            end
        end
    end
    
    %% Baseline
    % subtract the mean from each channel
    dataGPU = dataGPU - mean(dataGPU, 1); % subtract mean of each channel
   
    %% Re-reference
    % CAR, common average referencing by median - Old Method
    % dataGPU = dataGPU - median(dataGPU(:,goodChans), 2); % subtract median across channels
    
    % CAR, common average referencing by 64 channel batches - accounts for
    % some problems with headstages dropping out
    
    % if the number of channels is not divisible by 64 just process them all at once
    if mod(numChans,64) ~= 0 
        subGoodChans = connected(chans);
        if isempty(subGoodChans)
            continue
        else
            dataGPU(:,chans) = dataGPU(:,chans) - median(dataGPU(:,subGoodChans), 2); % subtract median across channels
        end
    else
        for j = 1:ceil(length(connected)./64)
            chans = ((j-1)*64)+1:j*64;
            subGoodChans = chans(connected(chans));
            if isempty(subGoodChans)
                continue
            else
                dataGPU(:,chans) = dataGPU(:,chans) - median(dataGPU(:,subGoodChans), 2); % subtract median across channels
            end
        end
    end
     
     %% Filter
    if runFilter
        [b1, a1] = butter(3, loFreq/sRate*2, 'high'); % the default is to only do high-pass filtering at 150Hz

        % next four lines should be equivalent to filtfilt (which cannot be used because it requires float64)
        dataGPU = filter(b1, a1, dataGPU); % causal forward filter
        dataGPU = flipud(dataGPU); % reverse time
        dataGPU = filter(b1, a1, dataGPU); % causal forward filter again
        dataGPU = flipud(dataGPU); % reverse time back
    end

     datcpu  = gather(int16(dataGPU))';

    %% Write out the data
    if chunkI == numChunks 
        fwrite(fidOut,datcpu(:,bufferSize+1:lastChunkSize),'int16');   
    else    
        fwrite(fidOut,datcpu(:,bufferSize+1:end-bufferSize),'int16');    
    end

end

fclose(fid);
fclose(fidOut);