clear all
close all

%% Recurrent neural net prediction 
% 1h prediction (4 steps)
% Load Consumption data
load ConsProfileExample.mat

XTrain = ConsProfileExample(1:596,1);
TTrain = ConsProfileExample(5:600,1);

XTest = ConsProfileExample(597:668,1);
TTest = ConsProfileExample(601:672,1);

layers = [
    sequenceInputLayer(1)
    lstmLayer(128)
    fullyConnectedLayer(1)];

options = trainingOptions("adam", ...
    MaxEpochs=1000, ...
    SequencePaddingDirection="left", ...
    Shuffle="every-epoch", ...
    Plots="training-progress", ...
    Verbose=false);

net = trainnet(XTrain,TTrain,layers,"mse",options);

Tpredict = predict(net,XTest);

RMS_1h_RNN = rms(Tpredict-TTest);

figure(3)
plot(1:72,Tpredict,1:72,TTest)
title("RNN model with forecasting horizon: 1 hour (4 steps)")
xlabel("Time [h]")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

% 3h prediction (12 steps)
% Load Consumption data
load ConsProfileExample.mat

XTrain = ConsProfileExample(1:588,1);
TTrain = ConsProfileExample(13:600,1);

XTest = ConsProfileExample(589:660,1);
TTest = ConsProfileExample(601:672,1);

layers = [
    sequenceInputLayer(1)
    lstmLayer(128)
    fullyConnectedLayer(1)];

options = trainingOptions("adam", ...
    MaxEpochs=1000, ...
    SequencePaddingDirection="left", ...
    Shuffle="every-epoch", ...
    Plots="training-progress", ...
    Verbose=false);

net = trainnet(XTrain,TTrain,layers,"mse",options);

Tpredict = predict(net,XTest);

RMS_3h_RNN = rms(Tpredict-TTest);

figure(4)
plot(1:72,Tpredict,1:72,TTest)
title("RNN model with forecasting horizon: 3 hour (12 steps)")
xlabel("Time [h]")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")





% offset = 75;
% [Z,state] = predict(net,ConsProfileExample(1:offset,:));
% net.State = state;
% 
% numTimeSteps = size(ConsProfileExample,1);
% numPredictionTimeSteps = numTimeSteps - offset;
% Y = zeros(numPredictionTimeSteps,1);
% Y(1,:) = Z(end,1);
% 
% for t = 1:numPredictionTimeSteps-1
%     Xt = ConsProfileExample(offset+t,:);
%     [Y(t+1,:),state] = predict(net,Xt);
%     net.State = state;
% end

% % Create and train recurrent neural network
% % 10 delay inputs and hidden layer size 10. 
% net = layrecnet(1:10,10);
% [Xs,Xi,Ai,Ts] = preparets(net,X,T);
% net = train(net,Xs,Ts,Xi,Ai);
% 
% % Returns prediction
% Y = net(Xs,Xi,Ai);
% 
% predicted_data_RNN_1h = cell2mat(Y);
% 
% % test data and prediction comparison
% figure(3)
% plot(1:72,predicted_data_RNN_1h(1,597:662),1:72,ConsProfileExample(601:672,1))
% title("RNN model with forecasting horizon: 1 hour (4 steps)")
% xlabel("Time [h]")
% ylabel("Power consumption [kW]")
% legend("Predicted consumption data","Real consumption data")
% 
% %25 delay inputs
% % Load Consumption data
% load ConsProfileExample.mat
% 
% X = num2cell(ConsProfileExample');
% T = num2cell(1:size(ConsProfileExample));
% 
% % Create and train recurrent neural network
% % 25 delay inputs and hidden layer size 10. 
% net = layrecnet(1:25,10);
% [Xs,Xi,Ai,Ts] = preparets(net,X,T);
% net = train(net,Xs,Ts,Xi,Ai);
% 
% % Returns prediction
% Y = net(Xs,Xi,Ai);
% 
% predicted_data_RNN_3h = cell2mat(Y);
% 
% % test data and prediction comparison
% figure(4)
% plot(1:72,predicted_data_RNN_3h(1,589:660),1:72,ConsProfileExample(601:672,1))
% title("RNN model with forecasting horizon: 3 hour (12 steps)")
% xlabel("Time [h]")
% ylabel("Power consumption [kW]")
% legend("Predicted consumption data","Real consumption data")
% 
