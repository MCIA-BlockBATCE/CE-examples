clear all
close all

%% Recurrent neural net prediction 
% Load SISO input data for prediction
[X,T] = simpleseries_dataset;

% Create and train recurrent neural network
% Two delay inputs and hidden layer size 10. 
net = layrecnet(1:2,10);
[Xs,Xi,Ai,Ts] = preparets(net,X,T);
net = train(net,Xs,Ts,Xi,Ai);

% Returns prediction
Y = net(Xs,Xi,Ai);

plotresponse(Ts,Y)
