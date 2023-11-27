function filterGPU(varargin)
% Takes a recData stuct (parseRecordingPath function) and will generate a
% new intan raw data file (amplifier.dat typically) with various filtering,
% downsampling, referencing applied
% INPUTS - Required
% recData - Struct generated with parseRecordingPath
% Reference - Referencing to apply, string: 'Common', 'Shank', or vector
%             containing channels to average and subtract
% RemoveNoise - looks for a .evt file that contains period with noise to
%               zero out, logical; default = true
% Filter   - Two element vector containing high-pass and low-pass cutoffs
%            for filtering, if an element is 0 it is skipped
% Downsample - Downsample the data, if logical true will aim for 1000Hz
%              output, if an integer > 1 will downsample by this factor
%              if filter is not provided will low-pass at new Nyquist freq
%              i.e.  Fs/2, 500Hz for 1KHz
% BadChans - vector of channels to exclude
% OutputChans - vector of channels to include - will not include any others
% FileName - output file name, if not provided will append suffix to
%            current name, if file exists will apend output data to the end


%% Parse inputs
p = inputParser;
addRequired(p, 'recData', @isstruct);
addParameter(p, 'Reference','Common');
addParameter(p, 'RemoveNoise',true, @islogical);
addParameter(p, 'Filter',[], @isnumeric);
addParameter(p, 'Downsample',0);
addParameter(p, 'BadChans',[], @isnumeric);
addParameter(p, 'OutputChans',[], @isnumeric);
addParameter(p, 'FileName',[]);

% Parsing inputs
parse(p,varargin{:})

recData     = p.Results.recData;
reference   = p.Results.Reference;
removeNoise = p.Results.RemoveNoise;
filtFreq    = p.Results.Filter;
downsample  = p.Results.Downsample;
badChans    = p.Results.BadChans;
outputChans = p.Results.OutputChans;
fileName    = p.Results.FileName;


%% File IO

header = recData.Header;
rawDataStruct = recData.AmplifierFile;
inFile = dir2path(rawDataStruct);
numChannels = length(header.amplifier_channels);
numSamples  = rawDataStruct.bytes/numChannels/2; % samples = bytes/channels/2 (2 bits per int16 sample)
sRate       = header.frequency_parameters.amplifier_sample_rate;

% Get bad or unconnected channels - exclude from the referecning
% calculations but will still include in ouput
badChans = unique([badChans find(~recData.ChanMapStruct.connected)]);



%% Look for noise events
if removeNoise == true
    noiseEventFile = recData.EvtPath;
    if ~isempty(noiseEventFile)
        rez.ops.fs = intanHeader.frequency_parameters.amplifier_sample_rate;
        rez.ops.noiseEventFile = recData.EvtPath;
        noisePeriods = loadNoiseEvents(rez);
        removeNoise = true;
    else
        removeNoise = false;
    end
end

%% Parse referencing
if reference == 0
    refApply = [];
    refChans = [];
    reference = [];
else
    refApply = {1:numChannels};
end
if isstring(reference) || ischar(reference)
    switch lower(reference)
        case 'common'
            if numChannels > 64 && rem(numChannels,64) == 0
                % Do in blocks of 64 for high channel count
                % This is because headstage failures and noise issues will
                % effect blocks of 64 channels at a time
                for j = 1:numChannels./64
                    currentChans = 1:64 + (j-1)*64;
                    refApply{j} = currentChans;
                    refChans{j} = currentChans(~ismember(currentChans,badChans));
                end
            else
                currentChans = 1:numChannels;
                refChans{1} = currentChans(~ismember(currentChans,badChans));
            end
        case 'shank'
            [refChans, refApply] = getPerShankRef(recData.ChanMapStruct);
    end
elseif iscell(reference)
    refChans = reference(1);
    refChans = reference(2);
elseif isnumeric(reference)
    refChans = {reference};
else
    refChans = [];
    refApply = [];
end

%% Parse filtering
if isempty(filtFreq)
    runFilter = false;
    loFreq = 0;
    hiFreq = 0;
else
    loFreq     = filtFreq(1);
    hiFreq     = filtFreq(2); % Zero means High-Pass filter
    runFilter = true;
end

%% Parse downsampling
if downsample == 0
    dsData = false;
elseif downsample == 1
    dsData = true;
    downSampleFactor = sRate ./ 1000;
    if rem(downSampleFactor,1) ~= 0
        downSampleFactor = round(downSampleFactor);
        warning(['Sampling frequency doesn''t smooothly divide to 1000,'
            'will approximate at ' num2str(downSampleFactor)]);
    end
    newSRate = sRate./downSampleFactor;
    runFilter = true;
    if hiFreq == 0
        hiFreq = newSRate ./2;
    end
else
    dsData = true;
    downSampleFactor = downsample;
    downSampleFactor = round(downSampleFactor);
    warning(['Downsample factor must be whole number,'
        'will approximate at ' num2str(downSampleFactor)]);
    newSRate = sRate./downSampleFactor;
    runFilter = true;
    if hiFreq == 0
        hiFreq = newSRate ./2;
    end
end

%% Parse outputChans
% If we are restricting the channels and referencing then we need to keep
% these channels so we can calculate the reference
if ~isempty(outputChans)
    if ~isempty(refApply)
        error('Re-refrencing and outputing only selected channels is not implemented...');
    else
        processChans = outputChans;
        saveChans    = outputChans;       
        nProcessChans = length(processChans);
        nSaveChans    = length(saveChans);
    end
else
    processChans = 1:numChannels;
    saveChans    = 1:numChannels;
    nProcessChans = length(processChans);
    nSaveChans    = length(saveChans);
end

    

%% Output filename
if isempty(fileName)
    outFile = fileName(1:end-4);
    outFile = [outFile '.filt'];
else
    outFile = fileName;
end

if exist(outFile,'file')
    fidOut = fopen(outFile,'a');
else
    fidOut = fopen(outFile,'w');
end

amplifierMap = memmapfile(inFile,...
    'Format', {
    'int16', [numChannels numSamples], 'data'
    });

%% Calculate chunks
chunkSize  = 2^20;
bufferSize = 2^10;
numChunks   = ceil(numSamples./chunkSize);

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
        chunk = amplifierMap.Data.data(processChans,1:chunkSize+bufferSize);
        chunk = [zeros(nProcessChans, bufferSize,'int16') chunk];
    elseif chunkI == numChunks
        startPoint = (chunkSize * (chunkI-1)) + 1 - bufferSize;
        endPoint   = numSamples;
        chunk      =  amplifierMap.Data.data(processChans,...
            chunkSize * (chunkI-1) + 1 - bufferSize : numSamples);
        lastChunkSize = size(chunk,2);
        if lastChunkSize < chunkSize + 2 * bufferSize
            chunk = [chunk zeros(nProcessChans, ...
                (chunkSize + 2 * bufferSize) - lastChunkSize,'int16')];
        end
    elseif (chunkSize*chunkI  + bufferSize >  length(amplifierMap.Data.data))
        startPoint = (chunkSize * (chunkI-1)) + 1 - bufferSize;
        endPoint   = numSamples;
        chunk      =  amplifierMap.Data.data(processChans,...
            chunkSize * (chunkI-1) + 1 - bufferSize : numSamples);
        lastChunkSize = size(chunk,2);
        if lastChunkSize < chunkSize + 2 * bufferSize
            chunk = [chunk zeros(nProcessChans, ...
                (chunkSize + 2 * bufferSize) - lastChunkSize,'int16')];
        end
    else
        chunk = amplifierMap.Data.data(processChans,...
            chunkSize * (chunkI-1) + 1 - bufferSize : ...
            chunkSize*chunkI  + bufferSize);
        startPoint = (chunkSize * (chunkI-1)) + 1 - bufferSize;
        endPoint   = chunkSize * (chunkI) + bufferSize;
    end

    %% Test here for if this batch is in noise period
    if removeNoise == true
        possibleNoise = find(startPoint <= noisePeriods.endSample);
        confirmedNoise = possibleNoise( endPoint >= noisePeriods.startSample(possibleNoise) );
        if ~isempty(confirmedNoise)
            for j = 1:length(confirmedNoise)
                channels = goodChans(dsearchn(goodChans(:),...
                    (noisePeriods.startChannel(confirmedNoise(j)):...
                    noisePeriods.endChannel(confirmedNoise(j)))'));
                samples = startPoint:endPoint;
                blank = samples >= noisePeriods.startSample(confirmedNoise(j))...
                    & samples <= noisePeriods.endSample(confirmedNoise(j));
                chunk(channels,blank) = 0;
            end
        end
    end

    %% Move data to GPU
    dataGPU = gpuArray(chunk); % move int16 data to GPU
    dataGPU = dataGPU';
    dataGPU = single(dataGPU); % convert to float32 so GPU operations are fast

    %% Baseline
    % subtract the mean from each channel
    dataGPU = dataGPU - mean(dataGPU, 1); % subtract mean of each channel

    %% Re-reference
    % Loop through the refApply channels and apply the median of the refChans
    for j = 1:length(refApply)
        currentChans = refApply{j};
        currentRef   = refChans{j};
        dataGPU(:,currentChans) = dataGPU(:,currentChans) ...
            - median(dataGPU(:,currentRef), 2); % subtract median across channels
    end

    %% Filter
    if runFilter
        if loFreq ~= 0 && hiFreq ~= 0
            [b1, a1] = butter(7, [loFreq/sRate*2 hiFreq/sRate*2], 'stop');
        end
        if loFreq ~= 0 && hiFreq == 0
            [b1, a1] = butter(7, loFreq/sRate*2, 'high');
        end
        if loFreq == 0 && hiFreq ~= 0
            [b1, a1] = butter(7, hiFreq/sRate*2, 'low');
        end
        % next four lines should be equivalent to filtfilt (which cannot be used because it requires float64)
        dataGPU = filter(b1, a1, dataGPU); % causal forward filter
        dataGPU = flipud(dataGPU); % reverse time
        dataGPU = filter(b1, a1, dataGPU); % causal forward filter again
        dataGPU = flipud(dataGPU); % reverse time back
    end

    %% Gather data
    datCPU  = gather(int16(dataGPU))';

    %% Downsample
    if dsData
        if chunkI == numChunks
            outData = datCPU(saveChans,bufferSize+1:downSampleFactor:lastChunkSize);
        else
            outData = datCPU(saveChans,bufferSize+1:downSampleFactor:end-bufferSize);
        end
    else
        if chunkI == numChunks
            outData = datCPU(saveChans,bufferSize+1:lastChunkSize);
        else
            outData = datCPU(saveChans,bufferSize+1:end-bufferSize);
        end
    end

    %% Write out the data
    fwrite(fidOut,outData,'int16');
end
fclose(fidOut);