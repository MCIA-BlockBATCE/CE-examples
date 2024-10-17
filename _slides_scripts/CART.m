clear all
close all

% This script demonstrates the use of a decision tree for classification.
% A decision tree is trained using a given set of features and target labels,
% and is then used to predict outcomes for new input data.
%
% The script is organized into four parts:
%
%   Part 1. DATA LOADING
%       This section loads the data used for training and testing the decision tree.
%
%   Part 2. TREE TRAINING
%       In this section, the classification decision tree is trained
%       based on the loaded dataset.
%
%   Part 3. TREE VISUALIZATION
%       The trained decision tree structure is visualized as a graph.
%
%   Part 4. PREDICTION
%       The trained model is used to make predictions on new input data.

%% -------------- Part 1 Data Loading --------------------

% Load the ionosphere dataset, which includes feature data (X) and target labels (Y)
load ionosphere  

% Load new input sample data (input_X) for making predictions
load input_sample_CART.mat  

%% -------------- Part 2 Tree Training --------------------

% Train a classification decision tree using the feature data (X) and
% corresponding labels (Y)
CMdl = fitctree(X,Y);

%% -------------- Part 3 Tree Visualization --------------------

% Visualize the trained decision tree structure as a graph
view(CMdl,'Mode','graph')

%% -------------- Part 4 Prediction ------------------------

% Use the trained classification model to predict the target labels for new
% input data (input_X)
Ynew = predict(CMdl,input_X);