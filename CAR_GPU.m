function filteredData = CAR_GPU(intanHeaderPath, rawDataPath, chanMapPath, runFilter, outFilename)
% Subtracts median of each channel, then subtracts median of each time
% point and can also high-pass filters at 150 Hz
% Does so in chunks, users buffers to avoid artefacts at edges
% Uses the GPU to do this quickly
% filename should be the complete path to an intan.rhd file
% The same directory should contain the 'amplifier.dat' file 

%% File IO

if nargin < 5
    outputFile = [];
end

if nargin < 4
    runFilter = true;
end
if nargin > 0
    [headerPath, headerName, headerExt] = fileparts(intanHeaderPath);
    header = [headerName headerExt];
    headerPath = [headerPath filesep];
    
    [dataPath, dataName, dataExt] = fileparts(rawDataPath);
    data = [dataName dataExt];
    dataPath = [dataPath filesep];
elseif nargin == 0
    [file, headerPath, filterindex] = ...
    uigetfile('*.rhd', 'Select an RHD2000 Header File', 'MultiSelect', 'off');
end

% Load Header Info
intanRec = intanHeader([headerPath header]);

if ~exist(data, 'file')
    try 
        data = [headerPath 'amplifier.dat'];
        if ~exist(data, 'file')
            warning('Can''t find data .dat file in header directory...')
            [amplifierFile, amplifierFilepath, filterindex] = ...
            uigetfile('*.dat', 'Select the recording .dat file', 'MultiSelect', 'off');
            amplifierDataStruct = dir([amplifierFilepath amplifierFile]);
        else  
            amplifierDataStruct = dir([headerPath 'amplifier.dat']);
        end
    end
else
    amplifierDataStruct = dir([dataPath data]);
end

%% Setup Parameters
% should make chunk size as big as possible so that the medians of the
% channels differ little from chunk to chunk.

loFreq    = 150;
hiFreq     = 0; % Zero means High-Pass filter
chunkSize  = 2^18;
bufferSize = 2^10;

numChannels = length(intanRec.amplifier_channels);
if nargin < 2
    goodChans = 1:numChannels;
    % chanMap specifies 'bad' channels to leave out of referenceing etc.
else
   load(chanMapPath);
   goodChans = chanMap(connected);
end
% Should add more complex referenceing here - per electrode shank probably
% would use kcoords values for this 

numSamples  = amplifierDataStruct.bytes/numChannels/2; % samples = bytes/channels/2 (2 bits per int16 sample)
sRate       = intanRec.frequency_parameters.amplifier_sample_rate;
numChunks   = ceil(numSamples./chunkSize);

filename = [amplifierDataStruct.folder filesep amplifierDataStruct.name];
if isempty(outFilename)
    if runFilter
        outFilename = [amplifierDataStruct.folder filesep ...
                      amplifierDataStruct.name(1:end-4) '_CAR_HP.dat'];
    else
        outFilename = [amplifierDataStruct.folder filesep ...
                      amplifierDataStruct.name(1:end-4) '_CAR.dat'];
    end
    fid    = fopen(filename,'r');
    fidOut = fopen(outFilename,'w');
    else
    fid    = fopen(filename,'r');
    fidOut = fopen(outFilename,'a');
end

amplifierMap = memmapfile(filename,...
'Format', {
'int16', [numChannels numSamples], 'data'
});

% filteredData = zeros(numChannels,numSamples,'int16');


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
        endPoint   = chunkSize;
        chunk = amplifierMap.Data.data(:,1:chunkSize+bufferSize);
        chunk = [zeros(numChannels,bufferSize,'int16') chunk];
    elseif chunkI == numChunks
        startPoint = (chunkSize * (chunkI-1)) + 1;
        endPoint   = numSamples;
        chunk      =  amplifierMap.Data.data(:,...
            chunkSize * (chunkI-1) + 1 - bufferSize : numSamples);
        lastChunkSize = size(chunk,2);
        if lastChunkSize < chunkSize + 2 * bufferSize
            chunk = [chunk zeros(numChannels, ...
            (chunkSize + 2 * bufferSize) - lastChunkSize,'int16')];
        end
    else
        chunk = amplifierMap.Data.data(:,...
            chunkSize * (chunkI-1) + 1 - bufferSize : ...
             chunkSize*chunkI  + bufferSize);
        startPoint = (chunkSize * (chunkI-1)) + 1;
        endPoint   = chunkSize * (chunkI);
    end
        
    
    %% Baseline,

    % Use GPU to common average reference and baseline (subtract per channel mean)
    % buffer is portion of data in format timepoints by channels
    % chanMap are indices of the channels to be used

    dataGPU = gpuArray(chunk); % move int16 data to GPU
    dataGPU = dataGPU';
    dataGPU = single(dataGPU); % convert to float32 so GPU operations are fast

    % subtract the mean from each channel
    dataGPU = dataGPU - mean(dataGPU, 1); % subtract mean of each channel

    %% Re-reference
%     % CAR, common average referencing by median - Old Method
    dataGPU = dataGPU - median(dataGPU(:,goodChans), 2); % subtract median across channels

     % CAR, common average referencing by channel group
%      referenceGroups = unique(kcoords);
%      if any(strcmp('Reference',unique(SiteType))) % Check for special Reference channels
%          referenceGroups(referenceGroups>100) = [];
%          for refI = 1:length(referenceGroups)
%              refChans     = kcoords == referenceGroups(refI) + 100;
%              currentChans = (kcoords == referenceGroups(refI)) | refChans;
%             % Use the mean of the specific reference channels
%              dataGPU(:,currentChans) = dataGPU(:,currentChans) - mean(dataGPU(:,refChans),2);
% %            % Use the median of the whole group
% %            dataGPU(:,currentChans) = dataGPU(:,currentChans) - median(dataGPU(:,currentChans),2);
%          end
%      else
%          for refI = 1:length(referenceGroups)
%             currentChans = (kcoords == referenceGroups(refI));
%             % Use the median of the whole group
%             dataGPU(:,currentChans) = dataGPU(:,currentChans) - median(dataGPU(:,currentChans),2);
%          end
%      end
     
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