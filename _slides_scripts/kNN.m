% TODO
% - Capçalera al script
% - Separar en 3 seccions, (i) lectura de dades (iii) entrenament (iii) visualització
% calcul de metriques??? emprar part del dataset per validar?

clear
clc
close all

% This script applies the k-nearest neighbor (k-NN) algorithm to Fisher's 
% iris dataset for classification. The dataset consists of sepal and petal 
% measurements for three different species of iris flowers. The model is 
% trained using k=7 nearest neighbors, and predictions are made for new data points. 
% The results are visualized with a scatter plot of the sepal and petal measurements.

%% -------------- Part 1 Data loading --------

% Load the Fisher's iris dataset, which contains measurements of iris flowers.
load fisheriris 

% Assign features (measurements) to X and labels (species) to Y.
X = meas; % Feature matrix containing sepal and petal dimensions.
Y = species; % Class labels corresponding to the species of iris.

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

% --- Plotting the classification results ---

% Two first features are represented
figure(1)
gscatter(X(:, 1), X(:, 2), Y);
xlabel('Sepal Length')
ylabel('Sepal Width')
title('k-NN Classification Results for Iris Dataset, sepal features')

% Two last features are represented
figure(2)
gscatter(X(:, 3), X(:, 4), Y);
xlabel('Petal Length')
ylabel('Petal Width')
title('k-NN Classification Results for Iris Dataset, petal features')