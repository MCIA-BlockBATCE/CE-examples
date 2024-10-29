% This script implements an ARIMA model to forecast time series data.
% The model is configured to include nonseasonal autoregressive, 
% integrated, and moving average components. The code is structured into 
% the following parts:
%
%   PART 1. DATA LOADING
%       This section loads the time series data and prepares the time 
%       vector for plotting.
%
%   PART 2. MODEL CONFIGURATION
%       This section defines the ARIMA model parameters, estimates the 
%       model based on a subset of the data, and prepares the presample 
%       data for forecasting.
%
%   PART 3. FORECASTING
%       This section generates forecasts based on the estimated model 
%       using the last observations as presample data.
%
%   PART 4. METRICS CALCULATION
%       This section calculates the root mean square error (RMSE) 
%       between the predicted and actual values.
%
%   PART 5. PLOTTING
%       This section visualizes the actual data and the forecasted values
%       on the same plot for comparison.

%% -------------- Part 1. Data Loading --------
% Load the time series data for energy consumption from the specified file.
load ConsProfileExample.mat

% Define the time vector for the data range from May 1 to May 31, 2023,
% with 15-minute intervals.
t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t_dates = t1:minutes(15):t2; % Create datetime array
t_dates = t_dates';

%% -------------- Part 2. Model Configuration ----------------
% Set up the ARIMA model configuration.
poly = 5; % Number of nonseasonal autoregressive terms
Mdl = arima(poly, 1, 1); % Create ARIMA model (p=5, d=1, q=1)

% Split the data for model estimation.
end_training_split = 400; % Index to split training and test data
idxpre = 1:Mdl.P; % Indices for presample data
idxest = (Mdl.P + 1):end_training_split; % Indices for estimation data

% Estimate the model parameters using the training data subset.
EstMdl = estimate(Mdl, ConsProfileExample(idxest),...
    'Y0', ConsProfileExample(idxpre)); % Presample data

%% -------------- Part 3. Forecasting -----------------------
% Specify the last observations to use as presample data for forecasting.
yf0 = ConsProfileExample(idxest(end - (poly + 1):end)); % Last observations for presample
horizon = 100; % Define the forecasting horizon (number of steps ahead)
yf = forecast(EstMdl, horizon, yf0); % Generate forecasts

%% -------------- Part 4.Metrics Calculation ----------------
% Calculate the root mean square error (RMSE) of the forecast.
err = rms(yf - ConsProfileExample(end_training_split:end_training_split + length(yf) - 1)); % RMSE calculation

%% -------------- Part 5. Plotting -------------------------
% Plot the first 2000 observations alongside the forecasted values.
figure(1)
h1 = plot(t_dates(1:length(ConsProfileExample)), ConsProfileExample(1:end)); 
hold on
h2 = plot(t_dates(end_training_split:end_training_split + horizon - 1), yf, 'r');
xlabel('Date') % Label for x-axis
ylabel('Energy [kWh]') 
title('ARIMA Forecasting') 
