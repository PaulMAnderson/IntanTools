function medianTrace = CAR_HP_Intan(intanHeaderPath, runFilter)
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
filteredData = zeros(numChannels, numSamples,'int16');

%% Loop through the chunks

for chunkI = 1:numChunks
    tic     
    fprintf('Loading Chunk %d of %d... \n',chunkI,numChunks)
    if chunkI == 1
        startPoint = 1;
        endPoint   = chunkSize;
        chunk = fread(fid,[numChannels chunkSize+bufferSize],'*int16');
        chunk = [zeros(numChannels,bufferSize) chunk];
    elseif chunkI == numChunks
        startPoint = numSamples - (chunkSize - 1);
        endPoint   = numSamples;
        offset     = (chunkSize * numChannels * 2) ...
                   + (bufferSize * numChannels * 2);
        fseek(fid,-offset,'eof');
        chunk = fread(fid,[numChannels inf],'*int16');
        lastChunkSize = size(chunk,2);
        if lastChunkSize < chunkSize + 2 * bufferSize
            chunk = [chunk zeros(numChannels, ...
            (chunkSize + 2 * bufferSize) - lastChunkSize)];
        end
    else
%         offset = (((chunkSize * numChannels * 2) * (chunkI - 1)) + 1) ...
%                - (bufferSize * numChannels * 2);
%         fseek(fid,offset,'bof');
        offset = (bufferSize * numChannels * 2) * 2; % Go back 2 times the buffer length
        fseek(fid,-offset,'cof');
        chunk = fread(fid,[numChannels chunkSize+2*bufferSize],'*int16');
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
    
    fwrite(fidOut,chunk(:,bufferSize+1:end-bufferSize),'int16');    
    % Optionally combine the data here
%     filteredData(:,startPoint:endPoint) = ...
%         chunk(:, bufferSize+1:end-bufferSize);
toc
end

fclose(fid);
fclose(fidOut);
