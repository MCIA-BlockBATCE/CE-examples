function [SP] = checkForServiceProviding(t, BidStep)
% This function returns a boolean variable depending on whether service
% providing is taking place or not.

if(t==BidStep || t==BidStep+1 || t==BidStep+2 || t==BidStep+3)
    SP = true;
else
    SP = false;

end

