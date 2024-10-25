clear
clc
close all

%% RNN-based time series prediction
% This script implements an RNN model for multi-step prediction on time
% series data, structured into the following parts:
%
%   Part 1. DATA INITIALISATION
%       Synthetic signal is loaded and parameters for prediction are
%       defined.
%
%   Part 2. TRAINING DATA PREPARATION
%       Define the training data by preparing input and output sequences 
%       with an offset to allow multi-step predictions.
%
%   Part 3. RNN CONFIGURATION
%       The architecture of the RNN is defined, including layer and
%       training options.
%
%   Part 4. TRAINING AND PREDICTION
%       Train the RNN model on the training data and predict future values.
%
%   Part 5. VISUALIZATION
%       The measured and predicted data are plotted and compared, alongside
%       error calculation.


% ------------------------ Part 1 Data Initialisation --------------------

load data_RNN.mat % Load time series data
N = length(signal_real); % Number of data points

t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,8,0,0,0);
t_dates = t1:minutes(15):t2; % Define time range with 15-minute intervals
t = t_dates';

% Define number of steps for prediction
nStepsAhead = 10; % Predict 10 future steps

% -------------------- Part 2 Training Data Preparation ------------------

% Specify ratio of data for training and calculate training sample size
trainRatio = 0.8;
numTrain = floor(trainRatio * N);

% Prepare training inputs and outputs by shifting outputs by nStepsAhead
XTrain = signal_real(1:numTrain - nStepsAhead);
YTrain = signal_real((1+nStepsAhead):numTrain);

% Convert data to cell arrays for RNN training
XTrain = num2cell(XTrain);
YTrain = num2cell(YTrain);

% ---------------------- Part 3 RNN Configuration ------------------------

inputSize = 1; % Single feature input
numHiddenUnits = 100; % Number of hidden units in LSTM layer
numResponses = 1; % Single output

% Specify the RNN layer structure using LSTM layers for sequence learning
layers = [ ...
    sequenceInputLayer(inputSize)
    lstmLayer(numHiddenUnits,'OutputMode','sequence')
    fullyConnectedLayer(numResponses)
    regressionLayer];

% Set training options for RNN
options = trainingOptions('adam', ...
    'MaxEpochs', 200, ...
    'GradientThreshold', 1, ...
    'InitialLearnRate', 0.01, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.2, ...
    'LearnRateDropPeriod', 50, ...
    'Verbose', 0, ...
    'Plots', 'training-progress');

% ------------------ Part 4 Training and Prediction ----------------------

% Train the RNN model
net = trainNetwork(XTrain, YTrain, layers, options);

% Predict future values using the trained network
YPred = predict(net, XTrain);

% Convert predictions to a vector format for plotting
YPred = cell2mat(YPred);
Ypred = YPred';

% Calculate error as percentage difference between real and predicted values
for i = 1:(numTrain - nStepsAhead)
    err(i,1) = 100 * (signal_real(i) - YPred(i)) / signal_real(i);
end

% ------------------------ Part 5 Visualization --------------------------

figure(1)
% Subplot for signal comparison
subplot(2,1,1)
plot(t(1:numTrain - nStepsAhead), signal_real(1:numTrain - nStepsAhead), 'b', 'LineWidth', 1.5); hold on;
plot(t(1:numTrain - nStepsAhead), YPred, 'r--', 'LineWidth', 1.5);
legend('Measured signal', 'Predicted signal');
xlabel('Time');
ylabel('Power consumption [kW]');
title(['Comparison of Measured Signal vs Predicted Signal (', num2str(nStepsAhead), ' future steps)']);
grid on;

% Subplot for prediction error over time
subplot(2,1,2)
plot(t(1:numTrain - nStepsAhead), err)
title('Error (Measured - Prediction)')
xlabel('Time');
ylabel('Error [%]');
