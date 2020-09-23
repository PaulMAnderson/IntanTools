function filteredData = myFilter(data, sRate, lo, high)

% Function to quickly filter data in batches
% Lifted and modified from the kilosort pre-processing script

%% Quickly load data in the present folder for testin
tic
if exist('amplifier_CAR.dat','file')  && exist('info.rhd','file')
    intanRec = intanHeader([pwd filesep 'info.rhd']);
    dataFile = dir('amplifier_CAR.dat');
    numChans = length(intanRec.amplifier_channels);
elseif exist('amplifier.dat','file') && exist('info.rhd','file')
    intanRec = intanHeader([pwd filesep 'info.rhd']);
    numChans = length(intanRec.amplifier_channels);
    applyCARtoDat([pwd filesep 'amplifier.dat'], numChans);
    dataFile = dir('amplifier_CAR.dat');
end

sRate       = intanRec.frequency_parameters.amplifier_sample_rate;
num_samples = dataFile.bytes/(numChans * 2); % int16 = 2 bytes
fid         = fopen('amplifier_CAR.dat','r');
data        = fread(fid, [numChans , num_samples], '*int16'); 
data        = data  * 0.195; % convert to microvolts

lo          = 500;
high        = 0;
%%

% 1 - Get data size, calculate batch and buffer size
nChans      = size(data,1);
nTimepoints = size(data,2);
% Add some tests for if these numbers are sensible

batchSize  = 2^20;
bufferSize = 2^10;
nBatches   = floor(nTimepoints./batchSize);

filteredData = zeros(size(data));

for batchi = 1:nBatches
    if batchi == 1
        startPoint = 1;
        endPoint   = batchSize;
        batch = data(:,startPoint:endPoint+bufferSize);
        batch = [zeros(numChans,bufferSize) batch];
        
    elseif batchi == nBatches
        startPoint = nTimepoints - (batchSize - 1);
        endPoint   = nTimepoints;
        batch = data(:,startPoint-bufferSize:endPoint);
        lastBatchSize = size(batch,2);
        if lastBatchSize < batchSize + 2 * bufferSize
            batch = [zeros(numChans, ...
            (batchSize + 2 * bufferSize) - lastBatchSize) batch];
        end
    else 
        startPoint = (batchSize * batchi) + 1;
        endPoint   = batchSize * (batchi + 1);
        batch = data(:,startPoint-bufferSize:endPoint+bufferSize);
    end
    
    fprintf('Filtering Batch %d of %d... \n',batchi,nBatches)
    tempData     = eegfilt(batch,sRate, lo, high);
    %%
    filteredData(:,startPoint:endPoint) = ...
        tempData(:, bufferSize+1:end-bufferSize);
toc
end