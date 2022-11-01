function dat = getNIRSData(dat,fnNIRS, nevfilename,varargin)
%      - fnNIRS: filename or nirs_data structure
%      - dsNIRS: fnew = fs/dsNIRS
%      - nirsEpoch: 2-element vector, with amount of time in seconds to pad each
%                   trial with. Default is [0 0]. If [1 2] is passed, then each
%                   trial will have an extra 1 s of samples before the '1' code
%                   and 2 s of samples after the '255' code.
%      - nirsreadflag: if true input is nirs_data structure not filename
%      - device4AD (optional): 'oxymon' (default), 'tmsi', 'portasync'
%      - portasyncPulse (optional): 2 element array, if different #s of portasync
%                                   pulses were sent to trellis and oxymon, this
%                                   indicates the pulse # to use for the alignment.
%                                   [pulse # in NEV, pulse # in NIRS]


p = inputParser;
p.addOptional('dsNIRS',1, @isnumeric);
p.addOptional('nirsEpoch',[0 0], @isnumeric);
p.addOptional('device4AD','oxymon', @(x) ismember(x,{'oxymon','tmsi','portasync'}));
p.addOptional('portasyncPulse',[1 , 1], @(x) isnumeric(x) & length(x)==2);
p.parse(varargin{:});
downsamplenirs = p.Results.dsNIRS;
nirsEpoch = p.Results.nirsEpoch;
device4AD = p.Results.device4AD;
portasyncPulse = p.Results.portasyncPulse;

if isstruct(fnNIRS)
    nirs_data = fnNIRS;
else
    load(fnNIRS,'nirs_data'); % nirs_data structure
    if ~exist('nirs_data','var')
        error('nirs file does not contain nirs_data structure')
    end
end

nirsSamp = nirs_data.Fs;

if isfield(nirs_data,'OD') % optical density data
    dataType = 'OD';
elseif isfield(nirs_data,'oxyvals') % oxy/dxy converted data
    dataType = 'oxyvals';
else
    error('nirs_data must contain OD or oxyvals');
end

nirsEndInd = size(nirs_data.(dataType),1);
% get trial markers in NIRS data
if isfield(nirs_data,'oxy_trialstartinds')
    oxy_trialstartinds = nirs_data.oxy_trialstartinds;
else
    oxy_trialstartinds = getTrialMarkers(nirs_data,length(dat), nevfilename, 'device4AD',device4AD, 'portasyncPulse',portasyncPulse);
end
% epoch nirs data
for tind = 1:length(dat)
    nirsdata = [];
    if mod(tind,100) == 0
        fprintf('Processed nirs for %i trials of %i...\n',tind,length(dat));
    end

    epochStartInd = oxy_trialstartinds(tind) - (nirsEpoch(1)*nirsSamp);

    %use length of trial in dat to determine # of samples to include in NIRS data
    trial_length = dat(tind).time(2) - dat(tind).time(1); % trial length in seconds

    epochEndInd = oxy_trialstartinds(tind) + floor((trial_length + nirsEpoch(2))*nirsSamp);

    if epochStartInd < 1
        epochStartInd = 1;
    end
    if epochEndInd > nirsEndInd
        epochEndInd = nirsEndInd;
    end

    msec = dat(tind).trialcodes(:,3); % time that trial codes occurred in NEV
    codes = dat(tind).trialcodes(:,2);
    codesamples = round(msec*nirsSamp); % sample that trial codes occurred in NEV

    % convert codesamples from samples in NEV to samples in NIRS data
    codesamples = oxy_trialstartinds(tind) + (codesamples - codesamples(1));
    nirsdata.codesamples = [codes codesamples];

    % downsample nirs data
    if strcmp(dataType,'OD')
        nirsOD = nirs_data.OD(epochStartInd:epochEndInd,:);
        for chan = 1:size(nirsOD,2) % smooth only operates on a vector
            nirsdata.OD(:,chan) = downsample(smooth(nirsOD(:,chan), downsamplenirs),downsamplenirs);
        end

        nirsdata.ODlabel = nirs_data.ODlabel;
        nsamples = size(nirsdata.OD,1);
    else
        nirsOxy = nirs_data.oxyvals(epochStartInd:epochEndInd,:);
        nirsDxy = nirs_data.dxyvals(epochStartInd:epochEndInd,:);
        for chan = 1:size(nirsOxy,2)
            nirsdata.oxyvals(:,chan) = downsample(smooth(nirsOxy(:,chan), downsamplenirs),downsamplenirs);
            nirsdata.dxyvals(:,chan) = downsample(smooth(nirsDxy(:,chan), downsamplenirs),downsamplenirs);
        end

        nsamples = size(nirsdata.trialOxy,1);
    end

    nirsdata.startsample = floor(codesamples(1)/downsamplenirs);
    nirsdata.dataFs = nirsSamp/downsamplenirs;
    nirsdata.codesamples(:,2) = floor(nirsdata.codesamples(:,2)/downsamplenirs);
    
    nirsdata.channels = nirs_data.label;
    nirsdata.DPF = nirs_data.DPF;
    nirsdata.distance = nirs_data.distance;
    nirsdata.wavelengths = nirs_data.wavelengths;

    dat(tind).nirsdata = nirsdata;
    dat(tind).nirsTime = (0:1:nsamples-1)./nirsdata.dataFs - nirsEpoch(1);

end


end