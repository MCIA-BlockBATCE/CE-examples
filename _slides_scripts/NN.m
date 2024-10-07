clear
clc
clear all

% This script trains and evaluates a neural network model to classify fault 
% types based on a feature dataset. The neural network is trained using a 
% subset of the training data and validated using validation data.
%
% The script is organized into four parts:
%
%   Part 1. DATA LOADING
%       This section loads the feature dataset and target labels, as well
%       as training and validation indexes.
%
%   Part 2. NEURAL NETWORK TRAINING
%       This section configures a neural network model, trains it using the 
%       training data, and evaluates its performance.
%
%   Part 3. METRICS
%       This section validates the performance of the neural network model
%       using validation data.
%
%   Part 4. VISUALIZATION
%       This section visualizes the results using a confusion matrix. 
%       It also plots decision boundaries to depict the classification regions
%       for different fault types alongside with some training data points.

%% -------------- Part 1 Data Loading --------
% Load data, containing features for fault type and severity, as well as a target
% label array fault types. Severity is not taken into account in the target labels.
% Training and validation indexes are loaded in order to later split the dataset.
load data_NN.mat

%% -------------- Part 2 Neural Network training -----------------------

% Separate data into training and validation sets
Training_Data = FeaturesHIOv3(:, Training_index);   % Training features
Training_Targets = Targets(:, Training_index);      % Training labels

Validation_Data = FeaturesHIOv3(:, Validation_index); % Validation features
Validation_Targets = Targets(:, Validation_index);   % Validation labels

% Set up neural network configuration
n = 10;               % Number of neurons in the hidden layer
trainFcn = 'trainrp'; % Training function: Resilient Backpropagation

% Training goals
epochs = 25;          % Maximum number of training epochs
min_err = 0.000001;   % Minimum error for stopping the training

% Create a feedforward neural network with 'n' hidden neurons
Net = feedforwardnet(n, trainFcn);

% Configure training parameters
Net.trainParam.epochs = epochs; % Number of training epochs
Net.trainParam.goal = min_err;  % Training goal (minimum error)

% Train the neural network using training data
[Net, TR] = train(Net, Training_Data, Training_Targets);

%% -------------- Part 3 Metrics ------------------------

% Validate the network using the validation data
Simu_Net = Net(Validation_Data);

%% -------------- Part 4 Visualization ------------------------

% ---- Confusion Matrix ----

plotconfusion(Validation_Targets, Simu_Net, 'All Features')

% ---- Decision Boundary with training data points ----

% Create a grid for plotting decision boundaries
x = min(FeaturesHIOv3(1,:))*2:0.001:max(FeaturesHIOv3(1,:))*2;
y = min(FeaturesHIOv3(2,:))*2:0.001:max(FeaturesHIOv3(2,:))*2; 
[X, Y] = meshgrid(x, y);
X = X(:);
Y = Y(:);
grid = [X Y];  % Flatten the grid for network input

% Classify each point in the grid using the trained network
Simu_Net2 = Net(grid');
[~, class] = max(Simu_Net2); 
class = class';
colors = ['g.'; 'm.'; 'b.'; 'y.'; 'r.'; 'k.'];

% Plot decision regions for each class
figure;
for i = 1:4
    thisX = X(class == i);
    thisY = Y(class == i);
    plot(thisX, thisY, colors(i,:));
    hold on
end

num_samples = 80; % Number of samples per class for plotting
Training_Data = Training_Data';

% Plot each class with distinct markers
hold on
p(1) = plot(Training_Data(1:num_samples, 1), Training_Data(1:num_samples, 2), 'square', ...
            'LineWidth', 1, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
p(2) = plot(Training_Data(num_samples+1:num_samples*4, 1), Training_Data(num_samples+1:num_samples*4, 2), 'diamond', ...
            'LineWidth', 1, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'm', 'MarkerSize', 8);
p(3) = plot(Training_Data(4*num_samples+1:num_samples*7, 1), Training_Data(4*num_samples+1:num_samples*7, 2), 'o', ...
            'LineWidth', 1, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'b', 'MarkerSize', 8);
p(4) = plot(Training_Data(7*num_samples+1:num_samples*10, 1), Training_Data(7*num_samples+1:num_samples*10, 2), 'hexagram', ...
            'LineWidth', 1, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'y', 'MarkerSize', 8);
hold off

legend(p(1:4))
ylim([min(Y) max(Y)])
xlim([min(X) max(X)])
xlabel('Dimension 1')
ylabel('Dimension 2') 
title('Decision regions for each class')
