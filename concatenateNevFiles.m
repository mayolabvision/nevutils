function [dat] = concatenateNevFiles(nevFiles,varargin)
% nevFiles- cell array of nevFile names to be concatenated
% optional inputs:
% nasFlag- sort with nasnet
% useClockStart- use nip clock time (nevclockstart) or time2 (UTC time)
% all other optionals match nev2dat
p = inputParser;
p.addOptional('nasFlag',false,@islogical);
p.addOptional('gammaVal',0.2,@isnumeric);
p.addOptional('netname','UberNet_N50_L1',@ischar);
p.addOptional('netFolder','../networks',@ischar);
p.addOptional('useClockStart',false,@islogical);
p.addOptional('readNS2',false,@islogical);
p.addOptional('readNS5',false,@islogical);
p.addOptional('convertEyes',false,@islogical);
p.addOptional('convertEyesPix',false,@islogical);
p.addOptional('nsEpoch',[0 0],@isnumeric);
p.addOptional('dsEye',30,@isnumeric);
p.addOptional('dsDiode',1,@isnumeric);
p.addOptional('channelsGrab',1:400, @isnumeric);
p.addOptional('nevreadflag', false, @islogical);
p.addOptional('ns2data', struct([]), @isstruct);
p.addOptional('allowNevPause', false, @islogical);
p.addOptional('include_0_255', false, @islogical);

p.parse(varargin{:});
nasFlag = p.Results.nasFlag;
gammaVal = p.Results.gammaVal;
netname = p.Results.netname;
netFolder = p.Results.netFolder;
useClockStart = p.Results.useClockStart;
readNS2 = p.Results.readNS2;
readNS5 = p.Results.readNS5;
convertEyes = p.Results.convertEyes;
convertEyesPix = p.Results.convertEyesPix;
nsEpoch = p.Results.nsEpoch;
dsEye = p.Results.dsEye;
dsDiode = p.Results.dsDiode;
channelsGrab = p.Results.channelsGrab;
nevreadflag = p.Results.nevreadflag;
ns2data = p.Results.ns2data;
allowNevPause = p.Results.allowNevPause;
include_0_255 = p.Results.include_0_255;



dat = [];
sf = 30000;
for nevInd = 1:length(nevFiles)
    nevHeader = NEV_displayheader(nevFiles{nevInd});
    timeUTC = nevHeader.hour*3600 + nevHeader.minute*60 + nevHeader.second + nevHeader.millisec/1000;
    timeEST = timeUTC - 5*3600; if timeEST<0, timeEST= timeEST+24*3600; end 
    if useClockStart 
        nevTime = nevHeader.nevclockstart;
    else
        nevTime = round(timeEST*sf);
    end
    if(nevInd == 1)
        initialclockstart = nevTime;
    end
    startOffset = (nevTime - initialclockstart)./sf;

    if nasFlag
    	[~, nevOutCurr,~] = runNASNet(nevFiles{nevInd}, gammaVal,'netname', netname, 'netFolder', netFolder);
        nevInput = nevOutCurr;
        nevreadflag = true;
    else
        nevInput = nevFiles{nevInd};
    end
    
    datCurrent = nev2dat(nevInput,'nevreadflag',nevreadflag,'nevfilename',nevFiles{nevInd},...
                'readNS5', readNS5, 'dsEye',dsEye,'convertEyes',convertEyes,'convertEyesPix',convertEyesPix, 'dsDiode',dsDiode,...
                'readNS2',readNS2,'ns2data',ns2data,'nsEpoch',nsEpoch,...
                'include_0_255',include_0_255,'allowNevPause',allowNevPause,'channelsGrab',channelsGrab);

    for i=1:length(datCurrent)
        datCurrent(i).time = datCurrent(i).time+startOffset;
        datCurrent(i).fileStartTime = timeEST;
    end
    dat = [dat,datCurrent];
end

end