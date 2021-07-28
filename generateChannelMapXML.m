function generateChannelMapXML(electrode, filepath)
% Takes an electrode struct (created with generateChannelMap function) and
% creates a .xml file that will work with RHX software as a channel map.

if nargin < 2
    filepath = pwd;
end

fileName = [electrode.name '.xml'];

fullPath = [filepath filesep fileName];

fid = fopen(fullPath,'w+');

%% Write file header and initial lines of code

% XMl definition
fprintf(fid, '<?xml version="1.0"?>');
fprintf(fid, '\n');

% RHX settings definition
fprintf(fid, '<IntanRHX version="3.0.3" type="ControllerRecordUSB3" sampleRate="20 kHz">');
fprintf(fid, '\n');

% Probe settings definition
fprintf(fid, ' <ProbeMapSettings backgroundColor="Black">');
fprintf(fid, '\n');

% Page definition
fprintf(fid, '  <Page name="Shanks">');
fprintf(fid, '\n');
fprintf(fid, '\n');

% % Lines for each shank
% % Shank 1
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% 
% % Shank 2
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% 
% % Shank 3
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% 
% % Shank 4
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% 
% % Shank 5
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% 
% % Shank 6
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% 
% % Shank 7
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% 
% % Shank 8
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');
% fprintf(fid, '   <Line x1="40" x2="40" y1="20" y2="220"/>/n');

ports = unique(electrode.Connector);
portLabels = {'A','B','C','D','E','F','G','H'};

for portI = 1:length(ports)

    portText = ['   <Port name="' portLabels{ports(portI)} '" siteShape="Ellipse" siteWidth="6" siteHeight="6">\n'];
    fprintf(fid, portText);

    portSites = find(electrode.Connector == ports(portI));

    for siteI = 1:length(portSites)
        
    chanNum =  electrode.Intan(portSites(siteI)) - (length(portSites) .* (portI-1));
        
    siteText = ['    <ElectrodeSite channelNumber="' num2str(chanNum) ...
                '" x="' num2str(electrode.xcoords(portSites(siteI))) ...
                '" y="' num2str(electrode.ycoords(portSites(siteI))) ...
                '"/>\n'];
    fprintf(fid, siteText);
            
        
        
    end % end site loop
        
    fprintf(fid, '   </Port>\n\n');
end % End port loop


% End text
fprintf(fid, '  </Page>\n');
fprintf(fid, ' </ProbeMapSettings>\n');
fprintf(fid, '</IntanRHX>'); 

fclose(fid);



end % End generateChannelMapXML
    