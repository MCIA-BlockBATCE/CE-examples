clear
clc
close all

% This script applies the k-nearest neighbor (k-NN) algorithm to classify
% data based on measurements across multiple features.
%
%   The code is organized into three parts:
%
%       Part 1. DATA INITIALISATION
%           Loads a dataset and assigns features and labels for classification.
%
%       Part 2. KNN CLASSIFICATION
%           A k-NN model is created with k=7 neighbors. Two new data points
%           are classified using the trained model.
%
%       Part 3. VISUALIZATION
%           Scatter plot displays classification results, marking the 
%           two new data points on the plot.
%

% ------------------------ Part 1 Data loading ------------------------

load fisheriris % Load dataset
X = meas; % Assign feature matrix to X.
Y = species; % Assign class labels to Y.

% ------------------------ Part 2 kNN Classification -------------------

% Obtain a k-NN classifier with 7 nearest neighbors and standardized features.
knn_mdl = fitcknn(X, Y, 'NumNeighbors', 7, 'Standardize', 1);

% Display model class names contained in knn_mdl.
knn_mdl.ClassNames 

% Define new measurements for prediction, representing two new data points.
xnew = [5.55 4 3 1; 5.25 2.5 3.75 1.2]; 

% Predict the class for the new data points using the k-NN model.
label = predict(knn_mdl, xnew);

% ------------------------ Part 3 Visualization -----------------------

% --- Two first features are represented ---
figure(1)
gscatter(X(:, 1), X(:, 2), Y);
hold on
plot(xnew(1, 1), xnew(1, 2), '-o', 'MarkerSize', 10) % Plot first new data point
plot(xnew(2, 1), xnew(2, 2), '-o', 'MarkerSize', 10) % Plot second new data point
xlabel('Sepal Length')
ylabel('Sepal Width')
title('k-NN Classification Results for Iris Dataset, sepal features')

% --- Two last features are represented ---
figure(2)
gscatter(X(:, 3), X(:, 4), Y);
hold on
plot(xnew(1, 3), xnew(1, 4), '-o', 'MarkerSize', 10) % Plot first new data point
plot(xnew(2, 3), xnew(2, 4), '-o', 'MarkerSize', 10) % Plot second new data point
xlabel('Petal Length')
ylabel('Petal Width')
title('k-NN Classification Results for Iris Dataset, petal features')