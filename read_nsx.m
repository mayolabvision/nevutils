function out = read_nsx(filename,varargin)
%function out = read_nsx(filename,varargin)
%
% Based on Ripple's NSX2MAT function - should read any NSX file
%
% Reformatted to be compatible with FieldTrip -ACS (adam@adamcsnyder.com)
%
% Can specify 'begsample', 'endsample', 'chanindx', 'readdata' as varargin
%

%% Ignore MATLAB's complaints about code optimization:
%#ok<*NASGU>
%#ok<*AGROW>
%% optional input arguments

p = inputParser;
p.addRequired('filename',@ischar);
p.addOptional('begsample',1,@isscalar);
p.addOptional('endsample',-1,@isscalar);
p.addOptional('chanindx',-1,@isnumeric);
p.addOptional('readdata',true,@islogical);
p.addOptional('keepint',false,@islogical);
p.addOptional('allowpause',false,@islogical);

p.parse(filename,varargin{:});

begsample = p.Results.begsample;
endsample = p.Results.endsample;
chanindx = p.Results.chanindx;
readdata = p.Results.readdata;
keepint = p.Results.keepint;
allowpause = p.Results.allowpause;

packetHeaderBytes = 9;
%% open file
fh   = fopen(filename, 'rb','n','UTF-8');
%% get file size
fseek(fh, 0, 1);
filesize = ftell(fh);
fseek(fh, 0, -1);
%% check if valid nsx 2.2 file
fid  = fread(fh, 8, '*char')';
if ~strcmp(fid, 'NEURALCD') %note: <-might use this for ft_filetype
    error('Not Valid NSx 2.2 file');
end
fseek(fh, 2, 0); %skip file spec
%% get bytes in headers (used to jump to begining of data)
bytesInHeaders = fread(fh, 1, '*uint32');
%% get label
label          = fread(fh, 16, '*char')'; 
fseek(fh, 256, 0);
%% get sampling frequency
period         = fread(fh, 1, '*uint32');
fs             = 30000/period; % samples per second
clockFs        = fread(fh, 1, '*uint32');
timeOrigin     = fread(fh, 8, 'uint16=>double');
dateVector = timeOrigin([1,2,4,5,6,7]); %ignore third value of timeOrigin (dayOfWeek)
dateVector(end) = dateVector(end)+timeOrigin(end)./1000; %add milliseconds
timeOrigin = datestr(dateVector(:)','dd-mmm-yyyy HH:MM:SS.FFF');

%% get channel list, unit, and scale
chanCount      = fread(fh, 1, '*uint32');
scale          = zeros(chanCount,1);
channelID      = int16(scale);
fseek(fh, 2, 0);
for i = 1:chanCount
    channelID(i) = fread(fh, 1, '*uint16');
    fseek(fh, 18, 0);
    minD         = fread(fh, 1, 'int16');
    maxD         = fread(fh, 1, 'int16');
    minA         = fread(fh, 1, 'int16');
    maxA         = fread(fh, 1, 'int16');
    unit(i)      = {deblank(fread(fh, 16, '*char')')}; 
    scale(i)        = (maxA - minA)/(maxD - minD);  
    fseek(fh, 22, 0);
end
chanLabels = cellfun(@num2str,num2cell(double(channelID)),'uniformoutput',0);
fseek(fh, bytesInHeaders,-1);
%% get time vector
k              = 1;
while (filesize-ftell(fh))>packetHeaderBytes %changed from while ftell<filesize to handle interrupted/corrupted files more smoothly... -ACS 01oct2014
    header         = fread(fh, 1); 
    timeStamp(k)   = fread(fh, 1, '*uint32');
    ndataPoints(k) = fread(fh, 1, '*uint32');   
    if ndataPoints(k)==0 %indicates that file writing was interrupted -ACS 18Dec2013
        warning('read_nsx:fileInterrupted','It appears that file %s was interrupted during writing. Data recovery will be attempted, but inspect carefully.',filename);
        currentByte = ftell(fh);
        remainingBytes = filesize-currentByte; %This should be right, but I might need a +1 or a -1 or something... -ACS
        ndataPoints(k) = uint32(floor(0.5.*remainingBytes./double(chanCount))); 
    end
    status = fseek(fh,(2*double(ndataPoints(k))*double(chanCount)),0);
    if status<0 %tried to seek past EOF, indicates corrupted file
        warning('read_nsx:fileCorrupted','Corrupted file %s has invalid packet information. Data recovery will be attempted, but inspect carefully.',filename);
        fseek(fh,bytesInHeaders+packetHeaderBytes,-1); %go back to the beginning        
        remainingBytes = filesize-(double(bytesInHeaders)+packetHeaderBytes); %This should be right, but I might need a +1 or a -1 or something... -ACS
        ndataPoints = uint32(floor(0.5.*remainingBytes./double(chanCount)));  %note that only one packet is represented
        timeStamp = timeStamp(1); %just keep the first time stamp
        break
    else
        k = k + 1;
    end
end
time               = [timeStamp; timeStamp + ndataPoints.*period]; %changed to ndataPoints.*period. 'timeStamp' was in units of the clock frequency, but ndataPoints was in the data frequency. -ACS 08Nov2012
%% get data vectors
nvec           = double(cumsum(double(ndataPoints)));
if readdata
    nvec           = [0, nvec];
    puntForPauses = endsample>0;
    if endsample<0
        endsample=nvec(end);
    end
    data           = zeros(chanCount, endsample-begsample+1, 'int16');
    if any(chanindx<0),chanindx=1:chanCount;end
    fseek(fh, bytesInHeaders, -1);
    % number of samples to skip can't go below 0 (i.e. make sure we can keep the first data point!)
    bytes2skip = max((begsample-1)*2*double(chanCount), 0); %this should be the number of data samples to skip... -ACS 09May2012 %-re-casted chanCount as double to avoid misreading huge files -ACS 16Jun2015
    bytes2skip = bytes2skip+packetHeaderBytes*sum(begsample>nvec); %this should add on the little headers before each data block... -ACS
    fseek(fh, bytes2skip, 0); %The initial bytes to skip
    % changed >= begsample to > begsample to account for reading from the very start... I think that's correct? --ESC
    dataBlockBounds = nvec>begsample&nvec<endsample; %pretty sure these are the right booleans here... -ACS
    if length(dataBlockBounds) == 2 % under normal circumstances (no pause), we should only have two points--the beginning and end of file
        if ~any(dataBlockBounds) %if there are no block boundaries in the requested data segment
            %just pull out the block of data:
            data = fread(fh,[chanCount,endsample-begsample+1],'*int16');
        elseif ~puntForPauses %if there are block boundaries in the requested data segment %...and a specific 'trial' wasn't requested -ACS 19Dec2013
            endByte = 9*sum(dataBlockBounds)+(endsample*2*chanCount); %this should be the position of the last requested sample in the file... -ACS
            currentSample = begsample;
            dataInd = 1;
            while ftell(fh)<endByte
                nextBound = nvec(find(nvec>currentSample,1,'first'));
                nextBound = min(nextBound,endsample);
                data(:,dataInd:nextBound-currentSample+dataInd) = fread(fh,[chanCount,nextBound-currentSample+1],'*int16');
                dataInd = nextBound-currentSample+dataInd+1;
                currentSample = nextBound+1;
                if ftell(fh)<(filesize-9)
                    fseek(fh,9,0); %skip the little header for the next data block
                end
            end
        else
            % in case I'm wrong about 'normal circumstances' making dataBlockBounds be only two points
            error('read_nsx:pauseInRequestedTrial','The NSX file %s was paused during the requested data segment (samples %d to samples %d), which is an error.',filename,begsample,endsample);
        end
    else
        if ~puntForPauses %if there are block boundaries in the requested data segment %...and a specific 'trial' wasn't requested -ACS 19Dec2013
            % keeping this here retains prior functionality for requesting the entire datafile but not aligning to trials
            endByte = 9*sum(dataBlockBounds)+(endsample*2*chanCount); %this should be the position of the last requested sample in the file... -ACS
            currentSample = begsample;
            dataInd = 1;
            while ftell(fh)<endByte
                nextBound = nvec(find(nvec>currentSample,1,'first'));
                nextBound = min(nextBound,endsample);
                data(:,dataInd:nextBound-currentSample+dataInd) = fread(fh,[chanCount,nextBound-currentSample+1],'*int16');
                dataInd = nextBound-currentSample+dataInd+1;
                currentSample = nextBound+1;
                if ftell(fh)<(filesize-9)
                    fseek(fh,9,0); %skip the little header for the next data block
                end
            end
        elseif ~allowpause
            error('read_nsx:pauseInRequestedTrial','The NSX file %s was paused during the requested data segment (samples %d to samples %d), which is an error.',filename,begsample,endsample);
        else
            % here, there was a pause *during* the trial (and we're allowing pauses)
            data           = [];
            % gotta redo file location in real time here, because there was a pause
            timeInSamples = time ./ period;
            dataBlockBoundsBeforeEndInRealTime = timeInSamples(2, :)<endsample;
            dataBlockRealTimeBlanks = timeInSamples(1,2:end)-timeInSamples(2,1:end-1);
            endsampleInSamples = endsample - sum(dataBlockRealTimeBlanks(dataBlockBoundsBeforeEndInRealTime));
            dataBlockBoundsBeforeBegInRealTime = timeInSamples(2, :)<begsample;
            begsampleInSamples = begsample - sum(dataBlockRealTimeBlanks(dataBlockBoundsBeforeBegInRealTime));

            fseek(fh, bytesInHeaders, -1);
            % number of samples to skip can't go below 0 (i.e. make sure we can keep the first data point!)
            bytes2skip = max((begsampleInSamples-1)*2*double(chanCount), 0); %this should be the number of data samples to skip... -ACS 09May2012 %-re-casted chanCount as double to avoid misreading huge files -ACS 16Jun2015
            bytes2skip = bytes2skip+packetHeaderBytes*sum(begsampleInSamples>nvec); %this should add on the little headers before each data block... -ACS
            fseek(fh, bytes2skip, 0); %The initial bytes to skip
            
            endByteOrig = 9*sum(dataBlockBounds)+(endsample*2*chanCount); %this should be the position of the last requested sample in the file... -ACS
            endByte = 9*sum(dataBlockBounds)+(endsampleInSamples*2*chanCount);
            currentSample = begsampleInSamples;
            dataInd = 1;
            while ftell(fh)<endByte
                nextBoundInd = find(nvec>currentSample,1,'first');
                nextBound = nvec(nextBoundInd);
                nextBound = min(nextBound,endsample);
                data(:,dataInd:nextBound-currentSample+dataInd) = double(fread(fh,[chanCount,nextBound-currentSample+1],'*int16'));
                dataInd = nextBound-currentSample+dataInd+1;
                if nextBoundInd <= size(timeInSamples,2)
                    blankDataSamples = timeInSamples(1, nextBoundInd) - timeInSamples(2, nextBoundInd-1);
                    data(:,dataInd:dataInd+blankDataSamples) = nan;
                    dataInd = dataInd + blankDataSamples+1;
                end
                currentSample = nextBound+1;
                if ftell(fh)<(filesize-9)
                    fseek(fh,9,0); %skip the little header for the next data block
                end
            end
        end
    end
    if ~keepint
        out.data = bsxfun(@times,double(data(chanindx,:)),double(scale(chanindx)));
    else
        out.data = data;
    end
end
%% package output
hdr.Fs = fs;
hdr.nChans = chanCount;
hdr.nSamples = max(nvec); %changed to nvec, which is the cumulative sum of datapoints in each block (had been max(ndataPoints), which caused an error for files with more than one block). -ACS 08Nov2012
hdr.label = chanLabels;
hdr.chanunit = unit(:);
hdr.scale = scale;
hdr.timeStamps = double(time);
hdr.clockFs = double(clockFs);
hdr.timeOrigin = timeOrigin;

out.hdr = hdr;

fclose(fh);
