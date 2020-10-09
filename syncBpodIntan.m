%% Combine Intan Recording Data with BPod Session Data

%% File IO

% Select and load recording file


% Select and load session .mat file - loads a struct called SessionData


%% Find event onsets that match

RawEvents = SessionData.RawEvents;
RawData   = SessionData.RawData;
TrialStartTimestamp = SessionData.TrialStartTimestamp;
TrialStartTimestamp = TrialStartTimestamp - TrialStartTimestamp(1) + EEG.times(EEG.event(1).latency);
TrialStartTimestamp = 