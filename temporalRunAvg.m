function [ t_runavg, y_runavg, bin_ntrials ] = temporalRunAvg(data_t,data_y,binL,shiftL,varargin)
% temporalRunAvg is similar to movmean.m and smoothdata.m except it bins and steps by
% time segments that may not be equally sampled (ex. trial times).
%   data_t - time data to be used to bin
%   data_y - compute running average on this 1D data array (if 2D array use optional flag2D)
%   binL - window length for moving estimate (same unit as data_t)
%   shiftL - length of shift step in moving estimate calculation (same unit as data_t)
%   flag2D (optional) - if true, compute moving average on first dimension

%   t_runavg - binned times for running average
%   y_runavg - moving average of data_y
%   bin_ntrials- # of samples/trials in each bin

p = inputParser;
addOptional(p,'flag2D',false,@islogical);
p.parse(varargin{:});
flag2D = p.Results.flag2D;

% ********** Compute time bins *********************
% bin start times shifted by shiftL
tbins = data_t(1):shiftL:(data_t(end)-binL);

% time at the center of each time bin
t_runavg = tbins + binL/2;

% ********** Identify samples in each time bin *********************
for ti = 1:length(tbins)
    start_i = find(data_t>=tbins(ti),1); % first trial with a time greater than tbins(ti)
    end_i = find(data_t<(tbins(ti) + binL),1,'last'); % last trial with a time less than tbins(ti)
    % note: if start_i > end_i then no samples appear in the interval

    bin_ntrials(ti) = length(start_i:end_i); % number of samples in each bin

    % ********** Compute average *********************
    if flag2D % 2D array
        y_runavg(ti,:) = mean(data_y(start_i:end_i,:),1,'omitnan');
    else % 1D array
        y_runavg(ti) = mean(data_y(start_i:end_i),'omitnan');
    end

end

end

