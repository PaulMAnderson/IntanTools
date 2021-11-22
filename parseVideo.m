
function videoData = parseVideo(recPath, eventData)

[recPath, recordingData] = parseRecordingPath(recPath);

if isempty(recordingData.VideoFiles) % Check for existance of videos
    warning('No video files found. Skipping Video Sync');
    videoData = [];
    return
else        
    cameraIdx = find([eventData.type] == 1001);
    cameraEvents = eventData(cameraIdx);
    
    % find a video file to read data from
    if ~isempty(recordingData.VideoFiles.Processed)
        for fileI = 1:length(recordingData.VideoFiles.Processed)
            vidFile{fileI} = [recordingData.VideoFiles.Processed(fileI).folder filesep ...
                 recordingData.VideoFiles.Processed(fileI).name];
        end
    elseif  ~isempty(recordingData.VideoFiles.Raw)
        warning('Only raw video found, need to adjust it for Matlab, run convertVideos()');
        videoData = [];
        return
    else
       warning('No video found! Needed to sync video frames to TTL pulses');
       videoData = [];
       return
    end
        
    %Create a videoReader object to handle processing video
    for vidI = 1:length(vidFile)
        vid = VideoReader(vidFile{vidI});
        clear videoData
 
        % extract root file name to
        [~,fileName,~] = fileparts(vidFile{vidI});
        pattern = '[A-Z]{2,3}\d{1,3}[\s+\_]\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}';
        rootName = regexp(fileName,pattern,'match');
     
       
        %% Check if the frame rate & duration match the camera events       
        nFrames = round(vid.Duration.*vid.FrameRate); % Estimate number of frames
        % Check for discontinuities in camera events
        frameDiffs = round(diff([cameraEvents.time]),4);
        frameInterval = 1./vid.FrameRate;
        discont = find(frameDiffs > frameInterval + 0.001);

        if ~isempty(discont)
            for j = 1:length(discont)+1
                if j == 1
                    eventCounts(j,1) = 1;
                    eventCounts(j,2) = discont(j);
                elseif j == length(discont)+1
                    eventCounts(j,1) = discont(j-1)+1;
                    eventCounts(j,2) = length(cameraEvents);
                else
                    eventCounts(j,1) = discont(j-1)+1;
                    eventCounts(j,2) = discont(j);
                end
            end
        else
            eventCounts(1,1) = 1;
            eventCounts(1,2) = length(cameraEvents);
        end

        sectionIdx = dsearchn(diff(eventCounts')',nFrames);    
        matchEvents = cameraEvents(eventCounts(sectionIdx,1):eventCounts(sectionIdx,2));

        if nFrames == length(matchEvents)
            disp('Video frames match Camera TTL exactly...');
            videoData(1:nFrames) = struct('frame',[],'latency',[], 'time',[],'file',[]);
            frames  = num2cell(1:nFrames);
            latency = num2cell([matchEvents.latency]);
            time    = num2cell([matchEvents.time]);
            [videoData.frame] = frames{:};
            [videoData.latency] = latency{:};
            [videoData.time] = time{:};
            fileName = repmat(rootName,size(frames));
            [videoData.file] = fileName{:};
            vidData{vidI} = videoData;
            
        elseif length(matchEvents) < nFrames
            % There are less camera events than the number of video frames
            % Need to determine where the video frames start...
            warning(['More video frames than camera TTL events...' ...
                     ' Assuming that video started at the be...']);

            vidData{vidI} = [];
        elseif nFrames < length(matchEvents)
            % video is shorter than event count 
            % check that video starts after recording
            if matchEvents(1).time > 0 
                % Check whether there are more trials after the video stops   
                lastFrame = cameraIdx(eventCounts(sectionIdx,1) + (nFrames - 1));
                if any([eventData(lastFrame:end).type] == 1003)
                    warning(['There are more trials after the video stops...' ...
                     ' Possible that video is mismatched, check carefully!']);
                end       
                videoData(1:nFrames) = struct('frame',[],'latency',[], 'time',[]);
                frames  = num2cell(1:nFrames);
                latency = num2cell([matchEvents(1:nFrames).latency]);
                time    = num2cell([matchEvents(1:nFrames).time]);
                [videoData.frame] = frames{:};
                [videoData.latency] = latency{:};
                [videoData.time] = time{:};
                [videoData.file] = repmat(rootName,size(frames));            
                vidData{vidI} = videoData;
            else
                warning(['Video TTL marks start before recording...' ...
                     ' Cannot disambinguate recording timing...']);
                vidData{vidI} = [];
            end            
        end
    end % end video file loop
       
    for vidI = 1:length(vidFile)       
        if vidI == 1
            videoData = vidData{vidI};
        else
            videoData = [videoData vidData{vidI}];        
        end
    end
    
end % End of video file exist if statement


% Write video file to disk
disp('Writing Video Sync Table to Disk');
videoTable = struct2table(videoData);
writetable(videoTable,'videoSync.tsv',...
    'Delimiter','\t','filetype','text');
    


end % end parseVideo Function