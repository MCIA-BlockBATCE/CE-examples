function y= normal (x)
%Normal Transforms data to zero mean and unit variance
% x is the input data matrix
% y is the returned data where each variable has zero mean and unit standard
%deviation.

n = size(x,1);
mu= mean(x);
s=std(x);
e = ones(n,1);

y= x-e*mu; %make y have zero mean

y=y./(e*(s+(s==0)));


end

