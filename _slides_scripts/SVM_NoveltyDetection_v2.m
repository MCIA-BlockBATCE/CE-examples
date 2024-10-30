close all  
clear      
clc           

% This script performs Support Vector Machine (SVM)-based novelty detection.
% The approach involves training an SVM model on known class data and
% identifying novel data points based on their position relative to the SVM decision boundary.
%
% The code is organized into the following sections:
%
%   PART 1. DATA LOADING
%       This section loads the feature dataset, containing features and
%       target labels for each class.
%
%   PART 2. DATA PREPROCESSING
%       Reduces data dimensions using Principal Component Analysis (PCA) for easier visualization.
%       Unlike "SVM_NoveltyDetection.mat", all features are taken into
%       account when performing PCA (8 features --> 2 features)
%
%   PART 3. MODEL TRAINING
%       Sets up the SVM model, defining known data points and setting the model parameters.
%
%   PART 4. NOVELTY DETECTION AND PLOTTING
%       Uses SVM to classify new points as "known" or "novel".
%       Plots the decision boundary and identifies novel points in the validation data.
%
%   PART 5. VALIDATION AND PERFORMANCE
%       Validates the SVM model and calculates accuracy metrics.

%% -------------- Part 1. Data Loading ----------------
% Load data, containing features for fault type and severity, as well as a target
% label array with target names for fault types. Severity is not taken into account
% in the target labels.
load data_SVM_NoveltyDetection.mat; 

%% -------------- Part 2. Data Preprocessing -------------
data_norm = Mat_Normalizada_val(:, 1:8); % Using all features

% Perform PCA to reduce data dimensions for visualization
DataCov = cov(data_norm);                 % Calculate covariance matrix
[PC, variances, explained] = pcacov(DataCov); % Apply PCA and get explained variance

% Display explained variance for each principal component
disp('Explained variance by each principal component (%):');
disp(explained');

% Retain only the first two principal components based on explained variance
z = 2;                                    % Number of principal components to retain
PC = PC(:, 1:z);                          % Select first two principal components
data_PC = data_norm * PC;                 % Project data into principal component space

% Plot data in 2D for visualization
figure(1);
gscatter(data_PC(:, 1), data_PC(:, 2), Targets_names, 'rgbcmyk', 'xo*+sd><^', 6);
xlabel('Feature #1');
ylabel('Feature #2');
title('PCA-Based Data Representation');

%% -------------- Part 3. Model Training ----------------
% Set up the SVM model parameters for novelty detection
D = data_PC(1:40, :);                     % Use first 40 samples as the training data
Y = ones(size(D, 1), 1);                  % Create labels for known data (all ones)
model = fitcsvm(D, Y, 'KernelFunction', 'RBF', 'KernelScale', 'auto', 'ClassNames', {'1', '0'}, 'OutlierFraction', 0.05);

% Generate a grid for decision boundary visualization
n = 1500;                                 % Number of points in grid for boundary plot
x1 = linspace(2 * min(data_PC(:, 1)) - 30, max(data_PC(:, 1)) + 30, n); % Grid for first principal component
x2 = linspace(2 * min(data_PC(:, 2)) - 10, max(data_PC(:, 2)) + 10, n);  % Grid for second principal component
[X1, X2] = meshgrid(x1, x2);
XG = [X1(:), X2(:)];                      % Create meshgrid for contour plotting

% Predict labels for the grid points using the trained SVM model
[labels, ~] = predict(model, XG);         % Get predicted labels for grid points
class = zeros(size(labels));               % Initialize class variable for known/novel classification
for cont = 1:length(labels)
    if labels{cont} == '1'                % Classify points based on predicted labels
        class(cont, 1) = 1;                % Known class
    end
end

%% -------------- Part 4. Novelty Detection and Plotting --------------
% Plot decision boundary and known vs novel data points
figure(2);
title('SVM Novelty Detection');
xlabel('Feature #1');
ylabel('Feature #2');
set(gca, 'Color', 'w'); % Set background color
hold on;
contour(X1, X2, reshape(class, size(X1, 1), size(X2, 1)), [1, 1], 'Color', 'k'); % Plot decision boundary
gscatter(D(:, 1), D(:, 2), [], 'b', 'o'); % Known class points (shown in blue)
hold off;

%% -------------- Part 5. Validation and Performance -----------------
% Classify validation data based on distance to known class
VDA = data_PC(41:end, :);                  % Validation data
VTA = target(41:end);                      % True labels for validation data ('1' for healthy)

% Get predictions for validation data using the SVM model
[labels_val, ~] = predict(model, VDA);     % Get predictions

% Convert cell array to string array for comparison
labels_val_str = string(labels_val);        % Convert labels_val from cell to string

% Initialize confusion matrix elements
confusion = zeros(2, 2); % Format: [TP, FN; FP, TN]

% Calculate confusion matrix elements
confusion(1, 1) = sum(labels_val_str == '1' & VTA == 1);  % True Positives (healthy classified as healthy)
confusion(1, 2) = sum(labels_val_str ~= '1' & VTA == 1);  % False Negatives (healthy classified as novel)
confusion(2, 1) = sum(labels_val_str == '1' & VTA ~= 1);  % False Positives (novel classified as healthy)
confusion(2, 2) = sum(labels_val_str ~= '1' & VTA ~= 1);  % True Negatives (novel classified as novel)

% Calculate accuracy metrics
accuracy = (confusion(1, 1) + confusion(2, 2)) / sum(confusion(:)); % Overall accuracy

% Display results
disp('Confusion Matrix:');
disp(confusion);
disp(['Detection Accuracy: ', num2str(accuracy)]);

% Plot validation results
figure(3);
contour(X1, X2, reshape(class, size(X1, 1), size(X2, 1)), [1, 1], 'Color', 'k'); % Decision boundary
hold on;
gscatter(VDA(:, 1), VDA(:, 2), labels_val, 'rg', 'xo', 8); % Known (green) vs novel (red) in validation
title('SVM Validation for Novelty Detection');
xlabel('Feature #1');
ylabel('Feature #2');
hold off;
