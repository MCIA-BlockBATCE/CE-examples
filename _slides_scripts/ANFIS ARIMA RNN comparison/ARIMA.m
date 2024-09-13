clear all
close all

%% Autoregressive integrated moving average prediction
% Load US equity indices dataset
load ConsProfileExample.mat

% Create model with 1 nonseasonal autoregressive polynomial degree, 1
% nonseasonal integration degree and 1 nonseasonal moving average
% polynomial degree
Mdl = arima(1,1,1);

% Fit model to data
idxpre = 1:Mdl.P;
idxest = (Mdl.P + 1):600;
EstMdl = estimate(Mdl,ConsProfileExample(idxest),...
    'Y0',ConsProfileExample(idxpre));


% Forecast closing values into 500-day horizon using estimated model.
% Last two observations in estimation data are specified as presample.
yf0 = ConsProfileExample(end - 1:end);
yf = forecast(EstMdl,72,yf0);

% Plot of 2000 first observations and forecast
figure(1)
plot(1:72,yf,1:72,ConsProfileExample(601:672));
title("ARIMA model with forecasting horizon: 1 hour (4 steps)")
xlabel("Time [h]")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

