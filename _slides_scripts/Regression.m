% This script applies linear regression to a pre-loaded dataset. 
% It is organized into three parts:
%
%   Part 1. DATA LOADING
%       The dataset for regression is loaded from an external file.
%
%   Part 2. MODEL FITTING
%       A linear regression model is fitted to the data. The fitted model 
%       is then plotted alongside the data.
%
%   Part 3. PREDICTION AND VISUALIZATION
%       A new prediction is made using the fitted model and visualized.

%% -------------- Part 1 Data Loading --------------------
% Load the dataset containing the incoming (x) and outcoming (y) flow data
% for a synthetic pipe model
load data_Regression.mat % 'x' and 'y' represent the incoming and outcoming flows, respectively

%% -------------- Part 2 Model Fitting --------------------
% Fit a first-degree polynomial (linear regression) to the loaded data
p = polyfit(x,y,1); % p contains the coefficients of the linear model

% Evaluate the fitted polynomial across the range of x-values
f = polyval(p,x); % f represents the predicted outcoming flows based on the model

% Plot the original data points and the linear fit
plot(x,y,'o',x,f,'-') % 'o' for data points, '-' for the linear fit line
title('Linear regression for synthetic pipe model','Interpreter','latex');
xlabel('incoming flow [LPS]','Interpreter','latex');
ylabel('outcoming flow [LPS]','Interpreter','latex');

%% -------------- Part 3 Prediction and Visualization --------------------
% Make a prediction for a new incoming flow value using the fitted model
new_incoming_flow = 42;
predicted_flow = polyval(p,new_incoming_flow); % Predict outcoming flow for the new data point

% Add the predicted value to the plot
hold on;
plot(new_incoming_flow,predicted_flow,'gx', 'MarkerSize', 10, 'LineWidth', 3) % Green 'x' for the predicted point
legend('data','linear fit','prediction','Interpreter','latex') % Add legend to explain plot elements