function combineIntanEventFiles(eventPath1, eventPath2, outputPath, timestamps)

if nargin < 4
    timestamps = true;
end

chunkSize  = 2^18;

file1 = dir(eventPath1);
file2 = dir(eventPath2);

numSamples1  = file1.bytes/2; % samples = (2 bits per uint16 sample)
numChunks1   = ceil(numSamples1./chunkSize);

numSamples2  = file2.bytes/2; % samples = (2 bits per uint16 sample)
numChunks2   = ceil(numSamples2./chunkSize);

fid    = fopen(eventPath1,'r');
foutID = fopen(outputPath,'w');

% memory map file 1

dataMap = memmapfile(eventPath1,...
'Format', {
'uint16', [1 numSamples1], 'data'
});

for chunkI = 1:numChunks1
    if chunkI == numChunks1
        tempData = dataMap.Data.data(1 + chunkSize * (chunkI - 1): end);
    else
        tempData = dataMap.Data.data(1 + (chunkSize * (chunkI - 1)) : ...
                                (chunkSize * chunkI) );
    end
    fwrite(foutID,tempData,'uint16');
end

fclose(fid);
fclose(foutID);
clear dataMap

fid    = fopen(eventPath2,'r');
foutID = fopen(outputPath,'a');
dataMap = memmapfile(eventPath2,...
'Format', {
'uint16', [1 numSamples2], 'data'
});

for chunkI = 1:numChunks2
    if chunkI == numChunks2
        tempData = dataMap.Data.data(1 + chunkSize * (chunkI - 1): end);
    else
        tempData = dataMap.Data.data(1 + (chunkSize * (chunkI - 1)) : ...
                                (chunkSize * chunkI) );
    end
    fwrite(foutID,tempData,'uint16');
end

fclose(fid);
fclose(foutID);
clear dataMap;

% Generate an equivalent timestamp file
if timestamps
    fid = fopen('time.dat','w');
    totalSamples = numSamples1 + numSamples2;
    t = 0:totalSamples;
    fwrite(fid,t,'int32');
    fclose(fid);
end

    
    