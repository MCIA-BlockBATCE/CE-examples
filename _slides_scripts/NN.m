% TODO
% - Modificar primera secció perqué només carregui les dades. La part 1
% actual hauria d'estar ja feta, i per tant l'objecte ".mat" que es
% carregui ja tindra l'objecte Targets configurat. En aquest sentit,
% quan es carregui aquest ".mat", calen un parell de línies dient que conté dins
% les dades de diferents condicions d'operació de coixinets.
% - Separar en 4 seccions, (i) lectura de dades (ii) entrenament
% (iii) càlculd de mètriques (iv) visualització

clear
clc
clear all

% This script uses a neural network to classify different types of faults
% (healthy, inner fault, outer fault, ball fault) based on extracted features.
% The script is organized into two parts:
%
%   Part 1. FEATURE CLASSIFICATION
%       This section prepares the data and assigning class labels for various
%       fault types. It then separates the data into training and validation sets.
%
%   Part 2. NEURAL NETWORK TRAINING AND CLASSIFICATION
%       This section trains a neural network with the training data. After training, 
%       the network's performance is evaluated using the validation data. 
%       A decision boundary plot is generated to visualize classification regions.


%% -------------- Part 1 Feature Classification --------

% Load feature data
load FeaturesHIOB_LDA.mat

% Transpose feature matrix
FeaturesHIOv3 = FeaturesHIOB_LDA';

% Initialize target matrix for 4 fault categories: Healthy, Inner, Outer, and Ball faults
Targets = zeros(1200, 4);  % 1200 samples, 4 classes

% Assign binary class labels to each fault category
% Severity will not be taken into account in this case
Targets=zeros(1200,4);
Targets(1:120,1)=1;  %Class healthy
Targets(121:480,2)=1;%Class Inner Fault
Targets(481:840,3)=1;%Class Outer Fault
Targets(841:1200,4)=1;%Class Ball Fault

% Transpose the target matrix to match the format for neural network input
Targets = Targets';

% Define indices for training and validation sets
Training_index = [1:120-40, 121:240-40, 241:360-40, 361:480-40, ...
                  481:600-40, 601:720-40, 721:840-40, 841:960-40, ...
                  961:1080-40, 1081:1200-40];

Validation_index = [121-40:120, 241-40:240, 361-40:360, 481-40:480, ...
                    601-40:600, 721-40:720, 841-40:840, 961-40:960, ...
                    1081-40:1080, 1201-40:1200];

% Separate data into training and validation sets
Training_Data = FeaturesHIOv3(:, Training_index);   % Training features
Training_Targets = Targets(:, Training_index);      % Training labels

Validation_Data = FeaturesHIOv3(:, Validation_index); % Validation features
Validation_Targets = Targets(:, Validation_index);   % Validation labels

%% -------------- Part 2 Neural Network with Data------------------------

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

% Validate the network using the validation data
Simu_Net = Net(Validation_Data);

% Plot confusion matrix to evaluate classification performance
plotconfusion(Validation_Targets, Simu_Net, 'All Features')

% ---- Decision Boundary Visualization ----

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

% ---- Plot training data points with different markers for each class ----
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



