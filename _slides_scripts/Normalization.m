%Normal Transforms data to zero mean and unit variance
% x is the input data matrix
% y is the returned data where each feature column has zero mean and unit standard
%deviation.
clc
clear all
load FeaturesHIOBv3_NoNormalized.mat
x=FeaturesHIOBv3_NoNormalized;
n = size(x,1);

%Normalization over the whole set
mu= mean(x);
s=std(x);
e = ones(n,1);
y= x-e*mu; %make y have zero mean
y=y./(e*(s+(s==0)));

figure(1)
gscatter(x(:,10), x(:,12))
xlabel('Feature #10')
ylabel('Feature #12')
title('Non-normalized data')

figure(2)
gscatter(y(:,10), y(:,12))
xlabel('Feature #10')
ylabel('Feature #12')
title('Normalized data')

figure(3)
histogram (x(:,10))
xlabel('Range of feature values segmented by bins')
ylabel('Number of hits per bin')
title('Histogram of Non-normalized Feature#10')
skewness_F10_Nonnormalized = skewness (x(:,10));
txt = ['Skewness: ' num2str(skewness_F10_Nonnormalized)];
text(27,600,txt)

figure(4)
histogram (y(:,10))
xlabel('Range of feature values segmented by bins')
ylabel('Number of hits per bin')
title('Histogram of Normalized Feature#10')
skewness_F10_Normalized = skewness (y(:,10));
txt = ['Skewness: ' num2str(skewness_F10_Normalized)];
text(2.5,600,txt)

%Normalization over the healthy samples (Nominal conditions)
mu_h= mean(x(1:120,:));
s_h=std(x(1:120,:));
e = ones(n,1);
y_h= x-e*mu_h; %make y have zero mean
y_h=y_h./(e*(s_h+(s_h==0)));

figure(5)
gscatter(y_h(:,10), y_h(:,12))
xlabel('Feature #10')
ylabel('Feature #12')
title('Normalized data over healhty')

figure(6)
histogram (y_h(:,10))
xlabel('Range of feature values segmented by bins')
ylabel('Number of hits per bin')
title('Histogram of Normalized Feature#10 - over healhty data')
skewness_F10_Normalized = skewness (y_h(:,10));
txt = ['Skewness: ' num2str(skewness_F10_Normalized)];
text(50,450,txt)

