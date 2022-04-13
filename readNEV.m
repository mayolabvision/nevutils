function [spike, waves] = readNEV(nevfile)
%function [spike] = readNEV(nevfile)
%
% readNEV takes an NEV file as input and returns the event codes
% and times. 
%
% The columns of "spike" are channel, spike class (or digital port
% value for digital events), and time (seconds). The channel is 0
% for a digital event, and 1 and above for spike channels.
%
% This is a mex-optimized version of the matlab read_nev.m file
%
% [spike] = readNEV(nevfile)
% [spike,wave] = readNEV(nevfile)
%   returns the waveforms as doubles in microVolts
% [spike,wave] = readNEV(nevfile,1)
%   returns the waveforms as int16 values (to save space)
%
