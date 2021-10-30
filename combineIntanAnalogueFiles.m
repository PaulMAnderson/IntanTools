function combineIntanAnalogueFiles(fPath1, fPath2, header1, header2, outputPath)

assert(length(header1.board_adc_channels) == length(header2.board_adc_channels),....
    'Analogue channels don''t match');

numChans = length(header1.board_adc_channels);

chunkSize  = 2^18;

file1 = dir(fPath1);
file2 = dir(fPath2);

numSamples1  = file1.bytes/(numChans * 2); % samples = (2 bits per uint16 sample)
numChunks1   = ceil(numSamples1./chunkSize);

numSamples2  = file2.bytes/(numChans * 2); % samples = (2 bits per uint16 sample)
numChunks2   = ceil(numSamples2./chunkSize);

fid    = fopen(fPath1,'r');
foutID = fopen(outputPath,'w');

% memory map file 1

dataMap = memmapfile(fPath1,...
'Format', {
'uint16', [numChans numSamples1], 'data'
});

for chunkI = 1:numChunks1
    if chunkI == numChunks1
        tempData = dataMap.Data.data(:, 1 + chunkSize * (chunkI - 1): end);
    else
        tempData = dataMap.Data.data(:, 1 + (chunkSize * (chunkI - 1)) : ...
                                (chunkSize * chunkI) );
    end
    fwrite(foutID,tempData,'uint16');
end

fclose(fid);
fclose(foutID);
clear dataMap

fid    = fopen(fPath2,'r');
foutID = fopen(outputPath,'a');
dataMap = memmapfile(fPath2,...
'Format', {
'uint16', [numChans numSamples2], 'data'
});

for chunkI = 1:numChunks2
    if chunkI == numChunks2
        tempData = dataMap.Data.data(:,1 + chunkSize * (chunkI - 1): end);
    else
        tempData = dataMap.Data.data(:,1 + (chunkSize * (chunkI - 1)) : ...
                                (chunkSize * chunkI) );
    end
    fwrite(foutID,tempData,'uint16');
end

fclose(fid);
fclose(foutID);
clear dataMap;

    
    