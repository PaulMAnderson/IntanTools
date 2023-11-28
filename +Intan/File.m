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
                    self.Precision   = 0.000050354;
                    self.Unit        = 'V';
                    self.Impedances  = [header.board_adc_channels.electrode_impedance_magnitude];

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

                case 'digitalin.dat'
                    self.FileName    = 'digitalin.dat';
                    self.SignalType  = 'digital';
                    self.DataType    = 'uint16';
                    self.DataFormat  = '16 bit word x samples';
                    self.NumChannels = length(header.board_dig_in_channels);
                    self.Bytes       = fileStruct.bytes;
                    self.SampleRate  = header.frequency_parameters.board_dig_in_sample_rate;
                    self.Samples     = self.Bytes / (self.NumChannels * 2); %  % uint16 = 2 bytes
                    self.Length   = self.Samples/self.SampleRate;
                    self.Precision   = nan;
                    self.Unit        = 'Binary';
                    self.Impedances  = [header.board_dig_in_channels.electrode_impedance_magnitude];

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
            end
            self.FullPath = [filePath filesep self.FileName];
        end
    end
end
