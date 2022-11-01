function [ nirs_data ] = applyMBLL(nirs_data, varargin)
% applyMBLL applies the modified beer-lambert law to the raw OD data
% artinis raw data is "OD", assumes input nirs_data structure has the following 
% fields: 'OD','ODlabel','distance','wavelengths'. Adds oxyvals and dxyvals 
% to data structure

% nirs_data: filepath/name for nirs_data structure or nirs_data structure
% I0method (optional): method for calculating I0, default- 'Iearly'
%                      1. 'Iavg': mean of entire data trace
%                      2. 'Iearly': mean of a few early samples in data
%                          trace (see nvals below)
%                      3. 'Imovavg': moving average estimate of I0 (see
%                          windowL below)
% nvals (optional): for I0method 'Iearly' how many samples to avg to
%                   compute I0, default- 300 samples
% windowL (optional): for I0method 'Imovavg' how many samples to avg in
%                     moving window, default- 1000 samples
% smallNumApprox (optional): if true ln(I/I0) ~ ∆I/I0, default- true

p = inputParser;
p.addOptional('I0method','Iearly', @(x) strcmp(x,'Iavg') | strcmp(x,'Iearly') | strcmp(x,'Imovavg'));
p.addOptional('nvals',300,@isnumeric);
p.addOptional('windowL',1000,@isnumeric)
p.addOptional('smallNumApprox',true,@islogical);
p.parse(varargin{:});
I0method = p.Results.I0method;
smallNumApprox = p.Results.smallNumApprox;
nvals = p.Results.nvals;

% **** Constants ****
load ext_coef
% ext_coef contains the extinction coefficients of HbO and Hb 
% from omlc.org/spectra/hemoglobin 
ext_hbo = ext_hbo *2.303/1000;
ext_hb  = ext_hb  *2.303/1000;
% *******************

% 1) Recalculate optical density using preferred I0 value
% convert artinis "optical density" to intensity
I = 2.^16.*10.^(-1.*nirs_data.OD);

% recalculate optical density using I0
switch I0method
    case 'Iavg'
        I0 = mean(I,1);
    case 'Iearly'
        I0 = mean(I(1:nvals,:),1);
    case 'Imovavg'
        % shift has to be 1 sample, because need an I0 for each data point
        I0 = movmean(I,windowL);
end

if smallNumApprox
    OD = -1*(I-I0)./I0;
else
    OD = -1*log(I./I0);
end

% 2) Create new OD matrix NxMxL
% this ensures the data from different wavelengths are in a consistent order
% N- # of channels
% M = 2 where column 1: lambda 1 (nirs_data.wavelengths(1)), column 2: lambda 2 (nirs_data.wavelengths(2))
% L- # of samples in data 
nchan = size(OD,2)/2;
L = size(OD,1);
lmbda1 = nirs_data.wavelengths(1);
lmbda2 = nirs_data.wavelengths(2);

ODmat = nan(nchan,2,L);
chan = 1;
for c = 1:2:size(OD,2)
    chanODs = OD(:,c:(c+1)); % OD values corresponding to channel c
    chan_lambda = cellfun(@(l) str2num(l(end-4:end-2)),nirs_data.ODlabel(c:c+1)); %determine which wavelength (lambda) each column in the raw data represents
    
    [~,loc_lmbda1] = min(abs(chan_lambda-lmbda1));
    [~,loc_lmbda2] = min(abs(chan_lambda-lmbda2));

    lambdas(chan,:) = [chan_lambda(loc_lmbda1),chan_lambda(loc_lmbda2)];

    ODmat(chan,1,:) = chanODs(:,loc_lmbda1);
    ODmat(chan,2,:) = chanODs(:,loc_lmbda2);
    
    % extinction coefficients for the exact values of lambda1 and lambda2
    % wavelength is an array from the ext_coeff.mat that indexes ext_hbo and ext_hb by lambda
    eoxy(chan,:) = ext_hbo([chan_lambda(loc_lmbda1),chan_lambda(loc_lmbda2)] - wavelength(1)+1);
    edxy(chan,:) = ext_hb([chan_lambda(loc_lmbda1),chan_lambda(loc_lmbda2)]  - wavelength(1)+1);
    
    chan = chan + 1;
end
nirs_data.wavelengths = lambdas;

% 3) Calculate ∆mua
for nn = 1:nchan
    for mm = 1:2
        nirs_data.dpf(nn,mm) = getDPF(25,lambdas(nn,mm));
        nirs_data.mua(nn,mm,:) = ODmat(nn,mm,:)./(nirs_data.distance(nn)*nirs_data.dpf(nn,mm));
    end
end

% 4) Solve for ∆oxy ∆dxy concentrations
for nn = 1:nchan
    den = (eoxy(nn,1)*edxy(nn,2)) - eoxy(nn,2)*edxy(nn,1);
    nirs_data.oxyvals(:,nn) = 1000 * (edxy(nn,2)*nirs_data.mua(nn,1,:) - edxy(nn,1)*nirs_data.mua(nn,2,:)) / den;
    nirs_data.dxyvals(:,nn) = 1000 * (eoxy(nn,1)*nirs_data.mua(nn,2,:) - eoxy(nn,2)*nirs_data.mua(nn,1,:)) / den;
end


end

