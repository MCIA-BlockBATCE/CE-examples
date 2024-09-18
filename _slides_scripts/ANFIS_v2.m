
% Clear workspace
clear all
close all
% 
% load ConsProfileExample.mat
% data = ConsProfileExample';

load signal.mat
data = synthetic_signal;

%% 1h prediction ANFIS
% synthetic data

% inputs based on previous data
start_i = 100;
end_i = 500;
for i=101:500
    previous_sample(1,i-start_i) = data(1,i-1);
    previous_5th_sample(1,i-start_i) = data(1,i-5);
    previous_20th_sample(1,i-start_i) = data(1,i-20);
    previous_50th_sample(1,i-start_i) = data(1,i-50);
    mean_last_5_samples(1,i-start_i) = mean(data(1,i-5:i));
    mean_last_20_samples(1,i-start_i) = mean(data(1,i-20:i));
    mean_last_50_samples(1,i-start_i) = mean(data(1,i-50:i));
end

%%
% group inputs and outputs into I/O matrix
% IO_matrix will be used from i=51 to i=200
IO_matrix(:,1) = previous_sample;
IO_matrix(:,2) = previous_5th_sample;
IO_matrix(:,3) = previous_20th_sample;
IO_matrix(:,4) = previous_50th_sample;
IO_matrix(:,5) = mean_last_5_samples;
IO_matrix(:,6) = mean_last_20_samples;
IO_matrix(:,7) = mean_last_50_samples;
IO_matrix(:,8) = data(101:500); % Output vector


%%
% train/test split
start_testing_split = 300;
end_testing_split = 400;
IO_matrix_training = IO_matrix(1:250,:);
IO_matrix_testing = IO_matrix(start_testing_split:end_testing_split,:);

% ANFIS
opt=anfisOptions('EpochNumber',5);
fis = anfis(IO_matrix_training,opt);
predicted_data = evalfis(fis,IO_matrix_testing(:,1:7));
data_for_predictions = data(start_i+start_testing_split:end_testing_split+start_i);
RMS_1h = rms(predicted_data' - data_for_predictions);

% test data and prediction comparison
dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_1h};

figure(1)
plot(1:length(predicted_data),predicted_data',1:length(predicted_data),data_for_predictions)
title("ANFIS model with forecasting horizon: 1 step")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlim([1 length(predicted_data)])
xlabel("Time [q]")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Synthetic consumption data")

