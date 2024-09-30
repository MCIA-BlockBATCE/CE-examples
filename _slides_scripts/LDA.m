clear
clc
close all

% This script performs Linear Discriminant Analysis (LDA) on a dataset 
% to analyze fault severity classifications. LDA is used to find the 
% linear combinations of features that best separate the classes, 
% which include various fault severities and healthy conditions.
%
% The script is organized into two parts:
%
%   Part 1. DATA INITIALISATION
%       This section loads the feature dataset and prepares the target labels 
%       for different fault severity classes
%
%   Part 2. LDA CALCULATION
%       This section computes LDA by calculating the within-class and between-class 
%       scatter matrices, performs eigendecomposition, and projects the data 
%       onto a lower-dimensional space for visualization of class separability.
%
%% -------------- Part 1 Data Initialization --------
% Load data
load FeaturesHIOBv3.mat

% Transpose feature matrix
FeaturesHIOBv3 = FeaturesHIOBv3';

% Define target labels for each fault severity class
Targets1C(1:120,1) = 1;  % Class healthy
Targets1C(121:240,1) = 2; % Class Inner Fault Severity 1
Targets1C(241:360,1) = 2; % Class Inner Fault Severity 2
Targets1C(361:480,1) = 2; % Class Inner Fault Severity 3
Targets1C(481:600,1) = 3; % Class Outer Fault Severity 1
Targets1C(601:720,1) = 3; % Class Outer Fault Severity 2
Targets1C(721:840,1) = 3; % Class Outer Fault Severity 3
Targets1C(841:960,1) = 4; % Class Ball Fault Severity 1
Targets1C(961:1080,1) = 4; % Class Ball Fault Severity 2
Targets1C(1081:1200,1) = 4; % Class Ball Fault Severity 3
Targets1C = Targets1C'; % Transpose to match feature matrix orientation

% Create target name labels
Targets_names = cell(1200,1); % Preallocate for efficiency
Targets_names(1:120,1) = {'Healthy'};  % Class healthy
Targets_names(121:240,1) = {'Inner Fault Severity 1'}; % Class Inner Fault Severity 1
Targets_names(241:360,1) = {'Inner Fault Severity 2'}; % Class Inner Fault Severity 2
Targets_names(361:480,1) = {'Inner Fault Severity 3'}; % Class Inner Fault Severity 3
Targets_names(481:600,1) = {'Outer Fault Severity 1'}; % Class Outer Fault Severity 1
Targets_names(601:720,1) = {'Outer Fault Severity 2'}; % Class Outer Fault Severity 2
Targets_names(721:840,1) = {'Outer Fault Severity 3'}; % Class Outer Fault Severity 3
Targets_names(841:960,1) = {'Ball Fault Severity 1'}; % Class Ball Fault Severity 1
Targets_names(961:1080,1) = {'Ball Fault Severity 2'}; % Class Ball Fault Severity 2
Targets_names(1081:1200,1) = {'Ball Fault Severity 3'}; % Class Ball Fault Severity 3

%% -------------- Part 2 LDA Calculation --------

X = FeaturesHIOBv3;
y = Targets1C;

% Compute scatter matrices
[Sw, Sb, Sm] = scatter_mat(X, y);

% Eigendecomposition and sorting of eigenvalues
[V, D] = eig(inv(Sw) * Sb);
s = diag(D); % Extract eigenvalues
[s, ind] = sort(s, 1, 'descend'); % Sort eigenvalues
V = V(:, ind); % Reorder eigenvectors according to sorted eigenvalues

% Project the data onto the LDA space
A = V(:, 1:2);
FeaturesHIOB_LDA = A' * X;
FeaturesHIOB_LDA = FeaturesHIOB_LDA'; % Transpose for visualization purposes

% --- LDA projection ---
gscatter(FeaturesHIOB_LDA(:,1), FeaturesHIOB_LDA(:,2), Targets_names, 'rgbcmyk', 'xo*+sd><^', 6)
xlabel('Principal Component #1')
ylabel('Principal Component #2')
title('LDA Data Representation')