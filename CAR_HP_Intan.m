function filteredData = CAR_HP_Intan(intanHeaderPath, runFilter)
% Subtracts median of each channel, then subtracts median of each time
% point and also high-pass filters at 300 Hz
% Does so in chunks, users buffers to avoid artefacts at edges
%
% filename should be the complete path to an intan.rhd file
% The same directory should contain the 'amplifier.dat' file that is the
% raw data

%% File IO

if nargin < 2
    runFilter = true;
end
if nargin > 0
    [fileParts, ~] = strsplit(intanHeaderPath,filesep);
    file = fileParts{end};
    filepath = strjoin(fileParts(1:end-1) , filesep);
    filepath = [filepath filesep];
elseif nargin == 0
    [file, filepath, filterindex] = ...
    uigetfile('*.rhd', 'Select an RHD2000 Header File', 'MultiSelect', 'off');
end

% Load Header Info
intanRec = intanHeader([filepath file]);

if ~exist([filepath 'amplifier.dat'])
    warning('Can''t find amplifier.dat file in header directory...')
    [amplifierFile, amplifierFilepath, filterindex] = ...
    uigetfile('*.dat', 'Select the recording .dat file', 'MultiSelect', 'off');
    amplifierDataStruct = dir([amplifierFilepath amplifierFile]);
else  
    amplifierDataStruct = dir([filepath 'amplifier.dat']);
end

%% Setup Parameters
% should make chunk size as big as possible so that the medians of the
% channels differ little from chunk to chunk.

loFreq    = 300;
hiFreq     = 0; % Zero means High-Pass filter
chunkSize  = 2^20;
bufferSize = 2^10;

numChannels = length(intanRec.amplifier_channels);
numSamples  = amplifierDataStruct.bytes/numChannels/2; % samples = bytes/channels/2 (2 bits per int16 sample)
sRate       = intanRec.frequency_parameters.amplifier_sample_rate;
numChunks   = ceil(numSamples./chunkSize);

filename = [amplifierDataStruct.folder filesep amplifierDataStruct.name];
if runFilter
    outFilename = [amplifierDataStruct.folder filesep ...
                  amplifierDataStruct.name(1:end-4) '_CAR_HP.dat'];
else
    outFilename = [amplifierDataStruct.folder filesep ...
                  amplifierDataStruct.name(1:end-4) '_CAR.dat'];
end
fid    = fopen(filename,'r');
fidOut = fopen(outFilename,'w');

amplifierMap = memmapfile(filename,...
'Format', {
'int16', [numChannels numSamples], 'data'
});

% filteredData = zeros(numChannels,numSamples,'int16');

%% Loop through the chunks
for chunkI = 1:numChunks
    tic     
    fprintf('Loading Chunk %d of %d... \n',chunkI,numChunks)
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
        
    
    %% Baseline, Rereference and Filter
    fprintf('Re-Referencing...\n')
    chunk = bsxfun(@minus, chunk, median(chunk,2)); % subtract median of each channel
    chunk = bsxfun(@minus, chunk, median(chunk,1)); % subtract median of each time point
      
    if runFilter
        fprintf('Filtering...\n')
        chunk = eegfilt(chunk,sRate, loFreq, hiFreq);
    end
    %% Write out the data
    
    if chunkI == numChunks 
        fwrite(fidOut,chunk(:,bufferSize+1:lastChunkSize),'int16');   
    else    
        fwrite(fidOut,chunk(:,bufferSize+1:end-bufferSize),'int16');    
    end
    % Optionally combine the data here

       % filteredData(:,startPoint:endPoint) = ...
       %    chunk(:, bufferSize+1:end-bufferSize);
toc
end

fclose(fid);
fclose(fidOut);
