clear all
close all

% This script demonstrates the application of an Adaptive Neuro-Fuzzy Inference
% System (ANFIS) for time series forecasting. The goal is to predict future values
% based on past samples and statistical features, such as moving averages,
% extracted from the data. External inputs (not extracted from the data) could
% be used to improve prediction, such as external temperature affecting energy
% consumption or environmental factors in industrial processes

% The script is divided into five sections:

%   Part 1. DATA LOADING
%       Load the dataset containing the time series data to be processed.

%   Part 2. FEATURE EXTRACTION
%       Generate relevant features for model training, including past samples and moving 
%       averages over different ranges. Additional external inputs could also be incorporated 
%       at this stage for improved prediction accuracy.

%   Part 3. MODEL TRAINING
%       Split the dataset into training and testing subsets, and then train an ANFIS model 
%       using the training data.

%   Part 4. MODEL EVALUATION
%       Evaluate the performance of the trained ANFIS model on the test data and compute 
%       error metrics (e.g., Root Mean Square Error).

%   Part 5. VISUALIZATION
%       Plot the predicted values against the actual data and display the model's performance metrics.


%% -------------- Part 1 Data Loading --------------------

% Load the data for processing
load signal.mat  
data = synthetic_signal;

%% -------------- Part 2 Feature Extraction --------------------

% Define indices for extracting previous samples and means
start_i = 100;  % Starting index for feature extraction
end_i = 500;    % Ending index for feature extraction

% Extract previous samples and calculate mean values over specified ranges
for i = 101:500
    previous_sample(1,i-start_i) = data(1,i-1);                 % Previous sample
    previous_5th_sample(1,i-start_i) = data(1,i-5);            % Sample from 5 steps back
    previous_20th_sample(1,i-start_i) = data(1,i-20);          % Sample from 20 steps back
    previous_50th_sample(1,i-start_i) = data(1,i-50);          % Sample from 50 steps back
    mean_last_5_samples(1,i-start_i) = mean(data(1,i-5:i));    % Mean of last 5 samples
    mean_last_20_samples(1,i-start_i) = mean(data(1,i-20:i));  % Mean of last 20 samples
    mean_last_50_samples(1,i-start_i) = mean(data(1,i-50:i));  % Mean of last 50 samples
end

% Group inputs and outputs into I/O matrix
IO_matrix(:,1) = previous_sample;
IO_matrix(:,2) = previous_5th_sample;
IO_matrix(:,3) = previous_20th_sample;
IO_matrix(:,4) = previous_50th_sample;
IO_matrix(:,5) = mean_last_5_samples;
IO_matrix(:,6) = mean_last_20_samples;
IO_matrix(:,7) = mean_last_50_samples;
IO_matrix(:,8) = data(101:500); % Output vector

% Additional inputs such as external factors could also be incorporated at this stage.
% For example, if the data represents energy consumption, external temperature or time-of-day 
% could be used as additional features to improve prediction accuracy.

%% -------------- Part 3 Model Training --------------------

% Define split indices for training and testing sets
start_testing_split = 300;  % Start index for testing data
end_testing_split = 400;     % End index for testing data

% Create training and testing sets from the input/output matrix
IO_matrix_training = IO_matrix(1:250,:);                % Training data (first 250 samples)
IO_matrix_testing = IO_matrix(start_testing_split:end_testing_split,:);  % Testing data (next 100 samples)

% Configure training options for ANFIS
opt = anfisOptions('EpochNumber', 5);  % Set the number of training epochs

% Train the ANFIS model using the training dataset
fis = anfis(IO_matrix_training, opt);

%% -------------- Part 4 Model Evaluation --------------------

% Evaluate the trained ANFIS model on the testing data
predicted_data = evalfis(fis, IO_matrix_testing(:,1:7));  % Predictions based on the test features

% Extract actual data for comparison
data_for_predictions = data(start_i + start_testing_split:end_testing_split + start_i);

% Calculate the Root Mean Square Error (RMSE) between predicted and actual data
RMS_1h = rms(predicted_data' - data_for_predictions);


%% -------------- Part 5 Visualization --------------------

% RMSE annotation
dim = [0.15 0.5 0.5 0.4];
str = {'RMSE' RMS_1h};

% Plot the predicted data against actual data
figure(1)
plot(1:length(predicted_data), predicted_data', 1:length(predicted_data), data_for_predictions)
title("ANFIS model with forecasting horizon: 1 step")
annotation('textbox', dim, 'String', str, 'FitBoxToText', 'on');
xlim([1 length(predicted_data)])  
xlabel("Time [q]")                 
ylabel("Power consumption [kW]")   
legend("Predicted consumption data", "Actual consumption data")  