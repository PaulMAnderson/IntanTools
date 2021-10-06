function combineAnalogueIntanData(varargin)
% Code to combine two intan analogue recording files
% Tests if the recording names are the same,
% if not will only combine matching ones
% Expects input to be paths to two seperate recording directories,
% containing at least an Intan header (info.rhd) and an analogue recording
% (analogin.dat)

% Inputs: needs two filepaths, path1 and path2
% Name Value Arguments
%   Output       = The path to output the file; default = parent directory
%                  of filepath1
%   OutputHeader = Whether to output a new header file that matches the
%                  output analogue file; default = true,

p = inputParser; % Create object of class 'inputParser'

% define defaults
defOutput          = []; 
defOutputHeader    = true; % in ms

% validation funs
valPath = @(x) validateattributes(x,{'cell', 'string'}, {'nonempty'});
    
addRequired(p, 'filepath1', valPath);
addRequired(p, 'filepath2', valPath);
addParameter(p, 'Output', defOutput, valPath);
addParameter(p, 'OutputHeader', defOutputHeader, islogical);

parse(p, varargin{:});

filepath1    = p.Results.filepath1; 
filepath2    = p.Results.filepath2;
outputPath   = p.Results.Output;
outputHeader = p.Results.OutputHeader;

clear p

if isempty(outputPath)
    outputPath = fileparts(filepath1);
end

%% process

assert(logical(exist([filepath1 filesep 'info.rhd'],'file')),'Header file missing from directory 1');
assert(logical(exist([filepath2 filesep 'info.rhd'],'file')),'Header file missing from directory 2');
assert(logical(exist([filepath1 filesep 'analogin.dat'],'file')),'Analogue file missing from directory 1');
assert(logical(exist([filepath2 filesep 'analogin.dat'],'file')),'Analogue file missing from directory 2');

header1 = loadIntanHeader(filepath1);
header2 = loadIntanHeader(filepath2);

adc1 = header1.board_adc_channels;
adc2 = header2.board_adc_channels;

nChans1 = length(adc1);
fileinfo1 = dir([filepath1 filesep 'analogin.dat']);
nSamples1 = fileinfo1.bytes/(nChans1 * 2); % uint16 = 2 bytes
fid1 = fopen([filepath1 filesep 'analogin.dat'], 'r');
data1 = fread(fid1, [nChans1, nSamples1], 'uint16');
fclose(fid1);

nChans2 = length(adc1);
fileinfo2 = dir([filepath2 filesep 'analogin.dat']);
nSamples2 = fileinfo2.bytes/(nChans2 * 2); % uint16 = 2 bytes
fid2 = fopen([filepath2 filesep 'analogin.dat'], 'r');
data2 = fread(fid2, [nChans2, nSamples2], 'uint16');
fclose(fid2);

% names1 = {adc1.custom_channel_name};
% names2 = {adc2.custom_channel_name};
% 
% matchedChans = intersect(names1,names2);
% 
% for chanI = 1:length(matchedChans)
%     idx1 = find(strcmp(names1,matchedChans{chanI}));
%     idx2 = find(strcmp(names2,matchedChans{chanI}));
%        
%     combinedData(chanI,:) = [data1(idx1,:) data2(idx2,:)];
%     board_adc_channels(chanI) = header2.board_adc_channels(idx2);
% end



combinedHeader = header2;
combinedHeader.board_adc_channels = board_adc_channels;


