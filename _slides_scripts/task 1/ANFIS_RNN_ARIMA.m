clear all
close all

load noise_signal.mat
data = synthetic_signal';

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
% 1h prediction (4 steps)

ConsProfileExample = data;

% XTrain = ConsProfileExample(1:596,1);
% TTrain = ConsProfileExample(5:600,1);
% 
% XTest = ConsProfileExample(597:668,1);
% TTest = ConsProfileExample(601:672,1);
% 1 STEP
XTrain = ConsProfileExample(1:2497,1);
TTrain = ConsProfileExample(4:2500,1);
 
XTest = ConsProfileExample(2498:steps-3,1);
TTest = ConsProfileExample(2501:steps,1);

layers = [
    sequenceInputLayer(1)
    lstmLayer(128)
    fullyConnectedLayer(1)];

options = trainingOptions("adam", ...
    MaxEpochs=100, ...
    SequencePaddingDirection="left", ...
    Verbose=false);

net = trainnet(XTrain,TTrain,layers,"mse",options);

Tpredict = predict(net,XTest);

RMS_1h_RNN = rms(Tpredict-TTest);

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_1h_RNN};

figure(3)
plot(t_dates(2501:steps), Tpredict, t_dates(2501:steps), TTest)
title("RNN model with forecasting horizon: 1 hour (4 steps)")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

% 3h prediction (12 steps)
% Load Consumption data
ConsProfileExample = data;


XTrain = ConsProfileExample(1:2488,1);
TTrain = ConsProfileExample(13:2500,1);

XTest = ConsProfileExample(2489:steps-12,1);
TTest = ConsProfileExample(2501:steps,1);

layers = [
    sequenceInputLayer(1)
    lstmLayer(128)
    fullyConnectedLayer(1)];

options = trainingOptions("adam", ...
    MaxEpochs=100, ...
    SequencePaddingDirection="left", ...
    Verbose=false);

net2 = trainnet(XTrain,TTrain,layers,"mse",options);

Tpredict = predict(net2,XTest);

RMS_3h_RNN = rms(Tpredict-TTest);

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_3h_RNN};

figure(4)
plot(t_dates(2501:steps), Tpredict, t_dates(2501:steps), TTest)
title("RNN model with forecasting horizon: 3 hour (12 steps)")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

%% Autoregressive integrated moving average prediction
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

