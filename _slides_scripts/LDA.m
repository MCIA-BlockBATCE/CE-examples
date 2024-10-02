% TODO
% - Modificar primera secció perqué només carregui les dades. La part 1
% actual hauria d'estar ja feta, i per tant l'objecte ".mat" que es
% carregui ja tindra "Target_names" construit a dins. En aquest sentit,
% quan es carregui aquest ".mat", calen un parell de línies dient que conté dins
% les dades de diferents condicions d'operació de coixinets.
% - Separar en 4 seccions, (i) lectura de dades (ii) entrenament
% (iii) càlculd de mètriques (iv) visualització
% Si Targets1C no es fa servir, eliminar. El mateix amb altres variables si
% aplica.

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
% Load data, containing features for fault type and severity, as well as a target
% label array and target names for fault types. Severity is not taken into account.
load data_LDA.mat

% Transpose feature matrix for further use
FeaturesHIOBv3 = FeaturesHIOBv3';

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