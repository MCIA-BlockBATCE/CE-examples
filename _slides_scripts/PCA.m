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
%   Part 1. DATA LOADING
%       This section loads the dataset features and target labels
%       for various fault classes.
%
%   Part 2. PCA CALCULATION
%       This section computes PCA to reduce the dimensionality of the 
%       normalized features.
% 
%   Part 3. PERFORMANCE METRICS (?¿?¿)
%       In this part we obtain the accumulated explained variance vector
%       from the PCA decomposition. This is useful to know how many
%       principal components are needed depending on the required explained
%       variance.
%
%   Part 4. VISUALIZATION
%       In this final section two plots are generated. The first one
%       represents the explained variance by the different principal
%       components. The second one is used to visualize the data in a
%       two-dimensional space using the first two principal components.

%% -------------- Part 1 Data loading --------------------
% Load data, containing features for fault type and severity, as well as
% target names for fault types. Severity is not taken into account in the
% target labels.
load data_PCA.mat

%% -------------- Part 2 PCA Calculation ----------------------------------
DataCov = cov(FeaturesHIOBv3); % Covariance matrix needed to perform the PCA
[PC, variances, explained] = pcacov(DataCov); %PCA decomposition

% From PCA decomposition we've obtained the principal components ordered by
% descending explained variance and their respective variances and explained
% variance percentages. 

%% -------------- Part 3 Performance metrics (?¿?¿¿?) ------------------------------

% Create accumulated explained variance vector
acum_var = zeros(length(explained), 1);
acum_var(1) = explained(1);
for i=2:length(explained)
    acum_var(i) = acum_var(i-1) + explained(i);
end

%% -------------- Part 4 Visualization ------------------------------

% --- Accumulated explained variance plot ---

% Accumulated explained variance is rounded, converted into strings and
% stored in a cell array
rounded_acum_var = round(acum_var,1);
acum_var_str = num2str(rounded_acum_var);
acum_var_str = acum_var_str + " %";
acum_var_str_cell = cellstr(acum_var_str);
dy = 1;

% Individual explained variance is rounded, converted into strings and
% stored in a cell array
individual_var = explained(2:end);
rounded_individual_var = round(individual_var,1);
individual_var_str = num2str(rounded_individual_var);
individual_var_str = individual_var_str + " %";
individual_var_str_cell = cellstr(individual_var_str);
dy2 = 5;

figure (1);
hold on
plot(acum_var,'-o','MarkerIndices',1:1:length(acum_var))
bar(explained)
text(1:1:length(explained),acum_var-dy,acum_var_str_cell)
text(2:1:length(explained),individual_var+dy2,individual_var_str_cell)
xlim([0 length(explained)])
ylim([0 100])
ylabel('Explained Variance [%]')
xlabel('Principal Components')
title('Explained Variance by Different Principal Components')
set(gca, 'XTick',1:1:length(explained), 'FontSize',9)
hold off

% --- Two-dimensional space label visualisation ---

num_PC=2; % Number of dimensions for the PCA.
PC=PC(:,1:num_PC);% From the PCA, select the 2 first components
FeaturesHIOBPC=FeaturesHIOBv3*PC;% Create a latent space with the new projections

figure(2)
gscatter(FeaturesHIOBPC(:,1), FeaturesHIOBPC(:,2), Targets_names, 'rgbcmyk', 'xo*+sd><^', 6)
xlabel('Principal Component #1')
ylabel('Principal Component #2')
title('PCA Data Representation')