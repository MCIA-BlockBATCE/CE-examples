%% 1h prediction ANFIS
% synthetic data
t = 0:0.002:0.399;
data = 5*sin(25*2*pi*t)+0.2*randn(size(t))+6;

% inputs based on previous data
for i=51:200
previous_sample(1,i) = data(1,i-1);
previous_5th_sample(1,i) = data(1,i-5);
previous_20th_sample(1,i) = data(1,i-20);
previous_50th_sample(1,i) = data(1,i-50);
mean_last_5_samples(1,i) = mean(data(1,i-5:i));
mean_last_20_samples(1,i) = mean(data(1,i-20:i));
mean_last_50_samples(1,i) = mean(data(1,i-50:i));
end

% group inputs and outputs into I/O matrix
% IO_matrix will be used from i=51 to i=200
IO_matrix(:,1) = previous_sample;
IO_matrix(:,2) = previous_5th_sample;
IO_matrix(:,3) = previous_20th_sample;
IO_matrix(:,4) = previous_50th_sample;
IO_matrix(:,5) = mean_last_5_samples;
IO_matrix(:,6) = mean_last_20_samples;
IO_matrix(:,7) = mean_last_50_samples;
IO_matrix(:,8) = data; % Output vector

% train/test split
IO_matrix_training = IO_matrix(51:176,:);
IO_matrix_testing = IO_matrix(177:200,:);

% ANFIS
opt=anfisOptions('EpochNumber',5);
fis = anfis(IO_matrix_training,opt);
predicted_data = evalfis(fis,IO_matrix_testing(:,1:7));
RMS_1h = rms(predicted_data' - data(1,177:200));

% test data and prediction comparison
dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_1h};
figure(1)
plot(1:24,predicted_data',1:24,data(1,177:200))
title("ANFIS model with forecasting horizon: 1 hour (1 step)")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time [h]")
ylabel("Power consumption [kW]")
xlim([1 24])
legend("Predicted consumption data","Synthesized consumption data")

clear IO_matrix
%% 3h prediction ANFIS

% use previous synthetic consumption data and inputs

% regroup into input/output matrix changing output vector
% IO_matrix will be used from i=51 to i=198
IO_matrix(:,1) = previous_sample(1,1:198);
IO_matrix(:,2) = previous_5th_sample(1,1:198);
IO_matrix(:,3) = previous_20th_sample(1,1:198);
IO_matrix(:,4) = previous_50th_sample(1,1:198);
IO_matrix(:,5) = mean_last_5_samples(1,1:198);
IO_matrix(:,6) = mean_last_20_samples(1,1:198);
IO_matrix(:,7) = mean_last_50_samples(1,1:198);
IO_matrix(:,8) = data(1,3:200); % Output vector

% train/test split
IO_matrix_training = IO_matrix(51:174,:);
IO_matrix_testing = IO_matrix(175:198,:);

% ANFIS
opt=anfisOptions('EpochNumber',5);
fis = anfis(IO_matrix_training,opt);
predicted_data = evalfis(fis,IO_matrix_testing(:,1:7));
RMS_3h = rms(predicted_data' - data(1,175:198));

% test data and prediction comparison
dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_3h};
figure(2)
plot(1:24,predicted_data',1:24,data(1,175:198))
title("ANFIS model with forecasting horizon: 3 hours (3 steps)")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time [h]")
ylabel("Power consumption [kW]")
xlim([1 24])
legend("Predicted consumption data","Synthetic consumption data")
