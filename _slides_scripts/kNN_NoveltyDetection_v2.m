close all
clear 
clc

% This script performs k-Nearest Neighbors (kNN)-based novelty detection.
% The approach involves training a kNN model on known class data and
% identifying novel data points based on their distance from known data clusters.
%
% The code is organized into the following sections:
%
%   PART 1. DATA LOADING
%       This section loads the feature dataset, containing features and
%       target labels for each class.
%
%   PART 2. DATA PREPROCESSING
%       Reduces data dimensions using Principal Component Analysis (PCA) for easier visualization.
%       Unlike "kNN_NoveltyDetection.mat", all features are taken into
%       account when performing PCA (8 features --> 2 features)
%
%   PART 3. MODEL TRAINING
%       Sets up the kNN model, defining known data points and setting a distance threshold.
%
%   PART 4. NOVELTY DETECTION AND PLOTTING
%       Uses kNN with a distance threshold to classify new points as "known" or "novel".
%       Plots the decision boundary and identifies novel points in the validation data.
%
%   PART 5. VALIDATION AND PERFORMANCE
%       Validates the kNN model and calculates accuracy metrics.

%% -------------- Part 1. Data Loading ----------------
% Load data, containing features for fault type and severity, as well as a target
% label array with target names for fault types. Severity is not taken into account
% in the target labels.
load data_kNN_NoveltyDetection.mat

%% -------------- Part 2. Data Preprocessing -------------
data_norm = Mat_Normalizada_val(:,1:8); % Use all available features

% Perform PCA to reduce data dimensions for visualization purposes
DataCov = cov(data_norm);               % Calculate covariance matrix
[PC, latent, explained] = pcacov(DataCov); % Apply PCA and get explained variance

% Display explained variance for each principal component
disp('Explained variance by each principal component (%):');
disp(explained');

% Retain only the first two principal components based on explained variance
z = 2;                                 % Number of principal components to retain
PC = PC(:,1:z);                        % Select first two principal components
data_PC = data_norm * PC;              % Project data into principal component space

% Plot data in 2D for visualization
figure(1)
gscatter(data_PC(:,1), data_PC(:,2), Targets_names, 'rgbcmyk', 'xo*+sd><^', 6);
xlabel('Feature #1');
ylabel('Feature #2');
title('PCA-Based Data Representation');

%% -------------- Part 3. Model Training ----------------
% Set up the kNN model parameters for novelty detection
D = data_PC(1:40,:); % Use "healthy" class data as known class for novelty detection
dmax = 5;           % Distance threshold to determine novelty
k = 1;               % Number of nearest neighbors to consider

% Generate a grid for decision boundary visualization
n = 1500;                                    % Number of points in grid for boundary plot
x1 = linspace(min(data_PC(:,1))-5, max(data_PC(:,1))+5, n); % Grid for first principal component
x2 = linspace(min(data_PC(:,2))-5, max(data_PC(:,2))+5, n); % Grid for second principal component
[X1, X2] = meshgrid(x1, x2);
XG = [X1(:), X2(:)]; % Create meshgrid for contour plotting

% Classify grid points based on distance from known data (novelty detection)
[~, distaux] = knnsearch(D, XG, 'k', k); % Find distance to nearest known point
resultaux = distaux <= dmax;             % Label grid points as known or novel based on distance threshold

%% -------------- Part 4. Novelty Detection and Plotting --------------
% Plot decision boundary and known vs novel data points
figure(2)
title('kNN Novelty Detection with Distance Threshold');
xlabel('Feature #1');
ylabel('Feature #2');
set(gca, 'Color', 'w');
hold on;
contour(X1, X2, reshape(resultaux, size(X1,1), size(X2,1)), [1, 1], 'Color', 'k'); % Plot decision boundary
gscatter(D(:,1), D(:,2), [], 'b', 'o');        % Known class points (healthy class)
hold off;

%% -------------- Part 5. Validation and Performance -----------------
% Classify validation data based on distance to known class
[~, dist] = knnsearch(D, data_PC(41:end,:), 'k', k); % Validation data distances
VDA_labels = dist <= dmax;                           % Classify as known/novel based on threshold

% Calculate confusion matrix elements
confusion = zeros(2,2); % True positives, false positives, etc.
confusion(1,1) = sum(VDA_labels & target(41:end) == 1); % True positives (known as known)
confusion(1,2) = sum(~VDA_labels & target(41:end) == 1); % False negatives (known as novel)
confusion(2,1) = sum(VDA_labels & target(41:end) ~= 1);  % False positives (novel as known)
confusion(2,2) = sum(~VDA_labels & target(41:end) ~= 1); % True negatives (novel as novel)

% Display results
accuracy = (confusion(1,1) + confusion(2,2)) / sum(confusion(:)); % Overall accuracy
disp('Confusion Matrix:');
disp(confusion);
disp(['Detection Accuracy: ', num2str(accuracy)]);

% Plot validation results
figure(3)
contour(X1, X2, reshape(resultaux, size(X1,1), size(X2,1)), [1, 1], 'Color', 'k'); % Decision boundary
hold on;
gscatter(data_PC(41:end,1), data_PC(41:end,2), VDA_labels, 'rg', 'xo', 8);         % Known (green) vs novel (red) in validation
title('kNN Validation for Novelty Detection');
xlabel('Feature #1');
ylabel('Feature #2');
hold off;