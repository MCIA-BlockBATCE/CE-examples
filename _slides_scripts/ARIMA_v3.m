% This script implements an iterative ARIMA model to forecast time series data.
% The model is configured to include nonseasonal autoregressive, 
% integrated, and moving average components. The code is structured into 
% the following parts:
%
%   PART 1. DATA LOADING
%       This section loads the time series data and prepares the time 
%       vector for plotting.
%
%   PART 2. MODEL CONFIGURATION
%       This section defines the ARIMA model parameters and fits the 
%       model to a subset of the data.
%
%   PART 3. ITERATIVE FORECASTING
%       This section generates forecasts iteratively, updating the 
%       model with each new set of predictions based on previously 
%       observed data.
%
%   PART 4. METRICS CALCULATION
%       This section calculates the root mean square error (RMSE) 
%       between the predicted and actual values if available.
%
%   PART 5. PLOTTING
%       This section visualizes the actual data and the forecasted values
%       on the same plot for comparison.

%% -------------- Part 1. Data Loading -------------------
% Load the time series data for energy consumption from the specified file.
load data_ARIMA.mat

% Define the time vector for the data range from May 1 to May 31, 2023,
% with 15-minute intervals.
t1 = datetime(2023, 5, 1, 0, 0, 0);
t2 = datetime(2023, 5, 31, 0, 0, 0);
t_dates = t1:minutes(15):t2; % Create datetime array
t_dates = t_dates'; % Convert to column vector

%% -------------- Part 2. Model Configuration -------------
% Set up the ARIMA model configuration.
P = 5; % Number of nonseasonal autoregressive terms (p)
D = 1; % Number of nonseasonal differencing terms (d)
Q = 1; % Number of nonseasonal moving average terms (q)
Mdl = arima(P, D, Q); % Create ARIMA model (5,1,1)

% Define the end index for the training range and forecasting parameters.
end_training_split = 400;  % Index to split training and test data
horizon = 10;              % Number of steps ahead for each forecast
total_forecasts = 100;     % Total points to forecast iteratively

% Fit model to the initial training data.
idxpre = 1:Mdl.P; % Indices for presample data
idxest = (Mdl.P + 1):end_training_split; % Indices for estimation data

% Estimate the model parameters using the training data subset.
EstMdl = estimate(Mdl, ConsProfileExample(idxest), 'Y0', ConsProfileExample(idxpre)); % Presample data

%% -------------- Part 3. Iterative Forecasting ------------
% Prepare to store forecasts and define starting point for forecasting.
forecast_array = [];  % Array to store rolling forecasts
forecast_start = end_training_split; % Start from the end of training data

% Iteratively forecast using previously observed data.
while length(forecast_array) < total_forecasts
    % Ensure there are enough points for presample data.
    if forecast_start - Mdl.P >= 1
        % Get the last P observations for presample.
        yf0 = ConsProfileExample(forecast_start - Mdl.P:forecast_start - 1); 
        
        % Forecast the next 'horizon' points using the ARIMA model.
        yf = forecast(EstMdl, horizon, yf0); 
        
        % Append the new forecast to the rolling forecast array.
        forecast_array = [forecast_array; yf]; 
        
        % Update the starting index for the next forecast iteration.
        forecast_start = forecast_start + horizon; 
    else
        break; % Exit loop if not enough data points are available for presample.
    end
end

%% -------------- Part 4. Metrics Calculation --------------
% Calculate the root mean square error (RMSE) if actual future values are available.
if end_training_split + total_forecasts <= length(ConsProfileExample)
    err = rms(forecast_array - ConsProfileExample(end_training_split + 1:end_training_split + length(forecast_array)));
end

%% -------------- Part 5. Plotting ------------------------
% Prepare time vector for plotting the forecasted values.
t_forecast_dates = t_dates(end_training_split + 1:end_training_split + length(forecast_array)); 

% Plot actual data and the rolling forecast.
figure(1)
plot(t_dates(1:length(ConsProfileExample)), ConsProfileExample, 'b', 'DisplayName', 'Actual Data')
hold on
plot(t_forecast_dates, forecast_array, 'r', 'LineWidth', 1.5, 'DisplayName', 'Forecast')
xlabel('Date')
ylabel('Energy [kWh]')
title('Iterative ARIMA Forecasting Using Only Observed Data')
legend('show')
