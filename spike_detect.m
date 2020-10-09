function spikes = spike_detect(data, timestamps, srate, filtered, detect_direction)
% Detect spikes using amplitude thresholding based on median noise levels
% Adapted from the wave_clus amp_detect function

% initial stuff

if nargin < 4
    filtered = 0;
end

if nargin < 5
    detect_direction = 'both';
end
%% Set a bunch of parameters

% srate = info.header.sampleRate;          % sample rate
locut = 500;            % lower bound of filter
hicut = 6000;           % upper bound of filter
save_pre = 20;          % points to save prior to spike
save_post = 40;         % points to save after spike
ref_period = 2;         % refractory period
ref = floor(ref_period *srate/1000);     % convert to points
std_min = 5;            % minimum threshold for detection default is 5
std_max = 25;                       % maximum threshold for detection

%% Bandpass filter the data
if filtered == 1
   smooth_data = data; clear data
else
    fprintf('.');
    reshape( eegfilt(EEG.data,EEG.srate,0,45) ,[EEG.nbchan EEG.pnts EEG.trials]);
    smooth_data = eegfilt(data, srate, locut, 0);
    smooth_data = eegfilt(smooth_data, srate, 0, hicut);
end

std_noise = median(abs(smooth_data),2)./0.6745; % Calculate median noise levels
thr = std_min * std_noise;      % Determine threshold for spike detection
thr_max = std_max * std_noise;   % Determine threshold for artifact removal

for chan = 1:size(smooth_data,1)

%% Detect Spikes
switch detect_direction
        case 'pos'
            nspk = 0;
            xaux = find(smooth_data(save_pre+2:end-save_post-2) > thr) +save_pre+1;
            xaux0 = 0;
            for i=1:length(xaux)
                if xaux(i) >= xaux0 + ref
                    [maxi iaux]=max((smooth_data(xaux(i):xaux(i)+floor(ref/2)-1)));    %introduces alignment
                    nspk = nspk + 1;
                    index(nspk) = iaux + xaux(i) -1;
                    xaux0 = index(nspk);
                end
            end
        case 'neg'
            nspk = 0;
            xaux = find(smooth_data(save_pre+2:end-save_post-2) < -thr) +save_pre+1;
            xaux0 = 0;
            for i=1:length(xaux)
                if xaux(i) >= xaux0 + ref
                    [maxi iaux]=min((smooth_data(xaux(i):xaux(i)+floor(ref/2)-1)));    %introduces alignment
                    nspk = nspk + 1;
                    index(nspk) = iaux + xaux(i) -1;
                    xaux0 = index(nspk);
                end
            end
        case 'both'
            nspk = 0;
            xaux = find(abs(smooth_data(save_pre+2:end-save_post-2)) > thr) +save_pre+1;
            xaux0 = 0;
            for i=1:length(xaux)
                if xaux(i) >= xaux0 + ref
                    [maxi iaux]=max(abs(smooth_data(xaux(i):xaux(i)+floor(ref/2)-1)));    %introduces alignment
                    nspk = nspk + 1;
                    index(nspk) = iaux + xaux(i) -1;
                    xaux0 = index(nspk);
                end
            end
end


% SPIKE STORING
ls = save_pre + save_post;
spike = zeros(nspk,ls+4);

chan_data = [smooth_data zeros(1,save_post)];
for i=1:nspk                          %Eliminates artifacts
    if max(abs( chan_data(index(i)-save_pre:index(i)+save_post) )) < thr_max               
        spike(i,:) = chan_data(index(i)-save_pre-1:index(i)+save_post+2);
    end
end
aux = find(spike(:,save_pre)==0);       %erases indexes that were artifacts
spike(aux,:)=[];
if exist('index','var')
    index(aux)=[]; 
    spikes.times = timestamps(index); 
else
    spikes.times = [];
end
    spikes.index = index;
spikes.data = spike;


end



