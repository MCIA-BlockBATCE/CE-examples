clear
clc
close all

% This script configures, trains, and evaluates a neural network for 
% multi-class classification using k-fold cross-validation. The dataset 
% includes features and corresponding target labels. Each k-fold iteration
% splits data into training and testing sets, with performance metrics
% calculated after each fold.
%
% The script is organized into four parts:
%
%   Part 1. DATA LOADING AND PREPERATION
%       Load the feature dataset and labels for each class
%
%   Part 2. Neural Network Configuration
%       Configure the neural network architecture and training parameters.
%
%   Part 3. k-Fold Cross-Validation and Training
%       Split the data into k folds, train the network on each fold, and 
%       compute performance metrics (accuracy, precision, recall, and specificity).
%
%   Part 4. Visualization
%       Plot performance metrics for each fold and the average across folds.
%

%% -------------- Part 1: Data Loading and Preparation ---------------
% Load data, containing features for fault type classes (healthy, inner fault, 
% outer fault and ball fault), as well as a target label array and target
% names for each class.

load data_KFold.mat 

%% -------------- Part 2: Neural Network Configuration ---------------

% Neural network parameters
n = 10;                   % Number of neurons in the hidden layer
trainFcn = 'trainrp';     % Training function: Resilient Backpropagation
epochs = 25;              % Maximum number of epochs
min_err = 1e-6;           % Minimum training error

% Define the neural network and its training configuration
Net = patternnet(n, trainFcn);
Net.divideParam.trainRatio = 1;  % Full training set (no validation/test split)
Net.divideParam.valRatio = 0;    
Net.divideParam.testRatio = 0;   
Net.trainParam.epochs = epochs;  % Set number of epochs
Net.trainParam.goal = min_err;   % Set training goal (minimum error)

%% -------------- Part 3: k-Fold Cross-Validation and Training ------------

% Set up cross-validation
x = FeaturesHIOB_LDA;               % Input features
y = Targets_names;                  % Target labels
k = 3;                              % Number of folds for cross-validation
c = cvpartition(y, 'kFold', k, 'Stratify', true);

% Initialize storage for metrics
AccuracyALL = zeros(1, k);
PrecisionALL = zeros(1, k);
RecallALL = zeros(1, k);
SpecificityALL = zeros(1, k);

% Loop over each fold
for i = 1:k
    % Split data into training and test sets for the current fold
    trIdx = c.training(i);
    teIdx = c.test(i);
    xTrain = x(trIdx, :)';
    yTrain = dummyvar(grp2idx(y(trIdx)))';
    xTest = x(teIdx, :)';
    yTest = dummyvar(grp2idx(y(teIdx)))';
    yTest2 = Targets1C(teIdx); % True labels for calculating metrics

    % Train the neural network
    Net = train(Net, xTrain, yTrain);
    yPred = Net(xTest);  % Network prediction on test data
    
    % Plot confusion matrix for the current fold
    figure
    plotconfusion(yTest, yPred, 'All Features')
    hold off
    
    % Calculate metrics for current fold
    [~, Predicted_Labels] = max(yPred, [], 1);
    Conf_Mat = confusionmat(yTest2, Predicted_Labels);

    Accuracy = sum(diag(Conf_Mat)) / sum(Conf_Mat(:));
    Precision = mean(diag(Conf_Mat) ./ sum(Conf_Mat, 1)');
    Recall = mean(diag(Conf_Mat) ./ sum(Conf_Mat, 2));
    Specificity = mean((sum(Conf_Mat(:)) - sum(Conf_Mat, 2) - sum(Conf_Mat, 1)' + diag(Conf_Mat)) ./ (sum(Conf_Mat(:)) - sum(Conf_Mat, 2)));

    % Display metrics for the current fold
    disp(['Accuracy: ', num2str(Accuracy)]);
    disp(['Precision: ', num2str(Precision)]);
    disp(['Recall: ', num2str(Recall)]);
    disp(['Specificity: ', num2str(Specificity)]);
    
    % Store metrics
    AccuracyALL(i) = Accuracy;
    PrecisionALL(i) = Precision;
    RecallALL(i) = Recall;
    SpecificityALL(i) = Specificity;
end

% Average metrics across all folds
AccuracyAVG = mean(AccuracyALL);
PrecisionAVG = mean(PrecisionALL);
RecallAVG = mean(RecallALL);
SpecificityAVG = mean(SpecificityALL);

%% -------------- Part 4: Visualization ------------------------

% Plot performance metrics for each fold and average values

figure
bar(AccuracyALL)
xlabel('k-th iteration')
ylabel('Accuracy')
title(['Avg Accuracy, K-fold crossvalidation = ', num2str(AccuracyAVG)])

figure
bar(PrecisionALL)
xlabel('k-th iteration')
ylabel('Precision')
title(['Avg Precision, K-fold crossvalidation = ', num2str(PrecisionAVG)])

figure
bar(RecallALL)
xlabel('k-th iteration')
ylabel('Recall')
title(['Avg Recall, K-fold crossvalidation = ', num2str(RecallAVG)])

figure
bar(SpecificityALL)
xlabel('k-th iteration')
ylabel('Specificity')
title(['Avg Specificity, K-fold crossvalidation = ', num2str(SpecificityAVG)])
