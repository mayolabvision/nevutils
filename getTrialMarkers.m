function [oxy_trialstartinds] = getTrialMarkers(nirs_data,nmarkers,nevfile, varargin)
% extract trial markers for NIRS data. Trial markers are typically sent to the oxymon
% and sometimes the TMSI system. A single portasync pulse is sent as a back up to
% both oxysoft and trellis.
%      - nirs_data: structure output of oxy2mat conversion
%      - nmarkers: expected number of trial markers
%      - nevfile: path/filename to nev (only opened if using portasync
%                method to extract trial markers)
%      - device4AD (optional): 'oxymon' (default), 'tmsi', 'portasync'
%      - portasyncPulse (optional): 2 element array, if different #s of portasync
%                                   pulses were sent to trellis and oxymon, this
%                                   indicates the pulse # to use for the alignment.
%                                   [pulse # in NEV, pulse # in NIRS]

p = inputParser;
p.addOptional('device4AD','oxymon', @(x) ismember(x,{'oxymon','tmsi','portasync'}));
p.addOptional('portasyncPulse',[1 , 1], @(x) isnumeric(x) & length(x)==2);
p.parse(varargin{:});
method = p.Results.device4AD;
portasyncPulse = p.Results.portasyncPulse;

tryTMSI_flag = 0; % flag to try TMSI if oxymon method fails
useNEV_flag = 0; % flag if the # of markers in Oxymon or TMSI don't match nmarkers

% **************************************************************************** %
%                     Using Oxymon AD values for trial markers                 %
% **************************************************************************** %
if strcmp(method,'oxymon')
    marker_chan = find(strcmp(nirs_data.ADlabel,'Oxymon AdChannels_0_id_10315')); % channel w/ trial markers
    if ~isempty(marker_chan)
        oxypulse = nirs_data.ADvalues(:,marker_chan);
        oxypulse = oxypulse>0.5; % analog signal, turn the data into binary 0s and 1s
        [~,oxy_trialstartinds] = findpeaks(diff(oxypulse),'MinPeakHeight',0.5);

        %check that there are no missing trial starts
        if length(oxy_trialstartinds)~=nmarkers
            warning(['# of trial markers in oxymon data (' num2str(length(oxy_trialstartinds)), ')'...
                ' does not match NEV (' num2str(nmarkers) '). ...trying TMSI markers...']);
            tryTMSI_flag = 1;
        end
    else
        warning('Oxymon AdChannel 0 not found, trying TMSI markers...');
        tryTMSI_flag = 1;
    end
end

% **************************************************************************** %
%                      Using TMSI AD values for trial markers                  %
% **************************************************************************** %
if strcmp(method,'tmsi') || tryTMSI_flag
    marker_chan = find(strcmp(nirs_data.ADlabel,'EEG: Digi')); % channel w/ trial markers
    if ~isempty(marker_chan)
        tmsipulse = nirs_data.ADvalues(:,marker_chan); % note: cleaner analog signal than oxymon pulses
        if tmsipulse(1)==0 % first point for AD values is an arbitrary 0 (assign to 255 so it doesn't effect peak finding)
            tmsipulse(1) = tmsipulse(2); 
        end
        [~,oxy_trialstartinds] = findpeaks(diff(-1*tmsipulse)); % tmsi signal is a negative pulse (255 baseline, pulse drops signal below baseline)

        %check that there are no missing trial starts
        if length(oxy_trialstartinds)~=nmarkers
            warning(['# of trial markers in tmsi data (' num2str(length(oxy_trialstartinds)), ')'...
                ' does not match NEV (' num2str(nmarkers) '). ...using portasync method...']);
            useNEV_flag = 1;
        end

    else
        warning('TMSI EEG digi channel not found, trying portasync alignment method...');
        useNEV_flag = 1;
    end
end

% **************************************************************************** %
% Using trial marker times from NEV (aligned to NIRS data via portasync pulse) %
% **************************************************************************** %
if strcmp(method,'portasync') || useNEV_flag
    nev = readNEV(nevfile);
    if sum(nev(:,1)==0 & nev(:,2)==1001)==0
        alignCode = 2; % FIX_ON code
    else
        alignCode = 1001; % special code sent with pulse
    end
    nev_starts = nev((nev(:,1)==0 & nev(:,2)==alignCode),3);
    portasync_nev = nev(nev(:,1)==0 & nev(:,2)==0,3); % portasync marker in NEV (chan 0, code 0)
    portasync_nev = portasync_nev(1:2:end); % only save rising edge time of marker

    portasync_chan = find(strcmp(nirs_data.ADlabel,'PortAd_Buttons')); % channel w/ portasync signal
    [~,portasync_inds] = findpeaks(diff(nirs_data.ADvalues(:,portasync_chan)),'MinPeakHeight',0.5);
    
    if isempty(portasync_inds) || isempty(portasync_nev)
        error('no portasync markers found');
    end

    if length(portasync_inds)~=length(portasync_nev)
        % this could occur if the portasync was sent before one of the
        % systems (either trellis or oxysoft) started recording
        warning(['# of portasync markers in NIRS data (' num2str(length(portasync_inds)), ')'...
            ' does not match NEV (' num2str(length(portasync_nev)) ')']);
        
        disp(['using #' num2str(portasyncPulse(1)) ' pulse in NEV and #' num2str(portasyncPulse(2)) ...
            ' pulse in NIRS']);
        
        portasync_inds = portasync_inds(portasyncPulse(2));
        portasync_nev = portasync_nev(portasyncPulse(1));
    end

    marker_dif = portasync_inds(1) - floor(portasync_nev(1)*nirs_data.Fs); % alignment b/w NEV and NIRS
    oxy_trialstartinds = floor(nev_starts*nirs_data.Fs) + marker_dif; % align NEV trial times w/ NIRS data
end


end