function jsonStruct = exportMatProbe2Json(probe,fName)
% Exports my matlab probes (electrodes) to ProbeInterface's json format
% Mine are an expanded version of Kilosorts struct 

nChans = length(probe.chanMap);

% Create highest level struct
jsonStruct = struct('specification','probeinterface','version','0.2.21',...
                    'probes',[]);

% Create probe struct
% Size and units
probes.ndim = 2;
probes.si_units = 'um';
% Probe info
probes.annotations = struct('name',probe.name,'manufacturer',...
                     probe.manufacturer,'first_index',1);
% Contact info
probes.contact_annotations.contact_type = probe.SiteType';

% Location
probes.contact_positions = [probe.xcoords(:) probe.ycoords(:)];

% Axes - Not sure I fully get this
for j = 1:nChans
    probes.contact_plane_axes(j,:,:) = [1 0; 0 1];
end

% shapes
probes.contact_shapes       = probe.shape';
probes.contact_shape_params = probe.shape_params';
% IDs
probes.contact_ids = probe.chanMap';
probes.shank_ids   = probe.Shank';
probes.device_channel_indices = (probe.Number-1)';


jsonStruct.probes = {probes};



%% Export here

if nargin < 2
    fName = [probe.name '.json'];
end
% If file name is not specified output in current path
fid = fopen(fName,'w');
encodedJson = jsonencode(jsonStruct, "PrettyPrint", true);
fprintf(fid, encodedJson);
fclose(fid);
