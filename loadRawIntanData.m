function outData = loadRawIntanData(varargin)
% Function to load raw Intan data
% Ideally used to read a small chunk of a single channel
% Can be used for larger pieces but memory constraints rapidly occur
% Parameters
% RecData   : RecData struct; see parseRecordingPath Function
% FilePath  : FilePath to read from 
% Channel   : Channel to read in, if not supplied reads channel 1; INT
% StartTime : Time to read from; default is start of file
% End Time  : Time to end read; if not provided defaults to 10 seconds
% Downsample: Downsample factor; if not provided defaults to 20 i.e. 1 KHz

%% Input Parser
p = inputParser; % Create object of class 'inputParser'

addParameter(p, 'RecData', [], @isstruct);
addParameter(p, 'filePath', pwd, @isfolder);
addParameter(p, 'StartTime', 0, @isnumeric);
addParameter(p, 'EndTime', [], @isnumeric);
addParameter(p, 'Channel', 1, @isnumeric);
addParameter(p, 'DownSample', 1, @isnumeric);
addParameter(p, 'HiPass', [], @isnumeric);

parse(p, varargin{:});

recData      = p.Results.RecData;
filePath     = p.Results.filePath; 
startTime    = p.Results.StartTime;
endTime      = p.Results.EndTime;
channel      = p.Results.Channel;
downSample   = p.Results.DownSample;
hiPass       = p.Results.HiPass;

%% Process inputs

if isempty(recData)
    recData = parseRecordingPath(filePath);
end

header = recData.Header;
numChannels = length(header.amplifier_channels);
assert(max(channel) <= numChannels, ['Channel is outside channel range: '...
    num2str(numChannels)]);

ampFile     = recData.AmplifierFile;
fileName    = [ampFile.folder filesep ampFile.name];
numSamples  = ampFile.bytes/numChannels/2;
sRate = header.frequency_parameters.amplifier_sample_rate;
sInt  = 1/sRate;
timeStamps = 0:sInt:(numSamples/sRate);
if length(timeStamps) > numSamples
    timeStamps = timeStamps(1:numSamples);
end
if isempty(endTime)
    endTime = startTime + 10;
end

assert(startTime < timeStamps(end),['Start Time is outside max time: ' ...
    num2str(timeStamps(end)) 's']);
assert(endTime <= timeStamps(end),['End Time is outside max time: ' ...
    num2str(timeStamps(end)) 's']);

%% Load data
% Memory map amplifier file
amplifierMap = memmapfile(fileName,...
'Format', {
'int16', [numChannels numSamples], 'data'
});

% Find samples
tIdx = dsearchn(timeStamps(:),[startTime; endTime]);

tempData = amplifierMap.Data.data(channel,tIdx(1):tIdx(2));
outData = double(tempData) * 0.195;

if downSample ~= 1
    outData = decimate(outData,downSample);
end

if ~isempty(hiPass)
    outData = eegfilt(outData,sRate,hiPass,0);
end














