function cleanRawData(filePath)
% Uses EEGLABs clean_rawdata function to estimate badchannels and noisy
% time-periods in an Intan recording. Does so by loading data and
% downsampling to 1KHz and placing into an EEG struct then running 
% the functions as expected by EEGLAB

%% File IO
% Change this to expect typical folder structure for Optotagging recordings
% For now will just run on 'amplifier.dat' files in folder

ampFile     = dir([filePath filesep 'amplifier.dat']);
headerFile  = dir([filePath filesep 'info.rhd']);

animalNum = regexp(filePath,'PMA(\d{2})','once','match');
electrode = generateChannelMap('Animal',animalNum);

header = loadIntanHeader(headerFile);

numChannels = length(header.amplifier_channels);
numSamples  = ampFile.bytes/numChannels/2; % samples = bytes/channels/2 (2 bits per int16 sample)
sRate       = header.frequency_parameters.amplifier_sample_rate;

fid = fopen([ampFile.folder filesep ampFile.name],'r');

numbersToSkip = 20 - 1; % We want every 20th sample, therefore skip 19 
bytesToSkip = numbersToSkip * numChannels * 2; % Multiply by 2 for uint16, which is 2 bytes
EEG.data = fread(fid, [numChannels inf], '256*int16', bytesToSkip);
% This command tells fread to take 256 samples at int16, then skip the
% specified bytes, then continue...

fclose(fid);

% Assign other needed fields to EEG struct
EEG.nbchan = numChannels;
EEG.srate = sRate;
for chanI = 1:numChannels
    EEG.chanlocs(chanI) = struct('theta',[],'radius',[],'labels',num2str(chanI),...
        'sph_theta',[],'sph_phi',[],'sph_radius',[],...
        'X',electrode.xcoords(chanI),'Y',electrode.ycoords(chanI),'Z',0);  
end



