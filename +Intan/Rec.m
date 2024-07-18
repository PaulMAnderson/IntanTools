% Object Class to handle interactions with Intan Recordings
% So far only 1 file per recording type format is implemented

classdef Rec
   properties
      Header             % Matlab struct of header info
      NumChannels        % Number of Amplifier Channels
      Impedances         % Impedance of Amplifier Channels
      SampleRate         % Sample Rate of Amplifier Channels
      NumSamples         % Number of Samples of Amplifier Channels
      Length             % Length of Recording in Seconds
      NumDigitalChannels % Number of Active Digital Channels (Always 16 bit data format)
      NumAnalogChannels  % Number of Active Analog Channels      
      Date               % Date of Recording
      Time               % Time of Recording
      Format             % Type of recording - One file per type is all that is implemented
      Files              % Array of Intan File Objects
      Animal             % Name of animal in recording
      Folder             % Name of folder containing the recording
      FullPath           % Full path to recording
   end

   methods
       function self = Rec(filePath) % Constructor           
            if nargin == 0 || isempty(filePath)
                % Check if there is an info.rhd file in the current path
                fileStruct = dir([pwd filesep 'info.rhd']);
                if ~isempty(fileStruct)
                    filePath = fileStruct.folder;
                else                
                    % If no directory is passed ask user                 
                    [~, filePath, ~] = ...
                    uigetfile('*.rhd', 'Select an RHD2000 Data File', 'MultiSelect', 'off');
                end
            else % Validate filepath
                if isfolder(filePath)
                    temp = dir(filePath);
                    filePath = temp(1).folder;
                elseif contains(filePath,'*.rhd')
                     temp = dir(filePath);
                     filePath = temp(1).folder;                     
                else
                    try
                        temp = dir(filePath);
                        filePath = temp(1).folder;
                    catch
                        error('Something is wrong with the filepath provided');
                    end
                end
            end

            self.FullPath = filePath;
            [~,folder] = fileparts(filePath);
            self.Folder = folder;

            self.Header = loadIntanHeader(filePath);
            fileStruct = [dir([filePath filesep 'info.rhd']); ...
              dir([filePath filesep '*.dat'])];

            for fileI = 1:length(fileStruct)
                fileP = [fileStruct(fileI).folder filesep ...
                         fileStruct(fileI).name];
                if fileI == 1
                    self.Files = Intan.File(fileP,self.Header);
                else
                    self.Files(fileI) = Intan.File(fileP,self.Header);
                end
            end

            ampFile = self.Files(strcmp({self.Files.SignalType},'amplifier'));
            if ~isempty(ampFile)
                self.NumChannels        = ampFile.NumChannels;
                self.Impedances         = ampFile.Impedances;
                self.SampleRate         = ampFile.SampleRate;
                self.NumSamples         = ampFile.NumSamples;
                self.Length             = ampFile.Length;
            end
            digFile = self.Files(strcmp({self.Files.SignalType},'digital'));
            if ~isempty(digFile)                
                self.NumDigitalChannels = digFile.NumChannels;
            end

            analogFile = self.Files(strcmp({self.Files.SignalType},'analog'));
            if ~isempty(analogFile)                
                self.NumAnalogChannels = analogFile.NumChannels;
            end

            self.Format = 'One File Per Signal Type';

            self = self.ParseFolder();
       end

       function self = ParseFolder(self)
            % Parse folder name with regex
            % animal name will be PMAd{1-3} or more generally A{2-3}dd{1-3}
            % date will be ' '/'_'d{6}
            animal   = '(?<animal>[A-Z]{2,3}\d{1,3})';
            output   = regexp(self.Folder,animal,'names');           
            if ~isempty(output)
                self.Animal = output.animal;                
            end

            dateTime = '(?<dateTime>\d{6}\_\d{6})';
            output   = regexp(self.Folder,dateTime,'names'); 
            if ~isempty(output)
                parts = strsplit(output.dateTime,'_');
                self.Date = datetime(parts{1},'InputFormat','yyMMdd');
                self.Time = datetime(output.dateTime,'InputFormat','yyMMdd_HHmmss');
            end           
       end

       function [eventData, varargout] = eventTimes(self,inSeconds)
           if nargin < 2
               inSeconds = true;
           end
           % Load event data and timestamps
           disp('Loading Raw Event and Time Data...')
           header = self.Header;
           % Get info on Digital In Channels
           numDigitalInChans = length(header.board_dig_in_channels);
           % Check for wire inputs - digital in 9-16, treat these as 8 bit input
           wireIn = false;
           try
               if strcmp(header.board_dig_in_channels(end).native_channel_name, 'DIGITAL-IN-16') ...
                       && strcmp(header.board_dig_in_channels(end-7).native_channel_name, 'DIGITAL-IN-09')
                   wireIn = true;
                   numDigitalInChans = length(header.board_dig_in_channels) - 8;
               end
           end

           if numDigitalInChans > 0
               % load digital input data - has a bitword format, see RHD  Application
               % note:  Data  file formats for details
               digitalFile = self.Files(strcmp({self.Files.SignalType},'digital'));
               eventSamples = digitalFile.Bytes/2; % uint16 = 2 bytes
               fid = fopen(digitalFile.FullPath,'r');
               digitalInWord = fread(fid,eventSamples,'uint16');
               fclose(fid);

               % Parse each channel of the digital input data
               digitalInData = zeros(numDigitalInChans,length(digitalInWord));

               for chanI = 1:numDigitalInChans
                   chanID = header.board_dig_in_channels(chanI).native_order;
                   digitalInData(chanI,:) = (bitand(digitalInWord, 2^chanID) > 0); % ch has a value of 0-15 here
               end

               if wireIn
                   bitCode = bitshift(digitalInWord,-8);
                   % Takes just the last 8 channels output as binary
               end
           end

           % Check here that timestamps match the event data length
           timeFile = self.Files(strcmp({self.Files.SignalType},'time'));
           timeSamples = timeFile.Bytes/4;
           if timeSamples < eventSamples
               warning('Time samples doesn''t match the event samples... Creating new timestamps file... Check for errors');
               % Generate a timestamp file
               delete(timeFile.FullPath)
               fid = fopen(timeFile.FullPath,'w');
               timestamps = 0:eventSamples;
               fwrite(fid,timestamps,'int32');
               fclose(fid);
               timeFile.FullPath = dir(timeFile.FullPath);
           else
               % load timestamps
               fid = fopen(timeFile.FullPath,'r');
               timestamps = fread(fid,[1, inf], 'int32');
               fclose(fid);
           end
           % convert timestamps to seconds
           secTimestamps = timestamps./header.frequency_parameters.amplifier_sample_rate;

           %% Process Data

           % Find event onsets and offsets
           if numDigitalInChans > 0 && ~isempty(digitalInData)
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
                       if bitCode(bitChanges(1)) == 0 % Must have been an ongoing event
                           eventOn{chanI} = 1;
                           eventOff{chanI} = bitChanges(1);
                           bitChanges(1) = [];
                           count = 2;
                       else
                           count = 1;
                       end
                       for eventI = 1:length(bitChanges)
                           if bitCode(bitChanges(eventI)) == 0
                               eventOff{chanI}(count-1) = bitChanges(eventI);
                           else
                               if eventI == 1
                                   eventOn{chanI}(count) = bitChanges(eventI);
                                   count = count + 1;
                               elseif eventI == length(bitChanges)
                                   eventOff{chanI}(count-1) = bitChanges(eventI);
                                   eventOn{chanI}(count)  = bitChanges(eventI);
                                   eventOff{chanI}(count) = length(bitCode);
                               else
                                   eventOn{chanI}(count) = bitChanges(eventI);
                                   eventOff{chanI}(count-1) = bitChanges(eventI);
                                   count = count + 1;
                               end
                           end
                       end
                       if length(eventOn{chanI}) > length(eventOff{chanI})
                           eventOff{chanI}(end+1) = length(bitCode);
                       end
                       numEvents = numEvents + length(eventOn{chanI});
                   end
               end

               % create event structure
               eventData(numEvents) = struct('event_code',[],'event_latency',[],'event_duration',[]);

               % Calculate sampling interval in ms
               samplingInterval = 1000 / header.frequency_parameters.board_dig_in_sample_rate;


               % loop through all events

               eventCount = 1;
               for chanI = 1:numDigitalInChans
                   for eventI = 1:length(eventOn{chanI})
                       eventData(eventCount).event_code     = header.board_dig_in_channels(chanI).native_order + 1001;
                       % Native numbering starts at 0, the 1001 gets us away from 8
                       % bit binary event numbers
                       eventData(eventCount).event_latency  = eventOn{chanI}(eventI);
                       eventData(eventCount).event_time     = secTimestamps(eventData(eventCount).event_latency);
                       try
                           eventData(eventCount).event_duration = (eventOff{chanI}(eventI) - eventOn{chanI}(eventI)) * samplingInterval; % Duration in ms
                       catch % Event doesn't end
                           eventData(eventCount).event_duration = length(timestamps) - eventData(eventCount).event_latency;
                       end
                       eventCount = eventCount + 1;
                   end
               end

               if wireIn
                   chanI = chanI + 1;
                   for eventI = 1:length(eventOn{chanI})
                       eventData(eventCount).event_code     = bitCode(eventOn{chanI}(eventI));
                       eventData(eventCount).event_latency  = eventOn{chanI}(eventI);
                       eventData(eventCount).event_time     = secTimestamps(eventData(eventCount).event_latency);
                       eventData(eventCount).event_duration = round( (eventOff{chanI}(eventI) ...
                                                                    - eventOn{chanI}(eventI)) ...
                                                                    * samplingInterval       ,3); % Duration in ms
                       eventCount = eventCount + 1;
                   end
               end

               % sort events by time

               [~, eventIdx] = sort([eventData.event_latency]);
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

       end % end eventTimes

      
       function [data, timeStamps] = getTimes(self, varargin)
           %% Parse Inputs
            p = inputParser;
            p.addParameter('Signal','amplifier',@ischar);
            p.addParameter('Channel',[],@isnumeric);
            p.addParameter('StartTime',0,@isnumeric);
            p.addParameter('EndTime',[],@isnumeric);

            p.parse(varargin{:});

            signal      = validatestring(p.Results.Signal,...
                {'data','rec','recording',...
                'amplifier','analog','digital','header','time'});
            channel     = p.Results.Channel;
            startTime   = p.Results.StartTime;
            endTime     = p.Results.EndTime;

            if any(strcmp(signal,{'data','rec','recording'}))
                signal = 'amplifier';
            end

            file = self.Files(strcmp(signal,{self.Files.SignalType}));            

            [data,timeStamps] = file.getTimes('Channel',channel,...
                'StartTime',startTime,'EndTime',endTime);

       end

        function [data, timeStamps] = getSamples(self, varargin)
           %% Parse Inputs
            p = inputParser;
            p.addParameter('Signal','amplifier',@ischar);
            p.addParameter('Channel',[],@isnumeric);
            p.addParameter('StartSample',[],@(x)validateattributes(x,{'numeric'},{'integer'}));
            p.addParameter('EndSample',[],@(x)validateattributes(x,{'numeric'},{'integer'}));
      
            p.parse(varargin{:});

            signal      = validatestring(p.Results.Signal,...
                {'data','rec','recording',...
                'amplifier','analog','digital','header','time'});
            channel     = p.Results.Channel;
            startSample = p.Results.StartSample;
            endSample   = p.Results.EndSample;

            if any(strcmp(signal,{'data','rec','recording'}))
                signal = 'amplifier';
            end

            file = self.Files(strcmp(signal,{self.Files.SignalType}));            

            [data,timeStamps] = file.getSamples('Channel',channel,...
                'startSample',startSample,'EndSample',endSample);


       end

       function combine(self, other, outPath)

           % Check recordings match
           assert(self.NumChannels == other.NumChannels,...
               'Channels don''t match...');
           assert(self.NumAnalogChannels == other.NumAnalogChannels,...
               'Analog channels don''t match...');
           assert(self.NumDigitalChannels == other.NumDigitalChannels,...
               'Digital channels don''t match...');

           % Create output folder
           if nargin < 3
               outPath = pwd;
           end
           if isfolder(outPath)
               temp = dir(outPath);
               outPath = temp(1).folder;
           else
               mkdir(outPath);
               temp = dir(outPath);
               outPath = temp(1).folder;
           end

           % Run through files

           for fileI = 1:length(self.Files)
                selfFile = self.Files(fileI);               
                otherIdx = find(strcmp(selfFile.FileName,{other.Files.FileName}));
                otherFile = other.Files(otherIdx);
                filePath = [outPath filesep selfFile.FileName];
                combine(selfFile,otherFile,filePath);


           end

       end

       function delete(self)
           % Destructor to gracefully remove the memorymapped data before
           % the memmap object so as to not load anything into memory
           for j = 1:length(self.Files)
               delete(self.Files(j));
           end
       end


   end
end
