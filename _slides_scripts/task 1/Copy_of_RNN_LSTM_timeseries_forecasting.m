
% Clear workspace
clear; clc; close all;

% Step 1: Generate synthetic signal (sinusoidal with noise)
load ConsProfileExample.mat
signal_real = ConsProfileExample;

N = length(signal_real); % Number of points
t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,8,0,0,0);
t_dates = t1:minutes(15):t2;
t = t_dates';

% Step 2: Define the number of steps to predict
nStepsAhead = 1;  % Number of future steps to predict

% Step 3: Create training data
trainRatio = 0.8;
numTrain = floor(trainRatio * N);

% Training inputs (XTrain) and outputs shifted nStepsAhead (YTrain)
XTrain = signal_real(1:numTrain - nStepsAhead);
YTrain = signal_real((1+nStepsAhead):(numTrain)); % Values shifted nStepsAhead

% Convert to cell format for RNN (sequence)
XTrain = num2cell(XTrain);
YTrain = num2cell(YTrain);

% Step 4: Define the RNN structure
inputSize = 1;
numHiddenUnits = 100;
numResponses = 1;

layers = [ ...
    sequenceInputLayer(inputSize)
    lstmLayer(numHiddenUnits,'OutputMode','sequence')
    fullyConnectedLayer(numResponses)
    regressionLayer];

% Step 5: Configure training options
options = trainingOptions('adam', ...
    'MaxEpochs', 200, ...
    'GradientThreshold', 1, ...
    'InitialLearnRate', 0.01, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.2, ...
    'LearnRateDropPeriod', 50, ...
    'Verbose', 0, ...
    'Plots', 'training-progress');

% Step 6: Train the network
net = trainNetwork(XTrain, YTrain, layers, options);

% Step 7: Predict multiple future steps
YPred = predict(net, XTrain);

% Convert to vector format for plotting
YPred = cell2mat(YPred);
Ypred = YPred';

for i = 1:(numTrain-nStepsAhead)
    err(i,1) = 100*(signal_real(i) - YPred(i))/signal_real(i);
end


% Step 8: Plot the real signal against the predicted signal
figure;
subplot(2,1,1)
plot(t(1:numTrain - nStepsAhead), signal_real(1:numTrain - nStepsAhead), 'b', 'LineWidth', 1.5); hold on;
plot(t(1:numTrain - nStepsAhead), YPred, 'r--', 'LineWidth', 1.5);
legend('Measured signal', 'Predicted signal');
xlabel('Time');
ylabel('Power consumption [kW]');
title(['Comparison of Measured Signal vs Predicted Signal (', num2str(nStepsAhead), ' future steps)']);
grid on;
subplot(2,1,2)
plot(t(1:numTrain - nStepsAhead),err)
title('Error (Measured - Prediction)')
xlabel('Time');
ylabel('Error [%]');
