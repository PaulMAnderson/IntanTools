function [EEG] = intan2EEGLAB(filepath,varargin)
% Function to import intan recording controller files into matlab in EEGLAB format


%% Parse Inputs

if nargin == 0 % Select a file
    [file, filepath, filterindex] = ...
    uigetfile('*.rhd', 'Select an RHD2000 Header File', 'MultiSelect', 'off');
else
    [fileParts, ~] = strsplit(filepath,filesep);
    file = fileParts{end};
    filepath = strjoin(fileParts(1:end-1) , filesep);
    filepath = [filepath filesep];
end

if nargin == 1 % Set defaults for filtering and channels to load if not specificed
    filtered = true;
    channels = [];   
end

if nargin > 1 % parse optional inputs
    argumentI = 1;
    while argumentI <= size(varargin,2)
        switch lower(varargin{argumentI})
            case 'filtered'
               filtered = varargin{argumentI + 1};
               argumentI = argumentI + 1;
            case 'channels'
                channels = varargin{argumentI + 1};
                argumentI = argumentI + 1;
            otherwise
                error('Unknown argument...')
        end
        argumentI = argumentI + 1;
    end
end

%% Load Data

% Load Header Info
intanRec = intanHeader([filepath file]);
if exist([filepath 'amplifier_CAR_HP.dat'],'file') && filtered
    amplifierDataFile = dir([filepath 'amplifier_CAR_HP.dat']);
elseif exist([filepath 'amplifier_CAR.dat'],'file') && filtered
    amplifierDataFile = dir([filepath 'amplifier_CAR.dat']);
else
    amplifierDataFile = dir([filepath 'amplifier.dat']);
end
eventDataFile     = dir([filepath 'digitalin.dat']);
timestampsFile    = dir([filepath 'time.dat']);



% Load Event and Time info
[eventData, timestamps] = intanEventTimes(intanRec, eventDataFile, timestampsFile, true);

% % Load Matlab file with recording info
% mfile = dir('*OptoTagging*.mat');
% try
%     load(mfile.name)
% catch
%     disp('Unable to load matlab file containing recrording session parameters');
% end

% Load amplifier (channel) data

numAmpChans = length(intanRec.amplifier_channels);
if ~exist('channels','var')
    channels = 1:numAmpChans;
end
numSamples = amplifierDataFile.bytes/(numAmpChans * 2); % int16 = 2 bytes
% Memory mapping method, allows to load specific channels
amplifierFilePath = [amplifierDataFile.folder filesep amplifierDataFile.name];
amplifierMap = memmapfile(amplifierFilePath,...
               'Format', {
               'int16', [numAmpChans numSamples], 'data'
               });
ampData = amplifierMap.Data.data(channels,:);
ampData     = ampData  * 0.195; % convert to microvolts
ampData     = single(ampData);

% Original Loading method, just read in the whole file
% fid         = fopen([amplifierDataFile.folder filesep amplifierDataFile.name], 'r');
% ampData     = fread(fid, [numAmpChans   , numSamples], '*int16'); 
% fclose(fid);
% ampData     = ampData  * 0.195; % convert to microvolts
% ampData     = single(ampData);


%% setup empty EEG struct
EEG = struct('setname',[],'filename',[],'filepath',[],'pnts',[],'nbchan',[], ...
    'trials',[],'srate',[],'xmin',[],'xmax',[],'data',[],'icawinv',[], ...
    'icasphere',[],'icaweights',[],'icaact',[],'event',[],'epoch',[], ...
    'chanlocs',[],'chaninfo',[],'comments',[],'ref',[],'saved',[]);

% assign values to EEG struct
EEG.srate = intanRec.frequency_parameters.amplifier_sample_rate;

EEG.times = timestamps;

EEG.setname    = 'Raw data';
EEG.filepath   = filepath;
EEG.filename   = file;
EEG.nbchan     = length(intanRec.amplifier_channels);
EEG.trials     = 1;
EEG.xmin       = EEG.times(1);
EEG.xmax       = EEG.times(end);

EEG.data = ampData;
clear ampData
for chanI = 1:length(channels)
    EEG.chanlocs(chanI).labels = intanRec.amplifier_channels(channels(chanI)).custom_channel_name;
end

EEG.event = eventData;

% main function end - intan2EEGLAB
end



%% Helper functions
function [intanRec] = loadIntanRecData(path, file)
% The following code comes from 'read_Intan_RHD2000_file.m'

    filename = [path,file];
    fid = fopen(filename, 'r');

    s = dir(filename);
    filesize = s.bytes;

    % Check 'magic number' at beginning of file to make sure this is an Intan
    % Technologies RHD2000 data file.
    magic_number = fread(fid, 1, 'uint32');
    if magic_number ~= hex2dec('c6912702')
        error('Unrecognized file type.');
    end

    % Read version number.
    data_file_main_version_number = fread(fid, 1, 'int16');
    data_file_secondary_version_number = fread(fid, 1, 'int16');

%     fprintf(1, '\n');
%     fprintf(1, 'Reading Intan Technologies RHD2000 Data File, Version %d.%d\n', ...
%         data_file_main_version_number, data_file_secondary_version_number);
%     fprintf(1, '\n');

    if (data_file_main_version_number == 1)
        num_samples_per_data_block = 60;
    else
        num_samples_per_data_block = 128;
    end

    % Read information of sampling rate and amplifier frequency settings.
    sample_rate = fread(fid, 1, 'single');
    dsp_enabled = fread(fid, 1, 'int16');
    actual_dsp_cutoff_frequency = fread(fid, 1, 'single');
    actual_lower_bandwidth = fread(fid, 1, 'single');
    actual_upper_bandwidth = fread(fid, 1, 'single');

    desired_dsp_cutoff_frequency = fread(fid, 1, 'single');
    desired_lower_bandwidth = fread(fid, 1, 'single');
    desired_upper_bandwidth = fread(fid, 1, 'single');

    % This tells us if a software 50/60 Hz notch filter was enabled during
    % the data acquisition.
    notch_filter_mode = fread(fid, 1, 'int16');
    notch_filter_frequency = 0;
    if (notch_filter_mode == 1)
        notch_filter_frequency = 50;
    elseif (notch_filter_mode == 2)
        notch_filter_frequency = 60;
    end

    desired_impedance_test_frequency = fread(fid, 1, 'single');
    actual_impedance_test_frequency = fread(fid, 1, 'single');

    % Place notes in data strucure
    intanRec.notes = struct( ...
        'note1', fread_QString(fid), ...
        'note2', fread_QString(fid), ...
        'note3', fread_QString(fid) );

    % If data file is from GUI v1.1 or later, see if temperature sensor data
    % was saved.
    num_temp_sensor_channels = 0;
    if ((data_file_main_version_number == 1 && data_file_secondary_version_number >= 1) ...
        || (data_file_main_version_number > 1))
        num_temp_sensor_channels = fread(fid, 1, 'int16');
    end

    % If data file is from GUI v1.3 or later, load eval board mode.
    eval_board_mode = 0;
    if ((data_file_main_version_number == 1 && data_file_secondary_version_number >= 3) ...
        || (data_file_main_version_number > 1))
        eval_board_mode = fread(fid, 1, 'int16');
    end

    % If data file is from v2.0 or later (Intan Recording Controller),
    % load name of digital reference channel.
    if (data_file_main_version_number > 1)
        intanRec.reference_channel = fread_QString(fid);
    end

    % Place frequency-related information in data structure.
    intanRec.frequency_parameters = struct( ...
        'amplifier_sample_rate', sample_rate, ...
        'aux_input_sample_rate', sample_rate / 4, ...
        'supply_voltage_sample_rate', sample_rate / num_samples_per_data_block, ...
        'board_adc_sample_rate', sample_rate, ...
        'board_dig_in_sample_rate', sample_rate, ...
        'desired_dsp_cutoff_frequency', desired_dsp_cutoff_frequency, ...
        'actual_dsp_cutoff_frequency', actual_dsp_cutoff_frequency, ...
        'dsp_enabled', dsp_enabled, ...
        'desired_lower_bandwidth', desired_lower_bandwidth, ...
        'actual_lower_bandwidth', actual_lower_bandwidth, ...
        'desired_upper_bandwidth', desired_upper_bandwidth, ...
        'actual_upper_bandwidth', actual_upper_bandwidth, ...
        'notch_filter_frequency', notch_filter_frequency, ...
        'desired_impedance_test_frequency', desired_impedance_test_frequency, ...
        'actual_impedance_test_frequency', actual_impedance_test_frequency );

    % Define data structure for spike trigger settings.
    spike_trigger_struct = struct( ...
        'voltage_trigger_mode', {}, ...
        'voltage_threshold', {}, ...
        'digital_trigger_channel', {}, ...
        'digital_edge_polarity', {} );

    new_trigger_channel = struct(spike_trigger_struct);
    intanRec.spike_triggers = struct(spike_trigger_struct);

    % Define data structure for data channels.
    channel_struct = struct( ...
        'native_channel_name', {}, ...
        'custom_channel_name', {}, ...
        'native_order', {}, ...
        'custom_order', {}, ...
        'board_stream', {}, ...
        'chip_channel', {}, ...
        'port_name', {}, ...
        'port_prefix', {}, ...
        'port_number', {}, ...
        'electrode_impedance_magnitude', {}, ...
        'electrode_impedance_phase', {} );

    new_channel = struct(channel_struct);

    % Create structure arrays for each type of data channel.
    intanRec.amplifier_channels = struct(channel_struct);
    intanRec.aux_input_channels = struct(channel_struct);
    intanRec.supply_voltage_channels = struct(channel_struct);
    intanRec.board_adc_channels = struct(channel_struct);
    intanRec.board_dig_in_channels = struct(channel_struct);
    intanRec.board_dig_out_channels = struct(channel_struct);

    amplifier_index = 1;
    aux_input_index = 1;
    supply_voltage_index = 1;
    board_adc_index = 1;
    board_dig_in_index = 1;
    board_dig_out_index = 1;

    % Read signal summary from data file header.

    number_of_signal_groups = fread(fid, 1, 'int16');

    for signal_group = 1:number_of_signal_groups
        signal_group_name = fread_QString(fid);
        signal_group_prefix = fread_QString(fid);
        signal_group_enabled = fread(fid, 1, 'int16');
        signal_group_num_channels = fread(fid, 1, 'int16');
        signal_group_num_amp_channels = fread(fid, 1, 'int16');

        if (signal_group_num_channels > 0 && signal_group_enabled > 0)
            new_channel(1).port_name = signal_group_name;
            new_channel(1).port_prefix = signal_group_prefix;
            new_channel(1).port_number = signal_group;
            for signal_channel = 1:signal_group_num_channels
                new_channel(1).native_channel_name = fread_QString(fid);
                new_channel(1).custom_channel_name = fread_QString(fid);
                new_channel(1).native_order = fread(fid, 1, 'int16');
                new_channel(1).custom_order = fread(fid, 1, 'int16');
                signal_type = fread(fid, 1, 'int16');
                channel_enabled = fread(fid, 1, 'int16');
                new_channel(1).chip_channel = fread(fid, 1, 'int16');
                new_channel(1).board_stream = fread(fid, 1, 'int16');
                new_trigger_channel(1).voltage_trigger_mode = fread(fid, 1, 'int16');
                new_trigger_channel(1).voltage_threshold = fread(fid, 1, 'int16');
                new_trigger_channel(1).digital_trigger_channel = fread(fid, 1, 'int16');
                new_trigger_channel(1).digital_edge_polarity = fread(fid, 1, 'int16');
                new_channel(1).electrode_impedance_magnitude = fread(fid, 1, 'single');
                new_channel(1).electrode_impedance_phase = fread(fid, 1, 'single');

                if (channel_enabled)
                    switch (signal_type)
                        case 0
                            intanRec.amplifier_channels(amplifier_index) = new_channel;
                            intanRec.spike_triggers(amplifier_index) = new_trigger_channel;
                            amplifier_index = amplifier_index + 1;
                        case 1
                            intanRec.aux_input_channels(aux_input_index) = new_channel;
                            aux_input_index = aux_input_index + 1;
                        case 2
                            intanRec.supply_voltage_channels(supply_voltage_index) = new_channel;
                            supply_voltage_index = supply_voltage_index + 1;
                        case 3
                            intanRec.board_adc_channels(board_adc_index) = new_channel;
                            board_adc_index = board_adc_index + 1;
                        case 4
                            intanRec.board_dig_in_channels(board_dig_in_index) = new_channel;
                            board_dig_in_index = board_dig_in_index + 1;
                        case 5
                            intanRec.board_dig_out_channels(board_dig_out_index) = new_channel;
                            board_dig_out_index = board_dig_out_index + 1;
                        otherwise
                            error('Unknown channel type');
                    end
                end

            end
        end
    end

    % Summarize contents of data file.
    num_amplifier_channels = amplifier_index - 1;
    num_aux_input_channels = aux_input_index - 1;
    num_supply_voltage_channels = supply_voltage_index - 1;
    num_board_adc_channels = board_adc_index - 1;
    num_board_dig_in_channels = board_dig_in_index - 1;
    num_board_dig_out_channels = board_dig_out_index - 1;

%     fprintf(1, 'Found %d amplifier channel%s.\n', ...
%         num_amplifier_channels, plural(num_amplifier_channels));
%     fprintf(1, 'Found %d auxiliary input channel%s.\n', ...
%         num_aux_input_channels, plural(num_aux_input_channels));
%     fprintf(1, 'Found %d supply voltage channel%s.\n', ...
%         num_supply_voltage_channels, plural(num_supply_voltage_channels));
%     fprintf(1, 'Found %d board ADC channel%s.\n', ...
%         num_board_adc_channels, plural(num_board_adc_channels));
%     fprintf(1, 'Found %d board digital input channel%s.\n', ...
%         num_board_dig_in_channels, plural(num_board_dig_in_channels));
%     fprintf(1, 'Found %d board digital output channel%s.\n', ...
%         num_board_dig_out_channels, plural(num_board_dig_out_channels));
%     fprintf(1, 'Found %d temperature sensor channel%s.\n', ...
%         num_temp_sensor_channels, plural(num_temp_sensor_channels));
%     fprintf(1, '\n');

    % Determine how many samples the data file contains.

    % Each data block contains num_samples_per_data_block amplifier samples.
    bytes_per_block = num_samples_per_data_block * 4;  % timestamp data
    bytes_per_block = bytes_per_block + num_samples_per_data_block * 2 * num_amplifier_channels;
    % Auxiliary inputs are sampled 4x slower than amplifiers
    bytes_per_block = bytes_per_block + (num_samples_per_data_block / 4) * 2 * num_aux_input_channels;
    % Supply voltage is sampled once per data block
    bytes_per_block = bytes_per_block + 1 * 2 * num_supply_voltage_channels;
    % Board analog inputs are sampled at same rate as amplifiers
    bytes_per_block = bytes_per_block + num_samples_per_data_block * 2 * num_board_adc_channels;
    % Board digital inputs are sampled at same rate as amplifiers
    if (num_board_dig_in_channels > 0)
        bytes_per_block = bytes_per_block + num_samples_per_data_block * 2;
    end
    % Board digital outputs are sampled at same rate as amplifiers
    if (num_board_dig_out_channels > 0)
        bytes_per_block = bytes_per_block + num_samples_per_data_block * 2;
    end
    % Temp sensor is sampled once per data block
    if (num_temp_sensor_channels > 0)
       bytes_per_block = bytes_per_block + 1 * 2 * num_temp_sensor_channels; 
    end

    % How many data blocks remain in this file?
    data_present = 0;
    bytes_remaining = filesize - ftell(fid);
    if (bytes_remaining > 0)
        data_present = 1;
    end

    num_data_blocks = bytes_remaining / bytes_per_block;

    num_amplifier_samples = num_samples_per_data_block * num_data_blocks;
    num_aux_input_samples = (num_samples_per_data_block / 4) * num_data_blocks;
    num_supply_voltage_samples = 1 * num_data_blocks;
    num_board_adc_samples = num_samples_per_data_block * num_data_blocks;
    num_board_dig_in_samples = num_samples_per_data_block * num_data_blocks;
    num_board_dig_out_samples = num_samples_per_data_block * num_data_blocks;

    record_time = num_amplifier_samples / sample_rate;

%     if (data_present)
%         fprintf(1, 'File contains %0.3f seconds of data.  Amplifiers were sampled at %0.2f kS/s.\n', ...
%             record_time, sample_rate / 1000);
%         fprintf(1, '\n');
%     else
%         fprintf(1, 'Header file contains no data.  Amplifiers were sampled at %0.2f kS/s.\n', ...
%             sample_rate / 1000);
%         fprintf(1, '\n');
%     end

    if (data_present)

%         % Pre-allocate memory for data.
%         fprintf(1, 'Allocating memory for data...\n');

        intanRec.t_amplifier = zeros(1, num_amplifier_samples);

        intanRec.amplifier_data = zeros(num_amplifier_channels, num_amplifier_samples);
        intanRec.aux_input_data = zeros(num_aux_input_channels, num_aux_input_samples);
        intanRec.supply_voltage_data = zeros(num_supply_voltage_channels, num_supply_voltage_samples);
        intanRec.temp_sensor_data = zeros(num_temp_sensor_channels, num_supply_voltage_samples);
        intanRec.board_adc_data = zeros(num_board_adc_channels, num_board_adc_samples);
        intanRec.board_dig_in_data = zeros(num_board_dig_in_channels, num_board_dig_in_samples);
        intanRec.board_dig_in_raw = zeros(1, num_board_dig_in_samples);
        intanRec.board_dig_out_data = zeros(num_board_dig_out_channels, num_board_dig_out_samples);
        intanRec.board_dig_out_raw = zeros(1, num_board_dig_out_samples);

        % Read sampled data from file.
%         fprintf(1, 'Reading data from file...\n');

        amplifier_index = 1;
        aux_input_index = 1;
        supply_voltage_index = 1;
        board_adc_index = 1;
        board_dig_in_index = 1;
        board_dig_out_index = 1;

        print_increment = 10;
        percent_done = print_increment;
        for i=1:num_data_blocks
            % In version 1.2, we moved from saving timestamps as unsigned
            % integeters to signed integers to accomidate negative (adjusted)
            % timestamps for pretrigger data.
            if ((data_file_main_version_number == 1 && data_file_secondary_version_number >= 2) ...
            || (data_file_main_version_number > 1))
                intanRec.t_amplifier(amplifier_index:(amplifier_index + num_samples_per_data_block - 1)) = fread(fid, num_samples_per_data_block, 'int32');
            else
                intanRec.t_amplifier(amplifier_index:(amplifier_index + num_samples_per_data_block - 1)) = fread(fid, num_samples_per_data_block, 'uint32');
            end
            if (num_amplifier_channels > 0)
                intanRec.amplifier_data(:, amplifier_index:(amplifier_index + num_samples_per_data_block - 1)) = fread(fid, [num_samples_per_data_block, num_amplifier_channels], 'uint16')';
            end
            if (num_aux_input_channels > 0)
                intanRec.aux_input_data(:, aux_input_index:(aux_input_index + (num_samples_per_data_block / 4) - 1)) = fread(fid, [(num_samples_per_data_block / 4), num_aux_input_channels], 'uint16')';
            end
            if (num_supply_voltage_channels > 0)
                intanRec.supply_voltage_data(:, supply_voltage_index) = fread(fid, [1, num_supply_voltage_channels], 'uint16')';
            end
            if (num_temp_sensor_channels > 0)
                intanRec.temp_sensor_data(:, supply_voltage_index) = fread(fid, [1, num_temp_sensor_channels], 'int16')';
            end
            if (num_board_adc_channels > 0)
                intanRec.board_adc_data(:, board_adc_index:(board_adc_index + num_samples_per_data_block - 1)) = fread(fid, [num_samples_per_data_block, num_board_adc_channels], 'uint16')';
            end
            if (num_board_dig_in_channels > 0)
                intanRec.board_dig_in_raw(board_dig_in_index:(board_dig_in_index + num_samples_per_data_block - 1)) = fread(fid, num_samples_per_data_block, 'uint16');
            end
            if (num_board_dig_out_channels > 0)
                intanRec.board_dig_out_raw(board_dig_out_index:(board_dig_out_index + num_samples_per_data_block - 1)) = fread(fid, num_samples_per_data_block, 'uint16');
            end

            amplifier_index = amplifier_index + num_samples_per_data_block;
            aux_input_index = aux_input_index + (num_samples_per_data_block / 4);
            supply_voltage_index = supply_voltage_index + 1;
            board_adc_index = board_adc_index + num_samples_per_data_block;
            board_dig_in_index = board_dig_in_index + num_samples_per_data_block;
            board_dig_out_index = board_dig_out_index + num_samples_per_data_block;

%             fraction_done = 100 * (i / num_data_blocks);
%             if (fraction_done >= percent_done)
%                 fprintf(1, '%d%% done...\n', percent_done);
%                 percent_done = percent_done + print_increment;
%             end
        end

        % Make sure we have read exactly the right amount of data.
        bytes_remaining = filesize - ftell(fid);
        if (bytes_remaining ~= 0)
            %error('Error: End of file not reached.');
        end

    end

    % Close data file.
    fclose(fid);

    if (data_present)

        fprintf(1, 'Parsing data...\n');

        % Extract digital input channels to separate variables.
        for i=1:num_board_dig_in_channels
           mask = 2^(intanRec.board_dig_in_channels(i).native_order) * ones(size(intanRec.board_dig_in_raw));
           intanRec.board_dig_in_data(i, :) = (bitand(intanRec.board_dig_in_raw, mask) > 0);
        end
        for i=1:num_board_dig_out_channels
           mask = 2^(intanRec.board_dig_out_channels(i).native_order) * ones(size(intanRec.board_dig_out_raw));
           intanRec.board_dig_out_data(i, :) = (bitand(intanRec.board_dig_out_raw, mask) > 0);
        end

        % Scale voltage levels appropriately.
        intanRec.amplifier_data = 0.195 * (intanRec.amplifier_data - 32768); % units = microvolts
        intanRec.aux_input_data = 37.4e-6 * intanRec.aux_input_data; % units = volts
        intanRec.supply_voltage_data = 74.8e-6 * intanRec.supply_voltage_data; % units = volts
        if (eval_board_mode == 1)
            intanRec.board_adc_data = 152.59e-6 * (intanRec.board_adc_data - 32768); % units = volts
        elseif (eval_board_mode == 13) % Intan Recording Controller
            intanRec.board_adc_data = 312.5e-6 * (intanRec.board_adc_data - 32768); % units = volts    
        else
            intanRec.board_adc_data = 50.354e-6 * intanRec.board_adc_data; % units = volts
        end
        intanRec.temp_sensor_data = intanRec.temp_sensor_data / 100; % units = deg C

        % Check for gaps in timestamps.
        num_gaps = sum(diff(intanRec.t_amplifier) ~= 1);
        if (num_gaps == 0)
%             fprintf(1, 'No missing timestamps in data.\n');
        else
            fprintf(1, 'Warning: %d gaps in timestamp data found.  Time scale will not be uniform!\n', ...
                num_gaps);
        end

        % Scale time steps (units = seconds).
        intanRec.t_amplifier = intanRec.t_amplifier / sample_rate;
        intanRec.t_aux_input = intanRec.t_amplifier(1:4:end);
        intanRec.t_supply_voltage = intanRec.t_amplifier(1:num_samples_per_data_block:end);
        intanRec.t_board_adc = intanRec.t_amplifier;
        intanRec.t_dig = intanRec.t_amplifier;
        intanRec.t_temp_sensor = intanRec.t_supply_voltage;

        % If the software notch filter was selected during the recording, apply the
        % same notch filter to amplifier data here.
        if (notch_filter_frequency > 0)
            fprintf(1, 'Applying notch filter...\n');

            print_increment = 10;
            percent_done = print_increment;
            for i=1:num_amplifier_channels
                intanRec.amplifier_data(i,:) = ...
                    notch_filter(intanRec.amplifier_data(i,:), sample_rate, notch_filter_frequency, 10);

%                 fraction_done = 100 * (i / num_amplifier_channels);
%                 if (fraction_done >= percent_done)
%                     fprintf(1, '%d%% done...\n', percent_done);
%                     percent_done = percent_done + print_increment;
%                 end

            end
        end
    end

% end of function  
end


function a = fread_QString(fid)

    % a = read_QString(fid)
    %
    % Read Qt style QString.  The first 32-bit unsigned number indicates
    % the length of the string (in bytes).  If this number equals 0xFFFFFFFF,
    % the string is null.

    a = '';
    length = fread(fid, 1, 'uint32');
    if length == hex2num('ffffffff')
   
        return;
    end
    % convert length from bytes to 16-bit Unicode words
    length = length / 2;

    for i=1:length
        a(i) = fread(fid, 1, 'uint16');
    end

    return

end


function out = notch_filter(in, fSample, fNotch, Bandwidth)

    % out = notch_filter(in, fSample, fNotch, Bandwidth)
    %
    % Implements a notch filter (e.g., for 50 or 60 Hz) on vector 'in'.
    % fSample = sample rate of data (in Hz or Samples/sec)
    % fNotch = filter notch frequency (in Hz)
    % Bandwidth = notch 3-dB bandwidth (in Hz).  A bandwidth of 10 Hz is
    %   recommended for 50 or 60 Hz notch filters; narrower bandwidths lead to
    %   poor time-domain properties with an extended ringing response to
    %   transient disturbances.
    %
    % Example:  If neural data was sampled at 30 kSamples/sec
    % and you wish to implement a 60 Hz notch filter:
    %
    % out = notch_filter(in, 30000, 60, 10);

    tstep = 1/fSample;
    Fc = fNotch*tstep;

    L = length(in);

    % Calculate IIR filter parameters
    d = exp(-2*pi*(Bandwidth/2)*tstep);
    b = (1 + d*d)*cos(2*pi*Fc);
    a0 = 1;
    a1 = -b;
    a2 = d*d;
    a = (1 + d*d)/2;
    b0 = 1;
    b1 = -2*cos(2*pi*Fc);
    b2 = 1;

    out = zeros(size(in));
    out(1) = in(1);  
    out(2) = in(2);
    % (If filtering a continuous data stream, change out(1) and out(2) to the
    %  previous final two values of out.)

    % Run filter
    for i=3:L
        out(i) = (a*b2*in(i-2) + a*b1*in(i-1) + a*b0*in(i) - a2*out(i-2) - a1*out(i-1))/a0;
    end

    return
end
