function [SP] = checkForServiceProviding(t, BidStep)
%CHECKFORSERVICEPROVIDING Summary of this function goes here
%   Detailed explanation goes here

if(t==BidStep || t==BidStep+1 || t==BidStep+2 || t==BidStep+3)
    SP = true;
else
    SP = false;

end

