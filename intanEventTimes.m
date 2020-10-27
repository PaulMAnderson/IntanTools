function [eventData, varargout] = intanEventTimes(intanRec, eventDataFile, timestampsFile, inSeconds)

%% Calculates event times (in seconds) from Intan digital in data
% intanRec: is a struct generated by intan2Binary that contains header info
% for an intan Recording in the 'seperate file per channel type' format
% eventDataFile: is a struct generated by dir('file'), will attempt to
% still work if its a file path as well

%% Check Inputs

if nargin < 4  % Output timestamps in seconds unless told not to
   inSeconds = true; 
end   

% Check if eventDataFile is a path or not
if isempty(eventDataFile)
    parseEvents = false;
else
    parseEvents = true;
    if ischar(eventDataFile) || isstring(eventDataFile) || iscellstr(eventDataFile)
       try 
           eventDataFile = dir(eventDataFile);
       catch
           error('Error when parsing the eventDataFile path')
       end
    end
end

% Check if timestampsFile is a path or not
if ischar(timestampsFile) || isstring(timestampsFile) || iscellstr(timestampsFile)
   try 
       timestampsFile = dir(timestampsFile);
   catch
       error('Error when parsing the timestampsFile string')
   end
end
  
  
%% Load Data

% Get info on Digital In Channels

numDigitalInChans = length(intanRec.board_dig_in_channels);

% Check for wire inputs - digital in 9-16, treat these as 8 bit input
wireIn = false;
try
    if strcmp(intanRec.board_dig_in_channels(end).native_channel_name, 'DIGITAL-IN-16') ...
        && strcmp(intanRec.board_dig_in_channels(end-7).native_channel_name, 'DIGITAL-IN-09')
        wireIn = true;    
        numDigitalInChans = length(intanRec.board_dig_in_channels) - 8;
    end
end

% load timestamps
fid = fopen([timestampsFile.folder filesep timestampsFile.name],'r');
timestamps = fread(fid,[1, inf], 'int32');
fclose(fid);

% convert timestamps to seconds
secTimestamps = timestamps./intanRec.frequency_parameters.amplifier_sample_rate;

if numDigitalInChans > 0

    % load digital input data - has a bitword format, see RHD  Application
    % note:  Data  file formats for details
    eventSamples = eventDataFile.bytes/2; % uint16 = 2 bytes
    fid = fopen([eventDataFile.folder filesep eventDataFile.name],'r');
    digitalInWord = fread(fid,eventSamples,'uint16');
    fclose(fid);

    % Parse each channel of the digital input data
    digitalInData = zeros(numDigitalInChans,length(digitalInWord));

    for chanI = 1:numDigitalInChans
        chanID = intanRec.board_dig_in_channels(chanI).native_order;
        digitalInData(chanI,:) = (bitand(digitalInWord, 2^chanID) > 0); % ch has a value of 0-15 here       
    end
    
    if wireIn
        bitCode = bitshift(digitalInWord,-8);
        % Takes just the last 8 channels output as binary
    end
end

%% Process Data

% Find event onsets and offsets
if numDigitalInChans > 0 & ~isempty(digitalInData)
    eventOn    = cell(1, numDigitalInChans);
    eventOff   = cell(1, numDigitalInChans);
    numEvents  = 0;

    for chanI = 1:numDigitalInChans
        digChanges = find(sign(diff(digitalInData(chanI,:))));
        if isempty(digChanges)
            warning(['No events detected on event channel ' num2str(chanI) '...'])
        else

            digChanges = digChanges + 1; % accounts for the missing timestamp from diff
            if digitalInData(chanI,digChanges(1))
                eventOn{chanI} = digChanges(1:2:end);
                eventOff{chanI} = digChanges(2:2:end);
            else
                eventOn{chanI}  = digChanges(2:2:end);
                eventOff{chanI} = digChanges(1:2:end);     
            end
        end
        numEvents = numEvents + length(eventOn{chanI});
    end

    if wireIn
        chanI = chanI + 1;
        bitChanges = find(sign(diff(bitCode)));
        if isempty(bitChanges)
            warning('No events detected in bitCode...')
            wireIn = false;
        else
            bitChanges = bitChanges + 1; % accounts for the missing timestamp from diff
            if bitCode(bitChanges(1))
                eventOn{chanI}  = bitChanges(1:2:end);
                eventOff{chanI} = bitChanges(2:2:end);
            else
                eventOn{chanI}  = bitChanges(2:2:end);
                eventOff{chanI} = bitChanges(1:2:end);     
            end
        end
        
        if length(eventOn{chanI}) > length(eventOff{chanI})
            eventOff{chanI}(end+1) = length(bitCode);
        end
        numEvents = numEvents + length(eventOn{chanI});
    end

    % create event structure
    eventData(numEvents) = struct('type',[],'latency',[],'duration',[]);

    % Calculate sampling interval in ms
    samplingInterval = 1000 / intanRec.frequency_parameters.board_dig_in_sample_rate;


    % loop through all events

    eventCount = 1;
    for chanI = 1:numDigitalInChans
        for eventI = 1:length(eventOn{chanI})
            eventData(eventCount).type     = intanRec.board_dig_in_channels(chanI).native_order + 1001;
            % Native numbering starts at 0, the 1000 gets us away from 8
            % bit binary event numbers
            eventData(eventCount).latency  = eventOn{chanI}(eventI);
            eventData(eventCount).time     = secTimestamps(eventData(eventCount).latency);
            eventData(eventCount).duration = (eventOff{chanI}(eventI) - eventOn{chanI}(eventI)) * samplingInterval; % Duration in ms

            eventCount = eventCount + 1;
        end
    end

   if wireIn
       chanI = chanI + 1;
        for eventI = 1:length(eventOn{chanI})
            eventData(eventCount).type     = bitCode(eventOn{chanI}(eventI));
            eventData(eventCount).latency  = eventOn{chanI}(eventI);
            eventData(eventCount).time     = secTimestamps(eventData(eventCount).latency);
            eventData(eventCount).duration = (eventOff{chanI}(eventI) - eventOn{chanI}(eventI)) * samplingInterval; % Duration in ms
            eventCount = eventCount + 1;
        end
    end
    
    % sort events by time

    [~, eventIdx] = sort([eventData.latency]);
    eventData     = eventData(eventIdx);
else
    eventData = [];
end
    
% Optionally output the timestamps 
if nargout == 2
    if inSeconds
        varargout = {secTimestamps};
    else
        varargout = {timestamps};
    end
end

