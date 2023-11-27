function combineIntanFiles(varargin)
% Combines Intan Recording files
% Give it an inpath and and outpath and if the outpath already exists it
% will concatenate the files
% Doesn't have the ability to check if files match so that needs to be done
% before sending files to this funciton

%% Parse inputs
p = inputParser; % Create object of class 'inputParser'

addParameter(p, 'inPath', @ischar);
addParameter(p, 'outPath', @ischar);
addParameter(p, 'fileType',@ischar);
addParameter(p, 'numChans',@isnumeric);
addParameter(p, 'sRate',@isnumeric);
addParameter(p, 'chunkSize',2^20, @isnumeric);

parse(p, varargin{:});

inPath     = p.Results.inPath; 
outPath    = p.Results.outPath;
fileType   = validatestring(p.Results.fileType,...
            {'analog','digital','header','amplifier','time'});
numChans   = p.Results.numChans;
sRate      = p.Results.sRate;
chunkSize  = p.Results.chunkSize;

%%

assert(exist(inPath,'file'),'Can''t find input file...');

combine = exist(outPath,'file');

if ~combine % If there isn't already a file at the output just copy the file   
    [~,inFile]   = fileparts(inPath);
    disp(['Copying file ' inFile '...']);
    copyfile(inPath,outPath);
else
    % Check that file names match... if they don't issue a warning put proceed
    [~,inFile]   = fileparts(inPath);
    [~, outFile] = fileparts(outPath);

    if inFile ~= outFile
        warning('Different input and output filenames... Are you sure you combined the correct files?')
    end

    switch fileType
        case 'header'
            % Load the two headers and check they match
            inHeader  = loadIntanHeader(inPath);
            outHeader = loadIntanHeader(outPath);

            % They can differ in only digital channels
            % If they do thats fine just replace the 
            inDig  = length(inHeader.board_dig_in_channels);
            outDig = length(outHeader.board_dig_in_channels);

            if inDig > outDig 
                delete(outPath);
                copyfile(inPath,outPath);
            end

        case 'amplifier'
            % Memory map file
            inData  = dir(inPath);
            inBytes = inData.bytes;
            nSamples = inBytes / (numChans * 2); % uint16 = 2 bytes
            numChunks   = ceil(nSamples./chunkSize);
            dataMap = memmapfile(inPath,'Format', ...
                        {'int16', [numChans nSamples], 'data'} ...
                    );

            fid = fopen(outPath,'a');
            try                
                for chunkI = 1:numChunks
                    if chunkI == numChunks
                        tempData = dataMap.Data.data(:, 1 + chunkSize * (chunkI - 1): end);
                    else
                        tempData = dataMap.Data.data(:, 1 + (chunkSize * (chunkI - 1)) : ...
                            (chunkSize * chunkI) );
                    end
                    fwrite(fid,tempData,'int16');
                end
                fclose(fid);
            catch
                warning('Error occured, written file may be incomplete');
                fclose(fid);
            end
            clear dataMap tempData

        case 'analog'
            % Memory map file
            inData  = dir(inPath);
            inBytes = inData.bytes;
            nSamples = inBytes / (numChans * 2); % uint16 = 2 bytes
            numChunks   = ceil(nSamples./chunkSize);
            dataMap = memmapfile(inPath,'Format', ...
                        {'uint16', [numChans nSamples], 'data'} ...
                    );

            fid = fopen(outPath,'a');
            try                
                for chunkI = 1:numChunks
                    if chunkI == numChunks
                        tempData = dataMap.Data.data(:, 1 + chunkSize * (chunkI - 1): end);
                    else
                        tempData = dataMap.Data.data(:, 1 + (chunkSize * (chunkI - 1)) : ...
                            (chunkSize * chunkI) );
                    end
                    fwrite(fid,tempData,'uint16');
                end
                fclose(fid);
            catch
                warning('Error occured, written file may be incomplete');
                fclose(fid);
            end
            clear dataMap tempData

        case 'digital'
            % Memory map file
            inData  = dir(inPath);
            inBytes = inData.bytes;
            nSamples = inBytes / 2; % uint16 = 2 bytes
            numChunks   = ceil(nSamples./chunkSize);
            dataMap = memmapfile(inPath,'Format', ...
                {'uint16', [1 nSamples], 'data'} ...
                );

            fid = fopen(outPath,'a');
            try
                for chunkI = 1:numChunks
                    if chunkI == numChunks
                        tempData = dataMap.Data.data(:, 1 + chunkSize * (chunkI - 1): end);
                    else
                        tempData = dataMap.Data.data(:, 1 + (chunkSize * (chunkI - 1)) : ...
                            (chunkSize * chunkI) );
                    end
                    fwrite(fid,tempData,'uint16');
                end
                fclose(fid);
            catch
                warning('Error occured, written file may be incomplete');
                fclose(fid);
            end
            clear dataMap tempData

        case 'time'
            % Timestamps are int32 sequence from 0 to numSamples -1 
            % Easiest to just recreate
            outData    = dir(outPath);
            outSamples = outData.bytes / 4; % int32 = 4 bytes
            inData     = dir(inPath);
            inSamples  = inData.bytes / 4; % int32 = 4 bytes
    
            t = 0:inSamples+outSamples-1;
            fid = fopen(outPath,'w');            
            try
                fwrite(fid,t,'int32');
                fclose(fid);
            catch
                warning('Error occured, written file may be incomplete');
                fclose(fid);
            end            
    end
end






    
    