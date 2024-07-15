% Object Class to handle interactions with Intan Files
% Is the superclass of Intan.Recording, not typically used by itself

classdef File
    properties
        FileName     % Name of File on Disk
        SignalType   % Type of File
        DataType     % Precision of individual data points
        DataFormat   % Layout of data
        NumChannels  % Number of Channels
        Bytes        % File size (in bytes)
        SampleRate   % Sample Rate of Amplifier Channels
        Samples      % Number of Samples of Amplifier Channels
        Length       % Length of Recording in Seconds
        Precision    % Range/precision Intan system: 0.195uV/bit i.e. data in microvolts = int16 * 0.195
        Unit         % Unit of converted data
        Impedances   % Impedance measurement of each channel (if present)
        FullPath     % Full path to file
        MemoryMap    % Memory map struct
    end

    methods
        function self = File(filePath,header) % Constructor

            if nargin == 0 || isempty(filePath)
                % If no directory is passed ask user
                [file, filePath, filterindex] = ...
                    uigetfile('*.dat', 'Select an Intan Data File', 'MultiSelect', 'off');
            end

            if nargin == 1 || isempty(header)
                % First try the existing filepath
                rootPath = fileparts(filePath);
                headerPath = [rootPath filesep 'info.rhd'];
                if ~exist(headerPath,'file')
                    [headerName, headerDir, ~] = ...
                        uigetfile('info.rhd', ...
                        'Select an Intan Header File', 'MultiSelect', 'off');
                    headerPath = [headerName filesep headerDir];
                end
                try
                    header = loadIntanHeader(headerPath);
                catch
                    warning('Can''t find header file, info will be limited');
                    header = [];
                end
            end

            self = self.processFile(filePath, header);

        end
        function self = processFile(self, filePath, header)
            self.FullPath = filePath;
            fileStruct = dir(filePath);
            switch fileStruct.name
                case 'info.rhd'
                    self.FileName    = 'info.rhd';
                    self.SignalType  = 'header';
                    self.DataType    = 'Multiple';
                    self.DataFormat  = '';
                    self.NumChannels = nan;
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = nan;
                    self.Samples     = nan;
                    self.Length      = nan;
                    self.Precision   = nan;
                    self.Unit        = '';
                    self.Impedances  = '';
                    self.MemoryMap   = '';
                    
                case 'amplifier.dat'
                    self.FileName    = 'amplifier.dat';
                    self.SignalType  = 'amplifier';
                    self.DataType    = 'int16';
                    self.DataFormat  = 'channels x samples';
                    self.NumChannels = length(header.amplifier_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.amplifier_sample_rate;
                    self.Samples     = self.Bytes / (self.NumChannels * 2); % int16 = 2 bytes
                    self.Length   = self.Samples/self.SampleRate;
                    self.Precision   = 0.195;
                    self.Unit        = 'uV';
                    self.Impedances  = [header.amplifier_channels.electrode_impedance_magnitude];
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [self.NumChannels self.Samples], ...
                                            'data'});

                case 'analogin.dat'
                    self.FileName    = 'analogin.dat';
                    self.SignalType  = 'analog';
                    self.DataType    = 'uint16';
                    self.DataFormat  = 'channels x samples';
                    self.NumChannels = length(header.board_adc_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.board_adc_sample_rate;
                    self.Samples     = self.Bytes / (self.NumChannels * 2); %  % uint16 = 2 bytes
                    self.Length   = self.Samples/self.SampleRate;
                    self.Precision   = @(x)(x - 32768) * 0.0003125;
                    self.Unit        = 'V';
                    self.Impedances  = [header.board_adc_channels.electrode_impedance_magnitude];
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [self.NumChannels self.Samples], ...
                                            'data'});

                case 'auxiliary.dat'
                    self.FileName    = 'auxiliary.dat';
                    self.SignalType  = 'other';
                    self.DataType    = 'uint16';
                    self.DataFormat  = 'channels x samples';
                    self.NumChannels = length(header.aux_input_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.aux_input_sample_rate;
                    self.Samples     = self.Bytes / (self.NumChannels * 2); %  % uint16 = 2 bytes
                    self.Length   = self.Samples/self.SampleRate;
                    self.Precision   = 0.0000374; % in uV
                    self.Unit        = 'V';
                    self.Impedances  = [header.aux_input_channels.electrode_impedance_magnitude];
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [self.NumChannels self.Samples], ...
                                            'data'});
                case 'digitalin.dat'
                    self.FileName    = 'digitalin.dat';
                    self.SignalType  = 'digital';
                    self.DataType    = 'uint16';
                    self.DataFormat  = '16 bit word x samples';
                    self.NumChannels = length(header.board_dig_in_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.board_dig_in_sample_rate;
                    self.Samples     = self.Bytes / 2; %  % uint16 = 2 bytes, all digital channels are a single 16 bit value
                    self.Length   = self.Samples/self.SampleRate;
                    self.Precision   = nan;
                    self.Unit        = 'Binary';
                    self.Impedances  = [header.board_dig_in_channels.electrode_impedance_magnitude];
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [1 self.Samples], ...
                                            'data'});

                case 'supply.dat'
                    self.FileName    = 'supply.dat';
                    self.SignalType  = 'other';
                    self.DataType    = 'uint16';
                    self.DataFormat  = '16 bit word x samples';
                    self.NumChannels = length(header.supply_voltage_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.supply_voltage_sample_rate;
                    self.Samples     = self.Bytes / (self.NumChannels * 2); %  % uint16 = 2 bytes
                    self.Length   = self.Samples/self.SampleRate;
                    self.Precision   = 0.0000748;
                    self.Unit        = 'V';
                    self.Impedances  = [header.supply_voltage_channels.electrode_impedance_magnitude];
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [1 self.Samples], ...
                                            'data'});
                case 'time.dat'
                    self.FileName    = 'time.dat';
                    self.SignalType  = 'time';
                    self.DataType    = 'int32';
                    self.DataFormat  = 'integer vector';
                    self.NumChannels = 1;
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.amplifier_sample_rate;
                    self.Samples     = self.Bytes / 4; %  % int32 = 4 bytes
                    self.Length   = self.Samples/self.SampleRate;
                    self.Precision   = '';
                    self.Unit        = 'Samples';
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [1 self.Samples], ...
                                            'data'});
            end           
        end

        function [data, timeStamps] = loadData(self, varargin)
             switch self.SignalType
                case 'header'
                    data = loadIntanHeader(self.FullPath);
                    return
             end
            
            %% Parse Inputs
            p = inputParser;
            p.addParameter('Channel',[],...
                @(x)validateattributes(x,{'numeric'},{'integer','>',0,'<=',self.NumChannels}));
            p.addParameter('StartTime',0,@isnumeric);
            p.addParameter('EndTime',[],@isnumeric);
            p.addParameter('StartSample',[],@(x)validateattributes(x,{'numeric'},{'integer'}));
            p.addParameter('EndSample',[],@(x)validateattributes(x,{'numeric'},{'integer'}));
            p.addParameter('Length',[],@isnumeric);
            p.addParameter('Timestamps','seconds',@ischar);
            % p.addParameter('Format','double',@ischar);

            p.parse(varargin{:});

            channel     = p.Results.Channel;
            startTime   = p.Results.StartTime;
            endTime     = p.Results.EndTime;
            startSample = p.Results.StartSample;
            endSample   = p.Results.EndSample;
            recLength   = p.Results.Length;
            timeFormat  = validatestring(p.Results.Timestamps,...
                                         {'Seconds','Samples'});
            % format      = validatestring(p.Results.Format,{'raw','single','double',...
            %     'int8', 'int16', 'int32', 'int64', ...
            %     'uint8', 'uint16', 'uint32', 'uint64'});
            % switch format
            %     case 'raw'
            %         format = self.DataFormat;
            % end

            % Calculate channels
            if isempty(channel) & ~strcmp(self.SignalType,'digital')
                channel = 1;
                disp('No channel specified, taking first channel only');
            end

            % Calculate Sample Start Idx
            if isempty(startSample)
                if isempty(startTime)
                    startIdx = 1;
                else
                    startIdx = round(startTime * self.SampleRate);                    
                end
            else
                startIdx = 1;
            end
            if startIdx < 1 
                startIdx = 1;
            end
            assert(startIdx < self.Samples,'Start Point is after end of data');

            % Calculate Sample End Idx
            if isempty(recLength)
                if isempty(endSample)
                    if isempty(endTime)
                        disp('No end point specified, taking 10 minutes of data');                        
                        endIdx = startIdx + (self.SampleRate * 60 * 60) - 1;
                    else
                        endIdx = floor(endTime * self.SampleRate);
                    end
                else
                    endIdx = endSample;
                end
            else
                endIdx = floor(startIdx + recLength*self.SampleRate - 1);
            end
            if endIdx > self.Samples
                endIdx = self.Samples;
                disp('End Point was after end of data, using last point in data...');
            end
            assert(endIdx ~= startIdx,'End Point and Start Point are the same');
            
            % Setup empty data 
            data = zeros(length(channel),length(startIdx:endIdx),'double');
                       
            %% Create Timestamps
            timeStamps = startIdx:endIdx;
            if strcmp(timeFormat,'Seconds')
                timeStamps = (timeStamps - 1) / self.SampleRate;
            end

            %% Load Data
            switch self.SignalType
                case 'amplifier'
                    data(:,:) = ...
                        self.Precision * ...
                        double(self.MemoryMap.Data.data(channel,startIdx:endIdx));
                case 'analog'
                    data(:,:) = self.Precision * ...
                        double(self.MemoryMap.Data.data(channel,startIdx:endIdx));
                case 'digital'                   
                    digIn = self.MemoryMap.Data.data(startIdx:endIdx);
                    % Parse each channel of the digital input data
                    data = zeros(self.NumChannels,length(digIn));
                    if isempty(channels) 
                        chanN = 0:numDigitalInChans-1;
                    else
                        chanN = channels - 1;
                    end
                    for chanI = chanN
                        data(chanI,:) = (bitand(digitalInWord, 2^chanID) > 0); % ch has a value of 0-15 here
                    end
                case 'time'
                    data = timeStamps;
            end
        end

        function combine(self, other, outPath, chunkSize)

            if nargin < 4 
                chunkSize = 2^20;
            end

            % Check files match
            assert(isequal(self.SignalType,other.SignalType),...
                'Non-matching signals');

            % check filename is filetype
            if isfolder(outPath)
                outPath = [outPath filesep self.FileName];
            elseif exist(outPath,'file')
                warning(['File: ' outPath ' already exists, skipping'])
                return
            end
                
            % Process depending on file type
            switch self.SignalType

                case 'header'
                    % Here we just keep one file

                    h1 = self.loadData;
                    h2 = other.loadData;
                    if length(h2.board_dig_in_channels) > ...
                       length(h1.board_dig_in_channels)
                        self = other;
                    end
                    copyfile(self.FullPath,outPath)                    

                case 'amplifier'
                    copyfile(self.FullPath,outPath);
                    % Memory map other file
                    numChunks = ceil(other.Samples./chunkSize);
                    dataMap = memmapfile(other.FullPath,'Format', ...
                        {'int16', [other.NumChannels other.Samples], 'data'} ...
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
                    copyfile(self.FullPath,outPath);
                    % Memory map other file
                    numChunks = ceil(other.Samples./chunkSize);
                    dataMap = memmapfile(other.FullPath,'Format', ...
                        {'uint16', [other.NumChannels other.Samples], 'data'} ...
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
                    copyfile(self.FullPath,outPath);
                    % Memory map other file
                    numChunks = ceil(other.Samples./chunkSize);
                    dataMap = memmapfile(other.FullPath,'Format', ...
                        {'uint16', [1 other.Samples], 'data'} ...
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
                    nSamples = self.Samples + other.Samples;
                    t = 0:nSamples-1;
                    fid = fopen(outPath,'w');
                    try
                        fwrite(fid,t,'int32');
                        fclose(fid);
                    catch
                        warning('Error occured, written file may be incomplete');
                        fclose(fid);
                    end

                case 'other'
                    disp(['Skipping ' self.FileName]);
            end

        end

    end
end
