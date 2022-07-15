function dat = getNS5Data(dat,fn5all,varargin)
p = inputParser;
p.addOptional('dsEye',30,@isnumeric);
p.addOptional('dsDiode',1,@isnumeric);
p.addOptional('nsEpoch',[0 0],@isnumeric);
p.addOptional('fnStartTimes', 0, @isnumeric);
p.addOptional('allowpause', false, @islogical);
p.parse(varargin{:});
downsampleeye = p.Results.dsEye;
downsamplediode = p.Results.dsDiode;
nsEpoch = p.Results.nsEpoch;
fnStartTimes = p.Results.fnStartTimes;
allowpause = p.Results.allowpause;


DIODE_CHAN = 3;
EYE_CHAN = [1 2 4]; % eye X, eye Y, pupil diameter
PUPIL_CHAN = 4;

if ~iscell(fn5all)
    fn5all = {fn5all};
end

fnInd = 1;
fn5 = fn5all{fnInd};
datTimeShift = fnStartTimes(fnInd);

hdr5 = read_nsx(fn5,'readdata',false);
ns5Samp = double(hdr5.hdr.Fs);
fprintf('Found %d channels of NS5 data in %s.\n',hdr5.hdr.nChans,fn5);
clockFs = double(hdr5.hdr.clockFs);
tind = 1;
switchFiles = false;
appendDat = false;
extractNsxDataD = true;

while tind <= length(dat)
    epochStartTime = dat(tind).time(1) - nsEpoch(1) - datTimeShift;
    epochEndTime = dat(tind).time(2) + nsEpoch(2) - datTimeShift;

    nsEndTime = double(hdr5.hdr.timeStamps(end,end)) / clockFs;
    if epochEndTime > nsEndTime && epochStartTime < nsEndTime
        % this takes care of the file switch happening *within* a trial
        epochEndTime = nsEndTime;
        switchFiles = true;
        extractNsxData = true;
    elseif epochEndTime > nsEndTime && epochStartTime > nsEndTime
        % this handles the file switch happening *between* trials
        switchFiles = true;
        extractNsxData = false;
    else
        extractNsxData = true;
    end
    if extractNsxData
        if epochStartTime < 0
            epochStartTime = 0;
        end
        if epochEndTime > nsEndTime
            epochEndTime = nsEndTime;
        end
        msec = dat(tind).trialcodes(:,3);
        codes = dat(tind).trialcodes(:,2);
        codesamples = round(msec*ns5Samp);
        
        eyedata.codesamples = [codes codesamples];
        eyes = read_nsx(fn5,'chanindx',EYE_CHAN,'begsample',round(epochStartTime*ns5Samp),'endsample',round(epochEndTime*ns5Samp), 'allowpause', allowpause);
        if size(eyes.data, 2) > 1
            eyedata.trial = downsample(eyes.data',downsampleeye)';
        else
            eyedata.trial = eyes.data;
        end
        eyedata.startsample = codesamples(1)/downsampleeye;
        eyedata.dataFs = ns5Samp/downsampleeye;
        
        diode.codesamples = [codes codesamples];
        diodes = read_nsx(fn5,'chanindx',DIODE_CHAN,'begsample',round(epochStartTime*ns5Samp),'endsample',round(epochEndTime*ns5Samp), 'allowpause', allowpause);
        diode.trial = int16(downsample(diodes.data,downsamplediode));
        diode.startsample = codesamples(1)/downsamplediode;
        diode.dataFs = ns5Samp/downsamplediode;
        
        pupil.codesamples = [codes codesamples];
        pupils = read_nsx(fn5,'chanindx',PUPIL_CHAN,'begsample',round(epochStartTime*ns5Samp),'endsample',round(epochEndTime*ns5Samp), 'allowpause', allowpause);
        pupil.trial = int16(downsample(pupils.data,downsamplediode));
        pupil.startsample = codesamples(1)/downsamplediode;
        pupil.dataFs = ns5Samp/downsamplediode;
    

        if ~appendDat
            dat(tind).eyedata = eyedata;
            dat(tind).diode = diode;
            dat(tind).pupil = pupil;
            dat(tind).nsTime = (0:1:size(eyedata.trial,2)-1)./ns5Samp - nsEpoch(1);
        else
            % the trial at a file switch needs its data appended
            dat(tind).eyedata.trial = [dat(tind).eyedata.trial eyedata.trial];
            dat(tind).diode.trial = [dat(tind).diode.trial diode.trial];
            dat(tind).pupil.trial = [dat(tind).pupil.trial pupil.trial];
            dat(tind).nsTime = [dat(tind).nsTime (dat(tind).nsTime(end) + (1:1:size(eyedata.trial,2))./ns5Samp - nsEpoch(1))];
            appendDat = false;
        end
    end
    if switchFiles
        fnInd = fnInd + 1;
        fn5 = fn5all{fnInd};
        datTimeShift = fnStartTimes(fnInd);
        epochStartTime = epochStartTime - datTimeShift;
        epochEndTime = epochEndTime - datTimeShift;
        hdr5 = read_nsx(fn5,'readdata',false);
        ns5Samp = double(hdr5.hdr.Fs);
        fprintf('Found %d channels of NS5 data in %s.\n',hdr5.hdr.nChans,fn5);
        switchFiles = false;
        if extractNsxData
            appendDat = true;
        end
        disp('first epoch start')
        disp(dat(tind).time(1) - nsEpoch(1) - datTimeShift)
        disp('first epoch end')
        disp(dat(tind).time(2) - nsEpoch(2) - datTimeShift)
    else
        tind = tind+1;
    end
end
end