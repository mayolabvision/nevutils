function [eyeout, eyeoutPix] = eye2deg(eyePt, params)
%function [eyeout, eyeoutPix] = eye2deg(eyePt, params)
%
%eye2deg takes as input a trial of eye position data and the corresponding
%params struct from the nev file. The params input could also be something
%like ex.ENV{1,1}
%
%Modified 12may2016 by Adam Snyder: For the new method of calibration
%(i.e., without the pixelsPerMV field), apparently we need to divide the
%raw voltage value in half before performing the regression. Not sure why
%the values seem to be doubled when saving to trellis yet, but this does
%work. -acs
%
%NOTE: We fixed the voltage doubling issue. There are only a few files
%where pixelsPerMV doesn't exist but the voltage is stored as double.
%Should update this.
%
% As of Jan 11, 2017, we think we've covered all cases of eye2deg
% conversion in Smith Lab History. This supercedes all previous eye2deg
% conversions and should work for every file. Most recent addition was
% dealing with the files where pixelsPerMV needed to be divided by 2 or
% not (Jan 2016 issues).
%
% 26jan2017: I found that 'voltScale' wasn't actually sent in my more
% recent files, whereas 'displayPixelSize' was, so I changed the conditional
% expression to this value. -acs26jan2017

%Set up regression for calibration of degrees to voltage space
calibration{1}=[params.block.calibPixX' params.block.calibPixY']; % Pixel space coordinates
calibration{2}=[params.block.calibVoltX' params.block.calibVoltY']; % Voltage space coordinates
% Volt to pix transform matrices via assumed linear regression
calibration{3}=regress(calibration{1}(:,1),[calibration{2},ones(size(calibration{2},1),1)]); % X
calibration{4}=regress(calibration{1}(:,2),[calibration{2},ones(size(calibration{2},1),1)]); % Y

%Load eye data
eyex_row = 1; %index of x position data in file
eyey_row = 2; %index of y position data in file

%eyePt = eyePt([eyex_row,eyey_row],:)'
eyePt = eyePt([eyex_row,eyey_row],:)'./1000; %organize the rows, transpose and convert millivolts to volts (this had been done by copying the values into new variables, but I was running into memory limitations, so I simplified this -acs21sep2016)

if isfield(params.block,'pixelsPerMV'), 
    %when PixelsPerMV existed, calibVoltX/Y were stored as pixel values for the control display
    if (params.block.pixelsPerMV(1,1) == 26.35) || (params.block.pixelsPerMV(1,1) == 25)
        % This case is for all data prior to Jan 2016 (we think) before
        % Linux control computers were installed
        eyePt = bsxfun(@plus,bsxfun(@times,eyePt,(params.block.pixelsPerMV)),params.block.midV);
        eyePt(:,2) = bsxfun(@minus,params.block.voltageDim(4),eyePt(:,2));
    elseif params.block.pixelsPerMV(1,1) == 52.7
        % We think this is for brief period of Jan-Mar 2016, when the new
        % computers were installed but pixelsPerMV was not yet purged from Ex
        eyePt = bsxfun(@plus,bsxfun(@times,eyePt,(params.block.pixelsPerMV/2)),params.block.midV);
        eyePt(:,2) = bsxfun(@minus,params.block.voltageDim(4),eyePt(:,2));
    else
        error(['Unexpected pixelsPerMV value: ',num2str(params.block.pixelsPerMV(1,1))]);
    end
    eyePt = cat(2,eyePt,ones(size(eyePt,1),1));
    eyex =eyePt*calibration{3};
    eyey =eyePt*calibration{4};
    %disp(' *** Old style eye2deg conversion when pixelsPerMV was used prior to 18mar2016');
elseif isfield(params.block,'displayPixelSize') %changed test field from 'voltScale' to 'displayPixelSize'; I found that voltScale wasn't actually sent. -acs26jan2017
    if max(abs([params.block.calibVoltX params.block.calibVoltY])) < 10 % arbitrary number here
        % files after 2016/03/18 don't have pixelsPerMV, they just
        % store the eye position data in raw volts
        eyePt = eyePt./2; %I found that the voltage in Trellis is apparently saved as twice the value that the control computer measures... not sure why yet... -acs12may2016
        eyePt = cat(2,eyePt,ones(size(eyePt,1),1)); %add ones for regression intercept
        eyex =eyePt*calibration{3};
        eyey =eyePt*calibration{4};
        %disp(' *** New style eye2deg conversion during brief voltage-doubled period');
    else % this seems to be the newest case, after 12may2016 with no voltage doubling
        eyePt = eyePt .* 1000;
        eyePt = cat(2,eyePt,ones(size(eyePt,1),1)); %add ones for regression intercept
        eyex =eyePt*calibration{3};
        eyey =eyePt*calibration{4};
        %disp(' *** New style eye2deg conversion after 12may2016');
    end
else
    % pre-history of the Smith Lab, before "wins" was merged with params
    % (B.C.) = Before Catstruct. Hard code in these values because they
    % never changed in the very early days (I hope).
    params.block.pixelsPerMV = [25 25];
    params.block.midV = [250 250];
    params.block.voltageDim = [0 0 500 500];
    
    eyePt = bsxfun(@plus,bsxfun(@times,eyePt,(params.block.pixelsPerMV)),params.block.midV);
    eyePt(:,2) = bsxfun(@minus,params.block.voltageDim(4),eyePt(:,2));
    eyePt = cat(2,eyePt,ones(size(eyePt,1),1));
    eyex =eyePt*calibration{3};
    eyey =eyePt*calibration{4};
end

% fix weird dropped packet in Wi160218_s240vx1_fixAndstim_2siteAmpHi_CH7_CH1_0008
if isfield(params.block,'screnDistance')
    params.block.screenDistance = params.block.screnDistance;
end

% save the pix before converting to deg
eyeoutPix(eyex_row, :) = eyex;
eyeoutPix(eyey_row, :) = eyey;

%Convert pixels to redefine eyex and eyey in degree space
eyex = pix2deg(eyex, params.block.screenDistance, params.block.pixPerCM);
eyey = pix2deg(eyey, params.block.screenDistance, params.block.pixPerCM);

% clf;
% plot(eyex,eyey,'r');
% pause;

eyeout(eyex_row,:) = eyex;
eyeout(eyey_row,:) = eyey;


