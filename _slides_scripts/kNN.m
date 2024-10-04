clear
clc
close all

% This script applies the k-nearest neighbor (k-NN) algorithm to Fisher's 
% iris dataset for classification. The dataset consists of sepal and petal 
% measurements for three different species of iris flowers.
%
% The script is organized into three parts:
%
%   Part 1. DATA INITIALISATION
%       Fisher's iris dataset for classification is loaded, containing
%       sepal and petal measurements as well as labels for each flower
%       species.
%
%   Part 2. KNN CLASSIFICATION
%       The model kNN model is trained using k=7 nearest neighbors. Two
%       new data points are created and the model is used to label them.
%
%   Part 3. VISUALIZATION
%       The results are visualized with two scatter plots of the sepal and
%       petal measurements.
%

%% ------------------------ Part 1 Data loading ----------------------

% Load the Fisher's iris dataset, which contains measurements of iris flowers.
load fisheriris 

% Assign features (measurements) to X and labels (species) to Y.
X = meas; % Feature matrix containing sepal and petal dimensions.
Y = species; % Class labels corresponding to the species of iris.

%% ------------------------ Part 2 kNN Classification -------------------

% Create a k-NN classification model using k=7 neighbors.
% Standardizing the features ensures they contribute equally to distance calculations.
k = 7;
knn_mdl = fitcknn(X, Y, 'NumNeighbors', k, 'Standardize', 1);

% Display the class names from the trained model.
knn_mdl.ClassNames 

% Define new data points for prediction, represented by their measurements.
xnew = [5.55 4 3 1; 5.25 2.5 3.75 1.2]; 

% Use the k-NN model to predict the species for the new data points.
label = predict(knn_mdl, xnew); 

%% ------------------------ Part 3 Visualization ----------------------

% --- Two first features are represented ---
figure(1)
gscatter(X(:, 1), X(:, 2), Y);
xlabel('Sepal Length')
ylabel('Sepal Width')
title('k-NN Classification Results for Iris Dataset, sepal features')

% --- Two last features are represented ---
figure(2)
gscatter(X(:, 3), X(:, 4), Y);
xlabel('Petal Length')
ylabel('Petal Width')
title('k-NN Classification Results for Iris Dataset, petal features')