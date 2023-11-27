% Object Class to handle interactions with Intan Recordings
% So far only 1 file per recording type format is implemented

classdef IntanRec < IntanFile
   properties
      Header        % Matlab struct of header info
      SampleRate    % Sample Rate of Amplifier Channels
      Samples       % Number of Samples of Amplifier Channels
      RecLength     % Length of Recording in Seconds
      NumChannels   % Number of Amplifier Channels
      NumDigitalChannels % Number of Active Digital Channels (Always 16 bit data format)
      NumAnalogChannels  % Number of Active Analog Channels
      Impedances    % Impedance of Amplifier Channels
      Date          % Date of Recording
      Time          % Time of Recording
      Format        % Type of recording - One file per type is all that is implemented
      Files         % Struct array of 'dir' data of recording files
      
   end

   methods
       function self = IntanRec(filePath) % Constructor
            if nargin == 0 || isempty(filePath)% If no directory is passed ask user for a 
                [file, filePath, filterindex] = ...
                uigetfile('*.rhd', 'Select an RHD2000 Data File', 'MultiSelect', 'off');
            end
            % Load header
            self.Header = loadIntanHeader(filePath);
            self.SampleRate = header.frequency_parameters.amplifier_sample_rate;
            
            self.NumChannels = length(self.Header.amplifier_channels);
            self.NumDigitalChannels = length(self.Header.board_dig_in_channels);
            self.NumAnalogChannels = length(self.Header.board_adc_channels);

            self.Impedances = [self.Header.amplifier_channels.electrode_impedance_magnitude];

            self.Format = 'One File Per Signal Type';
                
            fileStruct = [dir([filePath filesep 'info.rhd']); ...
                          dir([filePath filesep '*.dat'])];
            self.Files = processFileStruct(fileStruct);

       end
       function fileStruct = processFileStruct(self, fileStruct)

           for fileI = 1:length(fileStruct)

               switch fileStruct(fileI).name
                   case 'info.rhd'
                       fileStruct(fileI).signalType = 'header';
                   case 'amplifier.dat'
                       fileStruct(fileI).signalType = 'amplifier';
                       fileStruct(fileI).dataType   = 'int16';
                       fileStruct(fileI).dataFormat = 'channels x samples';
                       fileStruct(fileI).sampleRate = self.header.frequency_parameters.amplifier_sample_rate;
                       fileStruct(fileI).numChannels  = length(header.amplifier_channels);
                       fileStruct(fileI).numPoints    = files(fileI).bytes/(fileStruct(fileI).num_channels * 2); % int16 = 2 bytes
                       fileStruct(fileI).recLength    = fileStruct(fileI).num_points / fileStruct(fileI).sample_rate;
                       fileStruct(fileI).precision     = 0.195;
                       fileStruct(fileI).unit          = 'uV';
                   case 'analogin.dat'
                       count = count + 1;
                       fileStruct(fileI) = key;
                       fileStruct(fileI).file_name = 'analogin.dat';
                       fileStruct(fileI).signal_type = 'analog_in';
                       fileStruct(fileI).data_type   = 'uint16';
                       fileStruct(fileI).data_format = 'channels x samples';
                       fileStruct(fileI).bytes       = num2str(files(fileI).bytes);
                       fileStruct(fileI).sample_rate = header.frequency_parameters.board_adc_sample_rate;
                       fileStruct(fileI).num_channels  = length(header.board_adc_channels);
                       fileStruct(fileI).num_points    = files(fileI).bytes/(fileStruct(fileI).num_channels * 2); % uint16 = 2 bytes
                       fileStruct(fileI).rec_length    = fileStruct(fileI).num_points / fileStruct(fileI).sample_rate;
                       fileStruct(fileI).precision     = 0.000050354;
                       fileStruct(fileI).unit          = 'V';
                   case 'auxiliary.dat'
                       count = count + 1;
                       fileStruct(fileI) = key;
                       fileStruct(fileI).file_name = 'auxiliary.dat';
                       fileStruct(fileI).signal_type = 'other';
                       fileStruct(fileI).data_type   = 'uint16';
                       fileStruct(fileI).data_format = 'channels x samples';
                       fileStruct(fileI).bytes       = num2str(files(fileI).bytes);
                       fileStruct(fileI).sample_rate = header.frequency_parameters.aux_input_sample_rate;
                       fileStruct(fileI).num_channels  = length(header.aux_input_channels);
                       fileStruct(fileI).num_points    = files(fileI).bytes/(fileStruct(fileI).num_channels * 2); % uint16 = 2 bytes
                       fileStruct(fileI).rec_length    = fileStruct(fileI).num_points / fileStruct(fileI).sample_rate;
                       fileStruct(fileI).precision     = 0.0000374; % in uV
                       fileStruct(fileI).unit          = 'V';
                       fileStruct(fileI).description   = 'Auxillary input channels, Intan Headstage Accelerometer';
                   case 'digitalin.dat'
                       count = count + 1;
                       fileStruct(fileI) = key;
                       fileStruct(fileI).file_name = 'digitalin.dat';
                       fileStruct(fileI).signal_type = 'digital';
                       fileStruct(fileI).data_type   = 'uint16';
                       fileStruct(fileI).data_format = '16 bit word x samples';
                       fileStruct(fileI).bytes       = num2str(files(fileI).bytes);
                       fileStruct(fileI).sample_rate = header.frequency_parameters.board_dig_in_sample_rate;
                       fileStruct(fileI).num_channels  = length(header.board_dig_in_channels);
                       fileStruct(fileI).num_points    = files(fileI).bytes/2; % uint16 = 2 bytes
                       fileStruct(fileI).rec_length    = fileStruct(fileI).num_points / fileStruct(fileI).sample_rate;
                   case 'supply.dat'
                       count = count + 1;
                       fileStruct(fileI) = key;
                       fileStruct(fileI).file_name = 'supply.dat';
                       fileStruct(fileI).signal_type = 'other';
                       fileStruct(fileI).data_type   = 'uint16';
                       fileStruct(fileI).data_format = 'channels x samples';
                       fileStruct(fileI).bytes       = num2str(files(fileI).bytes);
                       fileStruct(fileI).sample_rate = header.frequency_parameters.supply_voltage_sample_rate;
                       fileStruct(fileI).num_channels  = length(header.supply_voltage_channels);
                       fileStruct(fileI).num_points    = files(fileI).bytes/(fileStruct(fileI).num_channels * 2); % uint16 = 2 bytes
                       fileStruct(fileI).rec_length    = fileStruct(fileI).num_points / fileStruct(fileI).sample_rate;
                       fileStruct(fileI).precision     = 0.0000748; % in uV
                       fileStruct(fileI).unit          = 'V';
                       fileStruct(fileI).description   = 'Supply input voltage, i.e. Power';
                   case 'time.dat'
                       count = count + 1;
                       fileStruct(fileI) = key;
                       fileStruct(fileI).file_name = 'time.dat';
                       fileStruct(fileI).signal_type = 'time';
                       fileStruct(fileI).data_type   = 'int32';
                       fileStruct(fileI).data_format = 'integer sequence';
                       fileStruct(fileI).bytes       = num2str(files(fileI).bytes);
                       fileStruct(fileI).sample_rate = header.frequency_parameters.amplifier_sample_rate;
                       fileStruct(fileI).num_points    = files(fileI).bytes/4; % int32 = 4 bytes
                       fileStruct(fileI).rec_length    = fileStruct(fileI).num_points / fileStruct(fileI).sample_rate;








                end

           end

        end
   end
end