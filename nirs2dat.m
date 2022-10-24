function dat = nirs2dat(dat,filename,varargin)
% - nirsdata: input nirs_data structure, allows for preprocessing (i.e. filtering of
%   NIRS data or mbll)to occur before epoching into dat structure
p = inputParser;
p.addOptional('readNIRS',false, @islogical);
p.addOptional('dsNIRS',1, @isnumeric);
p.addOptional('nirsEpoch',[0 0], @isnumeric);
p.addOptional('nirsdata',struct([]), @isstruct);
p.addOptional('device4AD','oxymon', @(x) ismember(x,{'oxymon','tmsi','portasync'}));
p.addOptional('portasyncPulse',[1 , 1], @(x) isnumeric(x) & length(x)==2);
p.parse(varargin{:});
readNIRS = p.Results.readNIRS;
dsNIRS = p.Results.dsNIRS;
nirsEpoch = p.Results.nirsEpoch;
nirsdata = p.Results.nirsdata;
device4AD = p.Results.device4AD;
portasyncPulse = p.Results.portasyncPulse;

if readNIRS
    existFlag = true;
    if ~isempty(nirsdata)
        fnNIRS = nirsdata;
    else
        if nevreadflag
            filename = nevfilename;
        end
        fnNIRS  = replace(filename,'.nev',['_' nirsType ,'.mat']);
        if ~exist(fnNIRS,'file')
            fprintf('NIRS file does not exist!\n');
            existFlag = false;
        end
    end
    if existFlag
        dat =  getNIRSData(dat,fnNIRS, filename, 'dsNIRS',dsNIRS,'nirsEpoch',nirsEpoch,...
              'device4AD', device4AD,'portasyncPulse',portasyncPulse);
    end
end
end
