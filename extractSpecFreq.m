function [spec_trace,t] = extractSpecFreq(x,fs,frange,windowL,overlapF,varargin)
%extractSpecFreq extracts a trace from the spectrogram in the frequency
%range listed 
%   INPUTS
%   x- data trace
%   fs- sampling frequency
%   frange- 2 element array, frequency range of the trace in Hz
%   windowL- window length for spectrogram (in samples)
%   overlapF- fraction of overlap between spectrogram bins
%   OUTPUTS
%   spec_trace- extracted trace from spectrogram
%   t- time from spectrogram

p = inputParser;
p.addOptional('penalty',0.001,@isscalar);
p.parse(varargin{:});

penalty = p.Results.penalty;

HighB = frange(1);
LowB = frange(2); %Hz

%filter data to remove substantial 1/f influence
[b,a]= butter(3,[HighB-HighB/2]/(fs/2),'high'); %high pass filter the data
dataFilt = filtfilt(b,a,x);


overlap = round(windowL*overlapF);
[s1,f,t,psd1] = spectrogram(dataFilt,windowL,overlap,[],fs,'yaxis');
s1 = psd1; %take it or leave it
[~,inx1] = min(abs(f-HighB));
[~,inx2] = min(abs(f-LowB));
s1_temp = s1(inx1:inx2,:);

nfb = 1;
[fr,ridge_idx] = tfridge(s1_temp,f,penalty,'NumRidges',1,'NumFrequencyBins',nfb);
ridge_idx = ridge_idx(:,1)+inx1-1;

spec_trace = f(ridge_idx);

end