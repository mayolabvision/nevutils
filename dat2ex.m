function ex = dat2ex(dat,varargin)
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
%% optional input arguments
p = inputParser;
p.addOptional('alignCode',1,@isscalar);
p.addOptional('keepTrialCode',5,@isscalar);
p.addOptional('collapseConditions',false,@islogical);

p.parse(varargin{:});

alignCode = p.Results.alignCode;
keepTrialCode = p.Results.keepTrialCode;
collapseConditions = p.Results.collapseConditions;

readDiode = isfield(dat,'diode');
readLFP = isfield(dat,'lfp');
readEyes = isfield(dat,'eyedata');

%% save some important values
START_TRIAL = 1;
END_TRIAL = 255;

% warn if multiple instances of the align code are found in a trial
warnAlignFlag = 0;

% number of trials to read before printing message

% Channel defaults
EYE_CHAN = [1 2 4]; % eye X, eye Y, pupil diameter
if readLFP
    lfpChan = dat(1).lfp.chan;
end
% setup a default keep code. Could use '1' here if the default is to keep
% all trials
if isempty(keepTrialCode)
    keepTrialCode = 5; % this is the REWARD code, could also use CORRECT which is 150
end

if alignCode ~= 1
    alignFlag = 1;
else
    alignFlag = 0;
end


for i = 1:length(dat)
    trial = dat(i);
    trial.spikeinfo = unpackSpikes(trial.spikeinfo,trial.spiketimesdiff,trial.firstspike,30000);
    trial.event = double(trial.event);
    cndIndex = find(trial.event(:,2)>32768,1);
    if collapseConditions % throw all conditions into one cell, or separate them
        trial.cnd = 1;
    else
        trial.cnd = trial.event(cndIndex,2)-32768;
    end
    trial.event(cndIndex,:) = [];    
    trial.event = double(trial.event(:,2:3));
    %trial.event(:,2) = trial.event(:,2)./30000;    
    trial.spikeinfo = double(trial.spikeinfo);
    trials{i} = trial;
end
trials = cell2mat(trials);
cndlist = arrayfun(@(x) x.cnd,trials);
cnds = double(unique(cndlist));

% find trials with the keepTrialCode (usually '5' for REWARD)
goodtrials = arrayfun(@(x) sum(x.event(:,1) == keepTrialCode)>0,trials);

% find trials with both a start and an end - this could be optional if we 
% wanted to rescue them somehow. For now we just delete the incomplete trials
started = arrayfun(@(x) sum(x.event(:,1) == START_TRIAL)>0,trials);
ended = arrayfun(@(x) sum(x.event(:,1) == END_TRIAL)>0,trials);
completed = started + ended - 1;
completed(completed<0) = 0;

% only include completed trials in the good trials list
%goodtrials = logical(goodtrials .* completed);

%% Fill up cell arrays of trial data
EVENTS = cell(size(trials(1).channels,1),max(cnds),1);
MSGS = cell(max(cnds),1);
NSTIME = cell(max(cnds),1);
if readDiode
    DIODE = cell(max(cnds),1);
end
if readEyes
    EYES = cell(numel(EYE_CHAN),max(cnds),1);
end
if readLFP
    LFP = cell(numel(lfpChan),max(cnds),1);
end
CODES = cell(max(cnds),1);
ENV = cell(max(cnds),1);

% find all the codes sent between trials and put them in 'params'
% This is wildly inefficient, it's a kludge to make sure you can reference
% the parameters easily from each trial. We could improve this - MATT
preTrial = cell(0);
lastEnd = 0;
params = struct();
for i = 1:length(trials)
    tri = trials(i);
    preCodes = tri.event(tri.event(:,2) > lastEnd & tri.event(:,2) < tri.time(1),1);
    preTrial{i} = char(preCodes(preCodes >= 256 & preCodes < 512) - 256)';
    if ~isempty(preCodes)
%         disp(['Trial # ',num2str(i),' preceded by digital codes']);
        %disp(preTrial{i});
    end
    variables = regexp(preTrial{i},';','split');
    for j = 1:length(variables)
        k = strfind(variables{j},'=');
        if k            
            lhs = variables{j}(1:k-1);
            rhs = variables{j}(k+1:end);
            % MATT - should we check here to see if any value has
            % changed and report back if it has?
            try
                eval(['params.' lhs '=[' rhs '];']);
            catch
                eval(['params.' lhs '=''' rhs ''';']);
            end
        end
    end
    % put all the params into the trials struct
    trials(i).params.block = catstruct(params,trials(i).params.block);    
    
    lastEnd = tri.time(2);
end

% This is a stupid hack to make eye2deg work later
params.block = params;

%% Align each trial's spikeinfo and codes, then store in the cell arrays
for i = 1:max(cnds)
    
    % status message
    disp(['Converting trials for condition ',num2str(i),' of ',num2str(max(cnds))]);
    
    theseTrials = trials(cndlist==i & goodtrials);
    
    for j = 1:length(theseTrials)
        if alignFlag
            if alignCode < 0 % alignCode -1 was used to align to diode
                error('dat2ex no longer supports aligning on the diode');
            else
                if (numel(alignCode)==1)
                    alignTime = theseTrials(j).event(theseTrials(j).event(:,1) == alignCode,2);
                elseif (numel(alignCode)>=1)
                    codestr=num2str(theseTrials(j).event(:,1)');
                    patstr = [];
                    for I=1:length(alignCode)-1
                        patstr = [patstr,num2str(alignCode(I)),' \s '];
                    end
                    patstr = [patstr,num2str(alignCode(I+1))];
                    idx = regexp(codestr,patstr,'start');
                    alignTime = 0;
                end
                if isempty(alignTime)
                    fprintf(['Repeat %i of condition %i does not ' ...
                                  'have align code %i'],j,i, ...
                                 alignCode);
                    alignTime = 0;
                elseif length(alignTime) > 1
                    if ~warnAlignFlag
                        fprintf(['Repeat %i of condition %i has ' ...
                                      '%i occurrences of align code %i ' ...
                                      '- using 1st occurrence'],j,i, ...
                                     length(alignTime),alignCode);
                        disp('No more warnings of this type will be displayed');
                        warnAlignFlag = 1;
                    end
                    alignTime = alignTime(1);
                end
            end
        else
            alignTime = 0;
        end % of alignment

        % put the spikes into the right spot
        for k = 1:size(theseTrials(j).channels,1)
            valid = theseTrials(j).spikeinfo(:,1) == theseTrials(j).channels(k,1) ...
                        & theseTrials(j).spikeinfo(:,2) == theseTrials(j).channels(k,2);
                 
            EVENTS{k,i,j} = theseTrials(j).spikeinfo(valid,3) - alignTime;
        end

        CODES{i,j} = theseTrials(j).event;
        CODES{i,j}(:,2) = CODES{i,j}(:,2) - alignTime;
        MSGS{i,j} = theseTrials(j).text;
        ENV{i,j} = theseTrials(j).params.block;
        
        if readDiode
            DIODE{i,j} = double(theseTrials(j).diode.trial);
        end
        if readEyes
            eyedat = theseTrials(j).eyedata.trial;
%             if convertEyes % make the X/Y in deg vis angle
%                 eyedat(1:2,:) = eye2deg(eyedat(1:2,:),params);
%             end
            for k = 1:numel(EYE_CHAN)
                EYES{k,i,j} = eyedat(k,:);
            end
        end
        if readLFP
            lfp = theseTrials(j).lfp.trial;
            for k = 1:numel(lfpChan)
                LFP{k,i,j} = lfp(k,:);
            end
        end
        
        if readDiode || readEyes || readLFP
            NSTIME{i,j} = theseTrials(j).nsTime-alignTime;            
        end
    end
end

%% Put all the data into the ex struct for output
ex = struct();
ex.EVENTS = EVENTS;
if readDiode
    ex.DIODE = DIODE;
end
if readEyes
    ex.EYES = EYES;
end
if readLFP
    ex.LFP = LFP;
    ex.LFPCHANNELS = lfpChan;
end
if readDiode || readEyes || readLFP
    ex.NSTIME = NSTIME;
end

ex.MSGS = MSGS;
ex.CODES = CODES;
ex.CHANNELS = trials(1).channels;
ex.TRIAL_SEQUENCE = double(cndlist(goodtrials))';
ex.REPEATS = hist(ex.TRIAL_SEQUENCE,1:max(cnds));
ex.PRE_TRIAL = preTrial(goodtrials);
ex.ENV = ENV;
