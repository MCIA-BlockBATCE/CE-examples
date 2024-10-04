clear
clc
close all

% This script performs Linear Discriminant Analysis (LDA) on a dataset 
% to analyze fault severity classifications. LDA is used to find the 
% linear combinations of features that best separate the classes, 
% which include various fault conditions.
%
% The script is organized into three parts:
%
%   Part 1. DATA LOADING
%       This section loads the feature dataset and prepares the target labels 
%       for different fault classes.
%
%   Part 2. LDA CALCULATION
%       This section computes LDA by calculating the within-class and between-class 
%       scatter matrices, performs eigendecomposition, and projects the data 
%       onto a lower-dimensional space for visualization of class separability.
%
%   Part 3. VISUALIZATION
%       Scatter plot of the projected data on the lower-dimensional space.
%
%% ------------------ Part 1 Data Loading -------------------------
% Load data, containing features for fault type and severity, as well as a target
% label array and target names for fault types. Severity is not taken into account
% in the target labels.
load data_LDA.mat

% Transpose feature matrix for further use
FeaturesHIOBv3 = FeaturesHIOBv3';

%% ------------------ Part 2 LDA Calculation -----------------------------

X = FeaturesHIOBv3;
y = Targets1C;

% Compute scatter matrices
[Sw, Sb, Sm] = scatter_mat(X, y);

% Eigendecomposition and sorting of eigenvalues
[eig_vectors, eig_value_mat] = eig(inv(Sw) * Sb);
eig_values = diag(eig_value_mat); % Extract eigenvalues
[eig_values, ind] = sort(eig_values, 1, 'descend'); % Sort eigenvalues
eig_vectors = eig_vectors(:, ind); % Reorder eigenvectors according to sorted eigenvalues

% Project the data onto the LDA space
A = eig_vectors(:, 1:2);
FeaturesHIOB_LDA = A' * X;
FeaturesHIOB_LDA = FeaturesHIOB_LDA'; % Transpose for visualization purposes

%% ------------------ Part 3 Visualization -----------------------------

gscatter(FeaturesHIOB_LDA(:,1), FeaturesHIOB_LDA(:,2), Targets_names, 'rgbcmyk', 'xo*+sd><^', 6)
xlabel('Principal Component #1')
ylabel('Principal Component #2')
title('LDA Data Representation')