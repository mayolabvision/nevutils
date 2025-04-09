function [oxy_trialstartinds] = getTrialMarkersOxy(nirs_data,nmarkers, deviceNum)
% extract trial markers for NIRS data. Trial markers are sent to the oxymon
%      - nirs_data: structure output of oxy2mat conversion
%      - nmarkers: expected number of trial markers
%      - nevfile: path/filename to nev (only opened if using portasync
%                method to extract trial markers)
%      - deviceNum: oxymon device number
%



% **************************************************************************** %
%                     Using Oxymon AD values for trial markers                 %
% **************************************************************************** %
    marker_chan = find(strcmp(nirs_data.ADlabel,['Oxymon AdChannels_0_id_' num2str(deviceNum)])); % channel w/ trial markers
    if ~isempty(marker_chan)
        oxypulse = nirs_data.ADvalues(:,marker_chan);
        oxypulse = oxypulse>0.5; % analog signal, turn the data into binary 0s and 1s
        [~,oxy_trialstartinds] = findpeaks(diff(oxypulse),'MinPeakHeight',0.5);
        %check that there are no missing trial starts
        if length(oxy_trialstartinds)~=nmarkers
            error(['# of trial markers in oxymon data (' num2str(length(oxy_trialstartinds)), ')'...
                ' does not match NEV (' num2str(nmarkers) ').']);
        end
    else
        error('Oxymon AdChannel 0 not found...');
    end



end