% Object Class to handle interactions with Intan Recordings
% So far only 1 file per recording type format is implemented

classdef Rec
   properties
      Header             % Matlab struct of header info
      NumChannels        % Number of Amplifier Channels
      Impedances         % Impedance of Amplifier Channels
      SampleRate         % Sample Rate of Amplifier Channels
      Samples            % Number of Samples of Amplifier Channels
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
            if nargin == 0 || isempty(filePath)% If no directory is passed ask user for a 
                [~, filePath, ~] = ...
                uigetfile('*.rhd', 'Select an RHD2000 Data File', 'MultiSelect', 'off');
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
            self.NumChannels        = ampFile.NumChannels;
            self.Impedances         = ampFile.Impedances;
            self.SampleRate         = ampFile.SampleRate;
            self.Samples            = ampFile.Samples;
            self.Length             = ampFile.Length;

            digFile = self.Files(strcmp({self.Files.SignalType},'digital'));
            self.NumDigitalChannels = digFile.NumChannels;

            analogFile = self.Files(strcmp({self.Files.SignalType},'analog'));
            self.NumAnalogChannels = analogFile.NumChannels;

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
                self.Time = datetime(output.dateTime,'InputFormat','yyMMdd_hhmmss');
            end           
       end
   end
end
