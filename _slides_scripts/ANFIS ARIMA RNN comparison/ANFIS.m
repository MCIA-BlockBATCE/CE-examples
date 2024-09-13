clear all
close all

%% ANFIS
% 1h prediction
load ConsProfileExample.mat
data = ConsProfileExample;

% inputs based on previous data
consumption_dif4 = zeros(672,1);
previous_day = zeros(672,1);
previous_sample = zeros(672,1);
    
    for t=1:672 
        
        % Differential consumption from the last 4 hours
        if t>=(4*4)+1
            consumption_dif4(t,1)=(data(t,1)-data(t-4*4,1));
        end
    
        % Consumption of current hour the previous day
        if t>=(4*24)+1
            previous_day(t,1)=(data(t-(4*24)));
        end

        % Consumption of previous sample
        if t>=2
            previous_sample(t,1) = data(t-1,1);
        end
    
    end

% group inputs and outputs into I/O matrix
% IO_matrix will be used from i=97 to i=672
IO_matrix(:,1) = previous_sample;
IO_matrix(:,2) = previous_day;
IO_matrix(:,3) = consumption_dif4;
IO_matrix(:,4) = data; % Output vector

% train/test split
IO_matrix_training = IO_matrix(97:600,:);
IO_matrix_testing = IO_matrix(601:672,:);

% ANFIS
opt=anfisOptions('EpochNumber',5);
fis = anfis(IO_matrix_training,opt);
predicted_data_ANFIS_1H = evalfis(fis,IO_matrix_testing(:,1:3));
RMS_1h_ANFIS = rms(predicted_data_ANFIS_1H  - data(601:672,1));

% test data and prediction comparison
dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_1h};

figure(1)
plot(1:72,predicted_data_ANFIS_1H ,1:72,data(601:672,1))
title("ANFIS model with forecasting horizon: 1 hour (4 steps)")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time [h]")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

clear IO_matrix

% 3h prediction

% use previous synthetic consumption data and inputs

% regroup into input/output matrix changing output vector
% IO_matrix will be used from i=97 to i=664
IO_matrix(:,1) = previous_sample(1:672-2*4,1);
IO_matrix(:,2) = previous_day(1:672-2*4,1);
IO_matrix(:,3) = consumption_dif4(1:672-2*4,1);
IO_matrix(:,4) = data(1+2*4:672,1); % Output vector

% train/test split (about 70/30)
IO_matrix_training = IO_matrix(97:592,:);
IO_matrix_testing = IO_matrix(593:664,:);

% ANFIS
opt=anfisOptions('EpochNumber',5);
fis = anfis(IO_matrix_training,opt);
predicted_data_ANFIS_3h = evalfis(fis,IO_matrix_testing(:,1:3));
RMS_3h_ANFIS = rms(predicted_data_ANFIS_3h - data(593:664,1));

% test data and prediction comparison
dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_3h};
figure(2)
plot(1:72,predicted_data_ANFIS_3h,1:72,data(593:664,1))
title("ANFIS model with forecasting horizon: 3 hours (12 steps)")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time [h]")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")


