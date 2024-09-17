clear all
close all

load signal.mat
data = synthetic_signal';
signal_real = data;

steps = 2881;

data = data(1:steps,:);
t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t_dates = t1:minutes(15):t2;
t_dates = t_dates';


%% ANFIS
% 1h prediction (4 samples)

% inputs based on previous data
consumption_dif4 = zeros(steps,1);
previous_day = zeros(steps,1);
previous_sample = zeros(steps,1);
    
    for t=1:length(data) 
        
        % Differential consumption from the last 4 hours
        if t>=(4*4)+1
            consumption_dif4(t,1)=(data(t,1)-data(t-4*4,1));
        end
    
        % Consumption of current hour the previous day
        if t>=(4*24)+1
            previous_day(t,1)=(data(t-(4*24)));
        end

        % Consumption of previous sample
        if t>=2
            previous_sample(t,1) = data(t-1,1);
        end
    
    end

% group inputs and outputs into I/O matrix
% IO_matrix will be used from i=97 to i=672
IO_matrix(:,1) = previous_sample;
IO_matrix(:,2) = previous_day;
IO_matrix(:,3) = consumption_dif4;
IO_matrix(:,4) = data; % Output vector

% train/test split
IO_matrix_training = IO_matrix(97:2500,:);
IO_matrix_testing = IO_matrix(2500:steps,:);

% ANFIS
opt=anfisOptions('EpochNumber',5);
fis = anfis(IO_matrix_training,opt);
predicted_data_ANFIS_1H = evalfis(fis,IO_matrix_testing(:,1:3));
RMS_1h_ANFIS = rms(predicted_data_ANFIS_1H  - data(2500:steps,1));

% test data and prediction comparison
dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_1h_ANFIS};

figure(1)
plot(t_dates(2500:steps),predicted_data_ANFIS_1H , t_dates(2500:steps), data(2500:steps,1))
title("ANFIS model with forecasting horizon: 1 hour (4 steps)")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

clear IO_matrix

% 3h prediction (12 samples)

% use previous consumption data and inputs

% regroup into input/output matrix changing output vector
% IO_matrix will be used from i=97 to i=664
IO_matrix(:,1) = previous_sample(1:steps-2*4,1);
IO_matrix(:,2) = previous_day(1:steps-2*4,1);
IO_matrix(:,3) = consumption_dif4(1:steps-2*4,1);
IO_matrix(:,4) = data(1+2*4:steps,1); % Output vector

% train/test split (about 70/30)
IO_matrix_training = IO_matrix(97:2500,:);
IO_matrix_testing = IO_matrix(2500:steps-8,:);

% ANFIS
opt=anfisOptions('EpochNumber',5);
fis = anfis(IO_matrix_training,opt);
predicted_data_ANFIS_3h = evalfis(fis,IO_matrix_testing(:,1:3));
RMS_3h_ANFIS = rms(predicted_data_ANFIS_3h - data(2500:steps-8,1));

% test data and prediction comparison
dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_3h_ANFIS};
figure(2)
plot(t_dates(2500:steps-8), predicted_data_ANFIS_3h, t_dates(2500:steps-8), data(2500:steps-8,1))
title("ANFIS model with forecasting horizon: 3 hours (12 steps)")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

%% Recurrent neural net prediction 

% Step 1: Generate synthetic signal (sinusoidal with noise)
% load ConsProfileExample.mat
% signal_real = ConsProfileExample;

N = steps; % Number of points
t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t_dates = t1:minutes(15):t2;
t = t_dates';

% Step 2: Define the number of steps to predict
nStepsAhead = 4;  % Number of future steps to predict

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

RMS_1h_RNN = rms(err);

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_1h_RNN};

% Step 8: Plot the real signal against the predicted signal
figure(3);
subplot(2,1,1)
plot(t(1:numTrain - nStepsAhead), signal_real(1:numTrain - nStepsAhead), 'b', 'LineWidth', 1.5); hold on;
plot(t(1:numTrain - nStepsAhead), YPred, 'r--', 'LineWidth', 1.5);
legend('Measured signal', 'Predicted signal');
xlabel('Time');
ylabel('Power consumption [kW]');
title(['Comparison of Measured Signal vs Predicted Signal (', num2str(nStepsAhead), ' future steps)']);
annotation('textbox',dim,'String',str,'FitBoxToText','on');
grid on;
subplot(2,1,2)
plot(t(1:numTrain - nStepsAhead),err)
title('Error (Measured - Prediction)')
xlabel('Time');
ylabel('Error [%]');

clear err

% Step 2: Define the number of steps to predict
nStepsAhead = 12;  % Number of future steps to predict

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

RMS_3h_RNN = rms(err);

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_3h_RNN};

% Step 8: Plot the real signal against the predicted signal
figure(4);
subplot(2,1,1)
plot(t(1:numTrain - nStepsAhead,1), signal_real(1:numTrain - nStepsAhead,1), 'b', 'LineWidth', 1.5); hold on;
plot(t(1:numTrain - nStepsAhead,1), YPred, 'r--', 'LineWidth', 1.5);
legend('Measured signal', 'Predicted signal');
xlabel('Time');
ylabel('Power consumption [kW]');
title(['Comparison of Measured Signal vs Predicted Signal (', num2str(nStepsAhead), ' future steps)']);
annotation('textbox',dim,'String',str,'FitBoxToText','on');
grid on;
subplot(2,1,2)
plot(t(1:numTrain - nStepsAhead),err)
title('Error (Measured - Prediction)')
xlabel('Time');
ylabel('Error [%]');

%% Autoregressive integrated moving average prediction

data = data(1:steps,:);
t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t_dates = t1:minutes(15):t2;
t_dates = t_dates';

% 1h prediction (4 samples)
ConsProfileExample = data;

% Create model with 1 nonseasonal autoregressive polynomial degree, 1
% nonseasonal integration degree and 1 nonseasonal moving average
% polynomial degree
Mdl = arima(1,1,1);

% Fit model to data
idxpre = 1:Mdl.P;
idxest = (Mdl.P + 1):(2501-4);
EstMdl = estimate(Mdl,ConsProfileExample(idxest),...
    'Y0',ConsProfileExample(idxpre));


% Forecast consumption into 4 sample horizon using estimated model
% Last two observations in estimation data are specified as presample.
yf0 = ConsProfileExample(idxest(end - 1:end));
for t=1:381
    yf = forecast(EstMdl,4,yf0);
    ypred(t,1) = yf(4,1); % We keep 4th step prediction
    idxest = (Mdl.P + 1):(2501-4)+t;
    yf0 = ConsProfileExample(idxest(end - 1:end));
end

RMS_1h_ARIMA = rms(ypred  - ConsProfileExample(2501:2881,1));

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_1h_ARIMA};

% Plot of observations and forecast 
figure(5)
plot(t_dates(2501:2881),ypred,t_dates(2501:2881),ConsProfileExample(2501:2881));
title("ARIMA model with forecasting horizon: 1 hour (4 steps)")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

% 3h prediction (12 samples)
ConsProfileExample = data;

% Create model with 1 nonseasonal autoregressive polynomial degree, 1
% nonseasonal integration degree and 1 nonseasonal moving average
% polynomial degree
Mdl = arima(1,1,1);

% Fit model to data
idxpre = 1:Mdl.P;
idxest = (Mdl.P + 1):(2501-12);
EstMdl = estimate(Mdl,ConsProfileExample(idxest),...
    'Y0',ConsProfileExample(idxpre));


% Forecast consumption into 12 sample horizon using estimated model
% Last two observations in estimation data are specified as presample.
yf0 = ConsProfileExample(idxest(end - 1:end));
for t=1:381
    yf = forecast(EstMdl,12,yf0);
    ypred(t,1) = yf(12,1); % We keep 12th step prediction
    idxest = (Mdl.P + 1):(2501-12)+t;
    yf0 = ConsProfileExample(idxest(end - 1:end));
end

RMS_3h_ARIMA = rms(ypred  - ConsProfileExample(2501:2881,1));

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_3h_ARIMA};

% Plot of observations and forecast
figure(6)
plot(t_dates(2501:2881),ypred,t_dates(2501:2881),ConsProfileExample(2501:2881));
title("ARIMA model with forecasting horizon: 3 hour (12 steps)")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")


