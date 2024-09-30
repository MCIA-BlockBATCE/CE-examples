clear
clc
close all


% This script presents on the application of Principal Component Analysis (PCA)
% for a dataset related to fault severity analysis. The aim of PCA is to
% reduce feature dimensionality of a dataset in order to simplify it
% without too losing much information.
%
% The script is organized into two main parts:
%
%   Part 1. FEATURE CLASSIFICATION
%       This section loads the dataset features and prepares target labels
%       for various fault severity classes, including healthy and 
%       multiple inner and outer fault severities. 
%
%   Part 2. PCA CALCULATION
%       This section computes PCA to reduce the dimensionality of the 
%       normalized features. It generates plots representing the 
%       explained variance by the different principal components and 
%       visualizes the data in a two-dimensional space using the 
%       first two principal component for a clearer analysis 
%       of the fault severity classes.
%
%% -------------- Part 1 Feature classification --------------------
% Load data
load FeaturesHIOBv3.mat

% Target labels are created
Targets_names=cell(1200,1);% 10 classes);
Targets_names(1:120,1)={'Healthy'};  % Class healthy
Targets_names(121:240,1)={'Inner Fault Severity 1'};% Class Inner Fault Severity 1
Targets_names(241:360,1)={'Inner Fault Severity 2'};% Class Inner Fault Severity 2
Targets_names(361:480,1)={'Inner Fault Severity 3'};% Class Inner Fault Severity 3
Targets_names(481:600,1)={'Outher Fault Severity 1'};% Class Outher Fault Severity 1
Targets_names(601:720,1)={'Outher Fault Severity 2'};% Class Outher Fault Severity 2
Targets_names(721:840,1)={'Outher Fault Severity 3'};% Class Outher Fault Severity 3
Targets_names(841:960,1)={'Ball Fault Severity 1'};% Class Ball Fault Severity 1
Targets_names(961:1080,1)={'Ball Fault Severity 2'};% Class Ball Fault Severity 2
Targets_names(1081:1200,1)={'Ball Fault Severity 3'};% Class Ball Fault Severity 3

%% -------------- Part 2 PCA Calculation----------------------------------
DataCov = cov(FeaturesHIOBv3); % Covariance matrix needed to perform the PCA
[PC, variances, explained] = pcacov(DataCov); %PCA decomposition

% From PCA decomposition we've obtained the principal components ordered by
% descending explained variance and their respective variances and explained
% variance percentages. 

% Create accumulated explained variance vector
acum_var = zeros(length(explained), 1);
acum_var(1) = explained(1);
for i=2:length(explained)
    acum_var(i) = acum_var(i-1) + explained(i);
end

% --- Accumulated explained variance plot ---

a1 = round(acum_var,1);
b1 = num2str(a1);
b1 = b1 + " %";
c1 = cellstr(b1);
dy = 1;

explained_short = explained(2:end);
a2 = round(explained_short,1);
b2 = num2str(a2);
b2 = b2 + " %";
c2 = cellstr(b2);
dy2 = 5;

figure (1);
hold on
plot(acum_var,'-o','MarkerIndices',1:1:length(acum_var))
%plot(acum_var)
bar(explained)
text(1:1:length(explained),acum_var-dy,c1)
text(2:1:length(explained),explained_short+dy2,c2)
xlim([0 length(explained)])
ylim([0 100])
ylabel('Explained Variance [%]')
xlabel('Principal Components')
title('Explained Variance by Different Principal Components')
set(gca, 'XTick',1:1:length(explained), 'FontSize',9)
hold off

% --- Two-dimensional space label visualisation ---

z=2; % Number of dimensions fot the PCA.
PC=PC(:,1:z);% From the PCA, select the z first components
FeaturesHIOBPC=FeaturesHIOBv3*PC;% Create a latent space with the new projections

figure(2)
gscatter(FeaturesHIOBPC(:,1), FeaturesHIOBPC(:,2), Targets_names, 'rgbcmyk', 'xo*+sd><^', 6)
xlabel('Principal Component #1')
ylabel('Principal Component #2')
title('PCA Data Representation')