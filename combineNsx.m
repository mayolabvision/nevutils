function [nsx_combined] = combineNsx(filename, chanindx,varargin)
%combineNsx concatenates nsx files from the same session using the
%timeOrigin clock time in the nsx file. filetype is ns2 or ns5. fills nans 
%for samples between sessions
%only loads channels listed in chanindx to save space
p = inputParser;

p.addOptional('filtFlag',false,@islogical);
p.addOptional('filtRange',[0.01, 10],@isnumeric)
p.parse(varargin{:});

filtFlag = p.Results.filtFlag;
filtRange = p.Results.filtRange;

hdr = read_nsx([filename{1}],'readdata',false);
fs = double(hdr.hdr.Fs);
nChans = length(chanindx);
nsx_combined.hdr = hdr.hdr;
nsx_combined.hdr.nChans = nChans;
nsx_combined.hdr.label = nsx_combined.hdr.label(chanindx);
nsx_combined.hdr.chanunit = nsx_combined.hdr.chanunit(chanindx);
nsx_combined.hdr.scale = nsx_combined.hdr.scale(chanindx);

for fn = 1:length(filename)
    hdr_temp = read_nsx([filename{fn}],'readdata',false);
    tempStr = split(hdr_temp.hdr.timeOrigin,' ');
    timeStr = split(tempStr{2},':');
    timeUTC(fn) = str2num(timeStr{1})*3600 + str2num(timeStr{2})*60 + str2num(timeStr{3}); %seconds
    fileL(fn) = hdr_temp.hdr.nSamples;
    if fn>1
        t_inbetw = timeUTC(fn) - timeUTC(fn-1);
        if t_inbetw < 0 % late night recording session
            t_inbetw = t_inbetw+24; 
        end
        n_inbetw(fn) = round(t_inbetw*fs) - fileL(fn-1);
    else
        n_inbetw(fn) = 0;
    end
end

combinedL = sum(fileL) + sum(n_inbetw);
nsx_combined.hdr.timeStamps(2) = double(nsx_combined.hdr.clockFs)*combinedL/fs;
nsx_combined.hdr.nSamples = combinedL;

nsx_combined.data = nan(nChans,combinedL);
[b,a] = butter(2,filtRange./(fs/2),'bandpass');

for fn = 1:length(filename)
nsx_temp = read_nsx(filename{fn},'chanindx',chanindx);
if filtFlag
nsx_temp.data = filtfilt(b,a,nsx_temp.data);
end
if fn == 1
    firstSamp = 1;
    lastSamp = fileL(fn);
else
    firstSamp = lastSamp + n_inbetw(fn);
    lastSamp = lastSamp + n_inbetw(fn) + fileL(fn) -1; 
end
nsx_combined.data(:,firstSamp:lastSamp) = nsx_temp.data;
end

end