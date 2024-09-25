clear all
close all

load ionosphere 
% train tree
CMdl = fitctree(X,Y);

% Uncomment next line for prediction for a given input
%Ynew = predict(CMdl,mean(X));

% plot tree
view(CMdl,'Mode','graph')