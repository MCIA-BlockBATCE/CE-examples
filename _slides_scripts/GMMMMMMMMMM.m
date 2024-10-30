close all
clear 
clc

% This script performs Gaussian Mixture Model (GMM)-based novelty detection.
% The approach involves training a GMM model on known class data and 
% identifying novel data points based on Mahalanobis distance from the GMM.
%
% The code is organized into the following sections:
%
%   PART 1. DATA LOADING
%       This section loads the feature dataset, containing features and
%       target labels for each class.
%
%   PART 2. DATA PREPROCESSING
%       Organizes data into training sets for different classes and normalizes data.
%
%   PART 3. MODEL TRAINING
%       Fits GMM models to the training data using various configurations 
%       of covariance types and shared covariance options.
%
%   PART 4. MODEL SELECTION
%       Selects the best GMM model based on AIC and BIC criteria.
%
%   PART 5. NOVELTY DETECTION
%       Calculates Mahalanobis distance for validation data and identifies
%       novel points based on a distance threshold.
%
%   PART 6. VALIDATION AND PERFORMANCE
%       Validates the GMM model on unseen data and calculates confusion matrix.

%% -------------- Part 1. Data Loading ----------------
% Load the dataset for GMM-based novelty detection, containing features and
% target labels. Additionally, contains different training and validation indexes.
load data_GMM_NoveltyDetection.mat

%% -------------- Part 2. Data Preprocessing ------------- 
% Normalize and separate data into training sets for different classes
data_norm = Mat_Normalizada_val(:,6:7); % Using the first two features

DataCov = cov(data_norm);
[PC, variances, explained] = pcacov(DataCov); 
z = 2; 
PC = PC(:,1:z);
data_PC = data_norm * PC;  % Project data into principal component space

% Training and validation set
% Set A
TA = ta(Training_index_A,:);
VDA = data_PC(Validation_index_A,:);
VTA = ta(Validation_index_A,:);
TAr = tar(Validation_index_A,:);

% Set B
TB = tb(Training_index_B,:);
VDB = data_PC(Validation_index_B,:);
VTB = tb(Validation_index_B,:);
TBr = tbr(Validation_index_B,:);

% Set C
TC = tc(Training_index_C,:);
VDC = data_PC(Validation_index_C,:);
VTC = tc(Validation_index_C,:);
TCr = tc(Validation_index_C,:);

% Create training data for set C
TD = data_PC(Training_index_C,:);

%% -------------- Part 3. Model Training ----------------
% Configuration for fitting GMM models
X = [TD(1:30,:); TD(61:90,:)]; % Combine training data
k = 1:5; % Range of clusters to test
nK = numel(k); % Number of cluster options
Sigma = {'diagonal','full'}; % Types of covariance
nSigma = numel(Sigma); % Number of covariance types
SharedCovariance = {true, false}; % Shared covariance options
nSC = numel(SharedCovariance); % Number of shared covariance options
RegularizationValue = 0.01; % Regularization to avoid singularities
options = statset('MaxIter', 10000); % Set options for fitting

% Preallocation of GMM parameters
gm = cell(nK, nSigma, nSC); % GMM model storage
aic = zeros(nK, nSigma, nSC); % AIC storage
bic = zeros(nK, nSigma, nSC); % BIC storage
converged = false(nK, nSigma, nSC); % Convergence status storage

% Fit all GMM models with various configurations
for m = 1:nSC
    for j = 1:nSigma
        for i = 1:nK
            % Fit GMM model
            gm{i,j,m} = fitgmdist(X, k(i), ...
                'CovarianceType', Sigma{j}, ...
                'SharedCovariance', SharedCovariance{m}, ...
                'RegularizationValue', RegularizationValue, ...
                'Options', options);
            aic(i,j,m) = gm{i,j,m}.AIC; % Store AIC value
            bic(i,j,m) = gm{i,j,m}.BIC; % Store BIC value
            converged(i,j,m) = gm{i,j,m}.Converged; % Check convergence
        end
    end
end

allConverge = (sum(converged(:)) == nK*nSigma*nSC); % Check if all models converged

%% -------------- Part 4. Model Selection ----------------
% Select the best GMM model based on criteria
gmBest = gm{5, 2, 2}; % Example of selecting the best model configuration
kGMM = gmBest.NumComponents; % Number of components in the best GMM

%% -------------- Part 5. Novelty Detection ----------------
% Calculate Mahalanobis distance for a grid of points
n = 1500; % Number of points for grid
x1 = linspace(2*min(data_norm(:,1))-30, max(data_norm(:,1))+30, n); % Range for first feature
x2 = linspace(2*min(data_norm(:,2))-10, max(data_norm(:,2))+30, n); % Range for second feature
[X1, X2] = meshgrid(x1, x2); % Create grid for decision boundary
XG = [X1(:), X2(:)]; % Reshape grid into 2D points for evaluation

% Compute Mahalanobis distance
mahalDist = mahal(gmBest, XG);
threshold = sqrt(chi2inv(0.99, 2)); % Distance threshold for novel detection

% Identify novel points based on distance threshold
resultaux = zeros(length(XG), 1); % Initialize results
for cont = 1:length(XG)
    if min(mahalDist(cont,:)) <= threshold
        resultaux(cont, 1) = 1; % Inside the threshold (known)
    end
end

% Plot decision boundary for known vs novel data
figure(3)
title('GMM Novelty Detection');
xlabel('Feature #1');
ylabel('Feature #2');
set(gca, 'Color', 'w');
hold on;
contour(X1, X2, reshape(resultaux, size(X1,1), size(X2,1)), [1, 1], 'Color', 'k'); % Plot boundary
gscatter(X(:,1), X(:,2), [], 'b', 'o'); % Plot known data points
axis([-2, 16, -10, 70]); % Set axis limits
hold off;

%% -------------- Part 6. Validation and Performance -----------------
% Validate the GMM model on validation data
mahalDistVal = mahal(gmBest, VDA); % Calculate distances for validation data
confusion = zeros(3, 3); % Initialize confusion matrix
labels = cell(length(VDA), 1); % Preallocate labels for validation results

% Classify validation data based on Mahalanobis distance
for cont = 1:length(VDA)
    if min(mahalDistVal(cont,:)) <= threshold && VTA(cont) == 1 % True Positive
        confusion(1,1) = confusion(1,1) + 1; % Increment TP count
        labels{cont} = 'True Positive'; % Assign label
    elseif min(mahalDistVal(cont,:)) <= threshold && VTA(cont) == 0 % False Positive
        confusion(2,1) = confusion(2,1) + 1; % Increment FP count
        labels{cont} = 'False Positive'; % Assign label
    elseif min(mahalDistVal(cont,:)) >= threshold && VTA(cont) == 1 % False Negative
        confusion(1,2) = confusion(1,2) + 1; % Increment FN count
        labels{cont} = 'False Negative'; % Assign label
    elseif min(mahalDistVal(cont,:)) >= threshold && VTA(cont) == 0 % True Negative
        confusion(2,2) = confusion(2,2) + 1; % Increment TN count
        labels{cont} = 'True Negative'; % Assign label
    end
end

% Calculate overall accuracy
total_acc = (confusion(1,1) + confusion(2,2)) / sum(confusion(:)); % Total accuracy calculation

% Display confusion matrix and accuracy
disp('Confusion Matrix:');
disp(confusion);
disp(['Overall Detection Accuracy: ', num2str(total_acc)]);

% Plot validation results with labels
figure(4)
contour(X1, X2, reshape(resultaux, size(X1,1), size(X2,1)), [1, 1], 'Color', 'k'); % Decision boundary
hold on;
gscatter(VDA(:,1), VDA(:,2), labels, 'rgbcmyk', 'xo*sd><^', 8); % Plot validation results
title('GMM Validation for Novelty Detection');
xlabel('Feature #1');
ylabel('Feature #2');
ax = gca;
ax.FontSize = 12;
ax.XAxis.Label.FontSize = 14;
ax.YAxis.Label.FontSize = 14;
xlim([-10 70]);
ylim([-2 16]);
hold off;