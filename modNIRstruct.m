function nirs_out = modNIRstruct(nirs_data,varargin)
% modNIRstruct creates a new nirs_data structure, only includes useful
% fields, and removes the first datapoint (the dark counts).
% Run this immediately after loading data, we can always add back 
% additional fields that become useful later.
%
% truncateDat: truncates data between [start_ind stop_ind] indices (not
%               time values). default is from 2 to end of data to get rid of dark count
%               value at sample #1

p = inputParser;
p.addOptional('truncateData',[2 nan], @isnumeric);
p.parse(varargin{:});
truncInds = p.Results.truncateData;

if isnan(truncInds(1))
    truncInds(1) = 1;
end
if isnan(truncInds(2))
    truncInds(2) = length(nirs_data.sampleNo);
end

if isfield(nirs_data,'OD') % optical density data
     nirs_out.OD = nirs_data.OD(truncInds(1):truncInds(2),:);
     nirs_out.ODlabel = nirs_data.ODlabel;
elseif isfield(nirs_data,'oxyvals') % oxy/dxy converted data
     nirs_out.oxyvals = nirs_data.oxyvals(truncInds(1):truncInds(2),:);
     nirs_out.dxyvals = nirs_data.dxyvals(truncInds(1):truncInds(2),:);
else
    error('nirs_data must contain OD or oxyvals');
end

nirs_out.time = nirs_data.time(truncInds(1):truncInds(2));

nirs_out.wavelengths = nirs_data.wavelengths;
nirs_out.DPF = nirs_data.DPF;
nirs_out.distance = nirs_data.distance;
nirs_out.Fs = nirs_data.Fs;

nirs_out.label = nirs_data.label;

nirs_out.ADlabel = nirs_data.ADlabel;
nirs_out.ADvalues = nirs_data.ADvalues(truncInds(1):truncInds(2),:);

end