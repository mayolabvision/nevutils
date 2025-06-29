function [dat,hdr] = nev2dat(filename,varargin)
% nev2dat2ex
%% step1: nev -> dat
% [dat] = nev2dat(filename)
%
% required argument:
% filename: NEV file name, to read in 'nev'.
%
% optional arguments:
% 'readNS2' : default false, if true, read in 'ns2'.
%
% 'readNS5' : default false, if true, read in 'ns5'.
%
% 'convertEyes' : default false, if true, converts eye X/Y values to
% degrees.
%
% 'nsEpoch' : 2-element vector, with amount of time in seconds to pad each
% trial with. Default is [0 0]. If [1 2] is passed, then each trial's NS data will have an
% extra 1 s of samples before the '1' code and 2 s of samples after the
% '255' code.
%
% 'convertEyes' and 'nsEpoch' are valid only when 'readNS5' is true.
%
% other examples:
% [dat] = nev2dat(filename,'readNS2',true)
% [dat] = nev2dat(filename,'readNS2',true,'readNS5',true,'convertEyes',true,'nsEpoch',[1,2]);
%
%% step 2: dat -> ex
% ex = dat2ex(dat)
%
% required argument:
% dat: output of step 1
%
% optional arguments:
% 'alignCode': default is 1, if present, adjusts the times so that a time of 0
%  corresponds to the presence of the sort code given.  If more than one
%  instance of alignCode is found in the trial, the first is used.
%
% 'collapseConditions': default is false, if true, will throw all conditions together into one
%  cell (i.e., units X 1 X repeats).
%
% 'keepTrialCode': defaults to 5 (REWARD), the output will only include
%  trials that have this code. If a '1' is input then all trials are
%  returned
%

p = inputParser;
p.addOptional('readInterTrialData',false,@islogical);
p.addOptional('mode',false,@(x) islogical(x)||strcmp(x,'low')||strcmp(x,'high'));
p.addOptional('readNS2',false,@islogical);
p.addOptional('readNS5',false,@islogical);
p.addOptional('convertEyes',false,@islogical);
p.addOptional('convertEyesPix',false,@islogical);
p.addOptional('nsEpoch',[0 0],@isnumeric);
p.addOptional('dsEye',30,@isnumeric);
p.addOptional('dsDiode',1,@isnumeric);
p.addOptional('channelsGrab',1:400, @isnumeric);
p.addOptional('nevreadflag', false, @islogical);
p.addOptional('EYE_CHAN',[1 2 4],@isnumeric);
p.addOptional('PUPIL_CHAN',4,@isnumeric);
p.addOptional('DIODE_CHAN',3,@isnumeric);
p.addOptional('nevfilename', '', @(x) ischar(x) || iscell(x));
p.addOptional('ns2data', struct([]), @isstruct);
p.addOptional('fnStartTimes', 0, @isnumeric);
p.addOptional('allowNevPause', false, @islogical);
p.addOptional('include_0_255', false, @islogical);

p.parse(varargin{:});

readInterTrialData = p.Results.readInterTrialData;
mode = p.Results.mode;
readNS2 = p.Results.readNS2;
readNS5 = p.Results.readNS5;
convertEyes = p.Results.convertEyes;
convertEyesPix = p.Results.convertEyesPix;
nsEpoch = p.Results.nsEpoch;
dsEye = p.Results.dsEye;
EYE_CHAN = p.Results.EYE_CHAN;
PUPIL_CHAN = p.Results.PUPIL_CHAN;
DIODE_CHAN = p.Results.DIODE_CHAN;
dsDiode = p.Results.dsDiode;
channelsGrab = p.Results.channelsGrab;
nevreadflag = p.Results.nevreadflag;
nevfilename = p.Results.nevfilename;
ns2data = p.Results.ns2data;
fnStartTimes = p.Results.fnStartTimes;
allowNevPause = p.Results.allowNevPause;
include_0_255 = p.Results.include_0_255;

% addpath helpers
% optional args
nev_info = [];
assignopts (who, varargin);
%% important codes
starttrial = 1;
endtrial = 255;

if(strcmp(mode,'low'))
    readNS2 = false;
    readNS5 = true;
    convertEyes = true;
elseif(strcmp(mode,'high'))
    readNS2 = true;
    readNS5 = true;
    convertEyes = true;
end

dat = [];
hdr = [];

if nevreadflag ==1
    nev = filename;
else
    if ~contains(filename,'.nev')
        filename = [filename,'.nev'];
    end
    if exist(filename,'file') == 2
        nev = readNEV(filename);
        nev_info = NEV_displayheader(filename);
    else
        fprintf("File does not exist!\n");
        return;
    end
end

if nargout>1
    hdr = nev_info;
end

diginnevind = find(nev(:,1)==0);
if isempty(diginnevind)
    fprintf('No digital code, Nev to dat failed!\n');
    return
end
digcodes = nev(diginnevind,:);

channels = unique(nev(nev(:,1) ~= 0,1:2),'rows');
if ~include_0_255
    channels = channels(channels(:,2) ~= 0 & channels(:,2) ~= 255 & channels(:,1) ~= 0 & ismember(channels(:, 1), channelsGrab),:);
else
    channels = channels(channels(:,1) ~= 0 & ismember(channels(:, 1), channelsGrab),:);
end
%spikecodes = nev(nev(:,1)~=0,:);

trialstartindstemp = (find(digcodes(:,2)==starttrial));
trialstartinds = diginnevind(trialstartindstemp);
trialstarts = nev(trialstartinds,3);

trialendindstemp = (find(digcodes(:,2)==endtrial));
trialendinds = diginnevind(trialendindstemp);
trialends = nev(trialendinds,3);

if isempty(trialstarts) || isempty(trialends)
    warning(['there were no trial starts or trial ends in ' filename]);
    return;
end
[trialstarts, trialends,trialstartgood,trialendgood] = detectMissingStartEndCode(trialstarts,trialends);
trialstartinds = trialstartinds(trialstartgood);
trialendinds = trialendinds(trialendgood);

if length(trialstarts)~=length(trialends) || sum((trialends-trialstarts)<0)
    % fix it
    if sum(trialstarts(1:end-1)>=trialends)==0
        trialstarts = trialstarts(1:end-1);
    end
end

%% get session initial params
block = 1;
predatcodes = digcodes(digcodes(:,3)<trialstarts(1),:);
tempdata.text = char(predatcodes(predatcodes(:,2)>=256 & predatcodes(:,2)<512,2)-256)';
if ~isempty(tempdata.text)

    tempdata = getDatParams(tempdata);

    %% Make Struct
    for n = 1:length(trialstarts)
        if mod(n,100) == 0
            fprintf('Processed nev for %i trials of %i...\n',n,length(trialstarts));
        end
        dat(n).block = block;
        dat(n).channels = channels;
        dat(n).time = [trialstarts(n) trialends(n)];
        thisnev = nev(trialstartinds(n):trialendinds(n),:);
        trialdig = thisnev(thisnev(:,1)==0,:);
        tempspikes = thisnev(thisnev(:,1)~=0 & ismember(thisnev(:, 1:2), channels, 'rows'), :);
        tempspikes(:,3) = tempspikes(:,3)*30000;
        %tempspikes(:,3) = tempspikes(:,3);
        dat(n).text = char(trialdig(trialdig(:,2)>=256 & trialdig(:,2)<512,2)-256)';

        dat(n).trialcodes = trialdig(trialdig(:,2)<256 | (trialdig(:,2)>=1000 & trialdig(:,2)<=32000),:);
        trialdig(:,3) = trialdig(:,3)*30000;
        %dat(n).event = trialdig;
        dat(n).event = uint32(trialdig);
        if ~isempty(tempspikes)
            dat(n).firstspike = tempspikes(1,3);
        else
            dat(n).firstspike = [];
        end
        dat(n).spiketimesdiff = uint16(diff(tempspikes(:,3)));
        %dat(n).spiketimesdiff = diff(tempspikes(:,3));
        dat(n).spikeinfo = uint16(tempspikes(:,1:2));
        %dat(n).spikeinfo = tempspikes;
        dat(n).result = dat(n).event(dat(n).event(:,2)>=160 & dat(n).event(:,2)<=165,2);
        if isempty(dat(n).result)
            dat(n).result = dat(n).event(dat(n).event(:,2)>=150 & dat(n).event(:,2)<=158,2);
        end
        dat(n).params.block = tempdata.params.trial;
        if readInterTrialData
            dat(n).intertrialdata  = [];
        end
        if n<length(trialstarts) && trialstartinds(n+1)- trialendinds(n)>1
            bt = nev(trialendinds(n)+1:trialstartinds(n+1)-1,:);
            if readInterTrialData
                dat(n).intertrialdata = bt;
            end
            btdig = bt(bt(:,1)==0,:);
            if sum(find(btdig(:,2)>=256 & btdig(:,2)<512))> 0
                tempdata.text = char(btdig(btdig(:,2)>=256 & btdig(:,2)<512,2)-256)';
                tempdata = getDatParams(tempdata);
                block = block + 1;
            end
        end

        if ~isempty(nev_info)
            dat(n).nevinfo.nevclockstart = nev_info.nevclockstart;
        end

        if(isempty(dat(n).result))
            dat(n).result = NaN;
        end
    end
    dat = getDatParams(dat);

    if readNS2
        if ~isempty(ns2data)
            fn2 = ns2data;
            dat = getNS2Data(dat,fn2,'nsEpoch',nsEpoch);
        else
            if nevreadflag
                filename = nevfilename;
            end
            fn2  = replace(filename,'.nev','.ns2');
            if ~exist(fn2,'file')
                fprintf('ns2 file does not exist!\n');
            else
               dat = getNS2Data(dat,fn2,'nsEpoch',nsEpoch);
            end
        end
    end

    if readNS5
        if nevreadflag
            filename = nevfilename;
        end
        if iscell(filename)
            fn5  = cellfun(@(fn) replace(fn,'.nev','.ns5'), filename, 'uni', 0);
            if any(cellfun(@(fn) ~exist(fn,'file'), fn5))
                fprintf('one of the ns5 files does not exist!\n');
                readNS5 = true;
            end
        else
            fn5  = replace(filename,'.nev','.ns5');
            if ~exist(fn5,'file')
                fprintf('ns5 file does not exist!\n');
                fprintf('ns5 file does not exist!\n');
            end
        end
        if readNS5
            dat = getNS5Data(dat,fn5,'nsEpoch',nsEpoch,'dsEye',dsEye,'dsDiode',dsDiode,'fnStartTimes', fnStartTimes,'allowpause',allowNevPause,'EYE_CHAN',EYE_CHAN,'PUPIL_CHAN',PUPIL_CHAN,'DIODE_CHAN',DIODE_CHAN);
            if convertEyes
                for n = 1:length(dat)
                    %disp(size(dat(n).eyedata.trial))
                    %disp(dat(n).eyedata.trial(:, 1))
                    %disp(n)
                    %if size(dat(n).eyedata.trial, 1) == 2
                    [eyedeg, eyepix] = eye2deg(dat(n).eyedata.trial(1:2,:),dat(n).params);
                    if convertEyesPix
                        dat(n).eyedata.trial(1:2,:) = eyepix;
                    else
                        dat(n).eyedata.trial(1:2,:) = eyedeg;
                    end
                    %end
                end
            end
        end
    end
end
end
