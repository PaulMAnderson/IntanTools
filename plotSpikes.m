%% Quick script to identify and plot spikes in Intan Rec Files
% Assumes there is already a high-pass and common average referenced file
% in the current folder

%% Load Data
EEG = intan2EEGLAB([pwd filesep 'info.rhd']);
% pop_eegplot( EEG, 1, 1, 0);
% Visually inspect and choose a channel to plot

%%
channel = 52;

spikes = spike_detect(EEG.data(channel,:),EEG.times,EEG.srate,1,'neg');
%% Sort spike data

pc = 10/100; % remove 10% largest spikes
maxAmps = max(abs(spikes.data'));
zhi  = quantile(maxAmps,1 - pc);
outliers = maxAmps > zhi;

spikes.times(outliers)  = [];
spikes.index(outliers)  = [];
spikes.data(outliers,:) = [];

% Make a timevector
msInt = 1 / (EEG.srate / 1000);
t = 0:msInt:size(spikes.data,2)*msInt - msInt;

spikeColours = cmocean('deep',length(spikes.times));
spikeColours(:,4) = 0.5; % Make them semi-transparent


%% Plotting here
waveformFig = figure(11);
waveformAx =  axes(waveformFig);
hold(waveformAx,'on');
for spikeI = 1:length(spikes.times)
spikePlot(spikeI) = plot(waveformAx,t,spikes.data(spikeI,:),...
    'color',spikeColours(spikeI,:));
end
meanSpikePlot = plot(t,mean(spikes.data,1),'k','LineWidth',2);

waveformAx.XLabel.String = 'Time (ms)';
waveformAx.YLabel.String = 'Amplitude (mV)';
waveformAx.XLim = [t(1) t(end)]; 

hold(waveformAx,'off');


% Timeseries plot

tWin   = [15 17]; % Random timepoint to plot
tIndex = dsearchn(EEG.times',tWin');

timeSeriesFig = figure(12);
timeSeriesAx =  axes(timeSeriesFig);
hold(timeSeriesAx,'on');

timeSeriesPlot = plot(EEG.times(tIndex(1):tIndex(2)),EEG.data(channel,tIndex(1):tIndex(2)),...
    'color',[0.33 0.33 0.33],'LineWidth',0.25);

currentSpikes = find(spikes.index>tIndex(1) & spikes.index<tIndex(2));
scatter(EEG.times(spikes.index(currentSpikes)),...
    EEG.data(channel,spikes.index(currentSpikes)),'r*');


timeSeriesAx.XLabel.String = 'Time (s)';
timeSeriesAx.YLabel.String = 'Amplitude (mV)';




