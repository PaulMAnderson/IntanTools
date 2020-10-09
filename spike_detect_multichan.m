function spikes = spike_detect_multichan(data, timestamps, info)
% Detect spikes using amplitude thresholding based on median noise levels
% Adapted from the wave_clus amp_detect function
%% Set a bunch of parameters

srate = info.header.sampleRate;          % sample rate
locut = 300;            % lower bound of filter
hicut = 6000;           % upper bound of filter
save_pre = 20;          % points to save prior to spike
save_post = 40;         % points to save after spike
ref_period = 2;         % refractory period
ref = floor(ref_period *srate/1000);     % convert to points
std_min = 5;            % minimum threshold for detection default is 5
std_max = 35;                       % maximum threshold for detection

%% Bandpass filter the data
smooth_data = eegfilt(data', srate, locut, 0);
smooth_data = eegfilt(smooth_data, srate, 0, hicut);

std_noise = median(abs(smooth_data),2)./0.6745; % Calculate median noise levels
thr = std_min * std_noise;      % Determine threshold for spike detection
thr_max = std_max * std_noise;   % Determine threshold for artifact removal

%% Detect Spikes

for chan = 1:size(data,1)
    nspk = 0;

    xaux = find(abs(smooth_data(chan,save_pre+2:end-save_post-2)) > thr(chan)) + save_pre+1;
    xaux0 = 0;
    for i=1:length(xaux)
        if xaux(i) >= xaux0 + ref
            [~, iaux] = max(abs(smooth_data(chan, xaux(i):xaux(i)+floor(ref/2)-1)));    %introduces alignment
            nspk = nspk + 1;
            index(nspk) = iaux + xaux(i) -1;
            xaux0 = index(nspk);
        end
    end

    % SPIKE STORING
    ls = save_pre + save_post;
    spike = zeros(nspk,ls+4);

    chan_data = [smooth_data(chan,:) zeros(1,save_post)];
    for i=1:nspk                          %Eliminates artifacts
        if max(abs( chan_data(index(i)-save_pre:index(i)+save_post) )) < thr_max(chan)              
            spike(i,:) = chan_data(index(i)-save_pre-1:index(i)+save_post+2);
        end
    end
    aux = find(spike(:,save_pre)==0);       %erases indexes that were artifacts
    spike(aux,:)=[];
    if exist('index','var')
        index(aux)=[]; 
        spikes.times{chan} = timestamps(index); 
    else
        spikes.times{chan} = [];
    end

    spikes.data{chan} = spike;

end

