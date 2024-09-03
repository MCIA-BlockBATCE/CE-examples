% synthesized data
t = 0:0.001:0.199;
data = 5*sin(25*2*pi*t)+0.2*randn(size(t));

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
IO_matrix_training = IO_matrix(51:150,:);
IO_matrix_testing = IO_matrix(151:200,:);

% ANFIS
opt=anfisOptions('EpochNumber',5);
fis = anfis(IO_matrix_training,opt);
predicted_data = evalfis(fis,IO_matrix_testing(:,1:7));
RMS = rms(predicted_data - data(1,151:200));

% test data and prediction comparison
plot(1:50,predicted_data',1:50,data(1,151:200))







