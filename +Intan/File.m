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
        NumSamples      % Number of Samples of Amplifier Channels
        Length       % Length of Recording in Seconds
        Precision    % Range/precision Intan system: 0.195uV/bit i.e. data in microvolts = int16 * 0.195
        Offset       % Any offset needed to be applied to raw data
        Unit         % Unit of converted data
        Impedances   % Impedance measurement of each channel (if present)
        FullPath     % Full path to file
        MemoryMap    % Memory map struct
        % Data         % Memory mapped or actual data
        Scale        % Function to convert raw data to scaled 
    end

    properties (Hidden)
        cleanup
    end

    methods ( Access = 'public' )

        function self = File(filePath,header) % Constructor

            if nargin == 0 || isempty(filePath)
                % If no directory is passed ask user
                [file, filePath, filterindex] = ...
                    uigetfile('*.dat', 'Select an Intan Data File', 'MultiSelect', 'off');
            end

            if nargin == 1 || isempty(header)
                % First try the existing filepath                
                rootPath = fileparts(filePath);
                if isempty(rootPath)
                    temp = dir(filePath);
                    rootPath = temp.folder;
                end
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

            % self.cleanup = onCleanup(@()delete(self));

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
                    self.NumSamples     = nan;
                    self.Length      = nan;
                    self.Precision   = nan;
                    self.Offset      = nan;
                    self.Unit        = '';
                    self.Impedances  = '';
                    self.MemoryMap   = [];
                    % self.Data        = loadIntanHeader(self.FullPath);
                    self.Scale       = @(x)x;
                    
                case 'amplifier.dat'
                    self.FileName    = 'amplifier.dat';
                    self.SignalType  = 'amplifier';
                    self.DataType    = 'int16';
                    self.DataFormat  = 'channels x samples';
                    self.NumChannels = length(header.amplifier_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.amplifier_sample_rate;
                    self.NumSamples   = self.Bytes / (self.NumChannels * 2); % int16 = 2 bytes
                    self.Length      = self.NumSamples/self.SampleRate;
                    self.Precision   = 0.195;
                    self.Offset      = 0;
                    self.Unit        = 'uV';
                    self.Impedances  = [header.amplifier_channels.electrode_impedance_magnitude];
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [self.NumChannels self.NumSamples], ...
                                            'data'});
                    % self.Data        = self.MemoryMap.Data.data;
                    self.Scale       = @(x)double(x)*self.Precision + self.Offset;

                case 'analogin.dat'
                    self.FileName    = 'analogin.dat';
                    self.SignalType  = 'analog';
                    self.DataType    = 'uint16';
                    self.DataFormat  = 'channels x samples';
                    self.NumChannels = length(header.board_adc_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.board_adc_sample_rate;
                    self.NumSamples     = self.Bytes / (self.NumChannels * 2); %  % uint16 = 2 bytes
                    self.Length      = self.NumSamples/self.SampleRate;
                    self.Precision   = 0.0003125;
                    self.Offset      = -32768;
                    self.Unit        = 'V';
                    self.Impedances  = [header.board_adc_channels.electrode_impedance_magnitude];
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [self.NumChannels self.NumSamples], ...
                                            'data'});
                    % self.Data        = self.MemoryMap.Data.data;
                    self.Scale       = @(x)double(x)*self.Precision + self.Offset;

                case 'auxiliary.dat'
                    self.FileName    = 'auxiliary.dat';
                    self.SignalType  = 'other';
                    self.DataType    = 'uint16';
                    self.DataFormat  = 'channels x samples';
                    self.NumChannels = length(header.aux_input_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.aux_input_sample_rate;
                    self.NumSamples     = self.Bytes / (self.NumChannels * 2); %  % uint16 = 2 bytes
                    self.Length      = self.NumSamples/self.SampleRate;
                    self.Precision   = 0.0000374; % in uV
                    self.Offset      = 0;
                    self.Unit        = 'V';
                    self.Impedances  = [header.aux_input_channels.electrode_impedance_magnitude];
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [self.NumChannels self.NumSamples], ...
                                            'data'});
                    % self.Data        = self.MemoryMap.Data.data;
                    self.Scale       = @(x)double(x)*self.Precision + self.Offset;

                case 'digitalin.dat'
                    self.FileName    = 'digitalin.dat';
                    self.SignalType  = 'digital';
                    self.DataType    = 'uint16';
                    self.DataFormat  = '16 bit word x samples';
                    self.NumChannels = length(header.board_dig_in_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.board_dig_in_sample_rate;
                    self.NumSamples     = self.Bytes / 2; %  % uint16 = 2 bytes, all digital channels are a single 16 bit value
                    self.Length      = self.NumSamples/self.SampleRate;
                    self.Precision   = 1;
                    self.Offset      = 0;
                    self.Unit        = 'Binary';
                    self.Impedances  = [header.board_dig_in_channels.electrode_impedance_magnitude];
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [1 self.NumSamples], ...
                                            'data'});
                    % self.Data        = self.MemoryMap.Data.data;
                    self.Scale       = @(x)double(x)*self.Precision + self.Offset;

                case 'supply.dat'
                    self.FileName    = 'supply.dat';
                    self.SignalType  = 'other';
                    self.DataType    = 'uint16';
                    self.DataFormat  = '16 bit word x samples';
                    self.NumChannels = length(header.supply_voltage_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.supply_voltage_sample_rate;
                    self.NumSamples     = self.Bytes / (self.NumChannels * 2); %  % uint16 = 2 bytes
                    self.Length      = self.NumSamples/self.SampleRate;
                    self.Precision   = 0.0000748;
                    self.Offset      = 0;
                    self.Unit        = 'V';
                    self.Impedances  = [header.supply_voltage_channels.electrode_impedance_magnitude];
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [1 self.NumSamples], ...
                                            'data'});
                    % self.Data        = self.MemoryMap.Data.data;
                    self.Scale       = @(x)double(x)*self.Precision + self.Offset;

                case 'time.dat'
                    self.FileName    = 'time.dat';
                    self.SignalType  = 'time';
                    self.DataType    = 'int32';
                    self.DataFormat  = 'integer vector';
                    self.NumChannels = 1;
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.amplifier_sample_rate;
                    self.NumSamples     = self.Bytes / 4; %  % int32 = 4 bytes
                    self.Length      = self.NumSamples/self.SampleRate;
                    self.Precision   = 1;
                    self.Offset      = 0;
                    self.Unit        = 'Samples';
                    self.MemoryMap   =  memmapfile(self.FullPath, 'Format',...
                                            {self.DataType, ...
                                            [1 self.NumSamples], ...
                                            'data'});
                    % self.Data        = self.MemoryMap.Data.data;
                    self.Scale       = @(x)double(x)*self.Precision + self.Offset;
            end           
        end


        function [data, timestamps] = getTimes(self, varargin)
            % Function to enable easy access to samples with conversion to
            % volts and time indexing

            %% Input parsing
            p = inputParser; % Create object of class 'inputParser'

            chanCheck = @(x)validateattributes(x,{'numeric'},...
                {'integer','positive','<=',self.NumChannels});

            addParameter(p, 'startTime', 0, @isnumeric);
            addParameter(p, 'endTime', [], @isnumeric)
            addParameter(p, 'channels', 1, chanCheck)
            
            parse(p, varargin{:});
            
            startTime = p.Results.startTime;
            endTime   = p.Results.endTime;
            channels  = p.Results.channels;
            
            if isempty(channels)
                channels = 1;
            end

            if isempty(endTime)
                % Get 10 seconds of recording if not specified
                points = 10 - (1/self.SampleRate);
                endTime = startTime + points;
            end
            if endTime > self.Length - 1/self.SampleRate
                endTime = self.Length - 1/self.SampleRate;
            end

            % Slow method to get samples
            % ts = 0:1/self.SampleRate:self.Length-(1/self.SampleRate);
            % assert(length(ts) == self.NumSamples,'timestamp calculation error!');
            % ts = ts(:);
            % tIdx = dsearchn(ts,[startTime; endTime]);

            % Faster method
            % We add a single sample as we assume timepoint 1 = 0;
            tIdx(1) = floor(startTime * self.SampleRate + 1);
            tIdx(2) = floor(endTime * self.SampleRate + 1);

            data = self.getSamples('startSample',tIdx(1),'endSample',tIdx(2),...
                'channels',channels);
            
            if nargout > 1
                timestamps = tIdx(1)/self.SampleRate:1/self.SampleRate:tIdx(2)/self.SampleRate;
            end

        end

        function [data, timestamps] = getSamples(self, varargin)
            % Function to enable easy access to samples with conversion to
            % volts and simplified indexing

            % Input parsing
            p = inputParser; % Create object of class 'inputParser'

            intCheck = @(x)validateattributes(x,{'numeric'},{'integer','positive'});
            chanCheck = @(x)validateattributes(x,{'numeric'},...
                {'integer','positive','<=',self.NumChannels});

            addParameter(p, 'startSample', 1, intCheck);
            addParameter(p, 'endSample', [], intCheck);
            addParameter(p, 'channels', 1, chanCheck);
            addParameter(p, 'scale',true,@logical);
            
            parse(p, varargin{:});
            
            startSample = p.Results.startSample;
            endSample   = p.Results.endSample;
            channels    = p.Results.channels;
            scale       = p.Results.scale;
            
            if isempty(endSample)
                % Get 10 seconds of recording if not specified
                points = self.SampleRate * 10 - 1;
                endSample = startSample + points;
            end
            if endSample > self.NumSamples
                endSample = self.NumSamples;
            end

            % Get samples
            switch self.SignalType
                case 'digital'
                    digData = self.MemoryMap.Data.data(1,startSample:endSample);
                    data = zeros(length(channels),length(digData));
                    chanN = channels - 1;
                    for chanI = 1:length(chanN)
                        data(chanI,:) = (bitand(digData, 2^chanN(chanI)) > 0); % ch has a value of 0-15 here
                    end
                case 'header'
                    disp('No Samples in Header...')                    
                    data = loadIntanHeader(self.FullPath);
                    return
                otherwise
                    data = self.MemoryMap.Data.data(channels,startSample:endSample);
            end

            if scale 
                data = self.Scale(data);
            end            

            if nargout > 1
                timestamps = startSample/self.SampleRate:1/self.SampleRate:endSample/self.SampleRate;
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

    % methods ( Access = 'private' )
    %     function self = delete( self )
    %         disp('delete was called');
    %         self.Data = []; 
    %         self.MemoryMap = [];
    %     end
    % end % private methods

end