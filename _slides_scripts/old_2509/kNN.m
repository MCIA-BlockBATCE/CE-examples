clear all
close all

%% k-nearest neighbor classifier for Fisher's iris data 
load fisheriris % Load Fisher's iris data.
X = meas; Y = species;

% obtain knn classiication model for k=7 (# of nearest neighbors).
knn_mdl = fitcknn(X,Y,'NumNeighbors',7,'Standardize',1);

% knn_mdl is a ClassificationKNN classifier. 
knn_mdl.ClassNames %To access the properties of the model

%	Prediction for new data points
xnew = [5.55 4 3 1; 5.25 2.5 3.75 1.2]; % predict for two new data points 
label = predict(knn_mdl,xnew);

% plot
figure(1)
gscatter(X(:,1), X(:,2), Y);
xlabel('Sepal Length')
ylabel('Sepal Witdth')
title('k-NN Classification Resuls for Iris dataset')
