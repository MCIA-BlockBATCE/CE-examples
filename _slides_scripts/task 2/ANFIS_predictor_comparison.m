clear all
close all

%% Prepare Inputs

% Load data
base_data = readmatrix("Dades_iCat_base.xlsx");
RES3_cons = base_data(1:64216,13);
temp_data = readmatrix("temperaturas_2022_2023_15minutal.xlsx");
NumSamples = 64216;

% Set indexes
hot_test_month = 17373:20348;
cold_test_month = 32061:35036;
hot_training_period = [9981:17372 20349:29180 45017:64216-4];
cold_training_period = [(4*24*7*2+1):9980 29181:32060 35037:45016];
whole_training_period = [(4*24*7*2+1):17372 20349:32060 35037:64216-4];

% Remove NaNs and apply moving window
RES3_cons(:,:) = fillmissing(RES3_cons(:,:),'linear');
RES3_cons=matlab.tall.movingWindow(@mean,15,RES3_cons);

% Time inputs
instant_day = zeros(NumSamples,1);
instant_week = zeros(NumSamples,1);

qh=1;
week_day=6; %2022 started on saturday

for t=1:NumSamples
    instant_day(t,1)=qh;
    instant_week(t,1)=week_day;
    qh=qh+1;

    if qh==97
        week_day=week_day+1;
        qh=1;
    end

    if week_day==8
        week_day=1;
    end
end

% Temperature inputs

temp_data = temp_data(:,6);

% Inputs related to previous consumption

cons_dif4 = zeros(NumSamples,1);
cons_mean = zeros(NumSamples,1);

for t=1:NumSamples

    % Differential consumption from last 4 hours
    if t>=(4*4)+1
        cons_dif4(t,1)=(RES3_cons(t,1)-RES3_cons(t-4*4,1));
    end

    % Mean consumption from last 2 weeks for current week instant
    if t>=(4*24*7*2)+1
        cons_mean(t,1)=(RES3_cons(t-(4*24*7),1)+RES3_cons(t-(4*24*7*2),1))/2;
    end

end

%% ANFIS Configuration

% Matrix Inputs/Outputs
data_ANFIS(:,1)=instant_day(1:NumSamples-4,1);
data_ANFIS(:,2)=instant_week(1:NumSamples-4,1);
data_ANFIS(:,3)=RES3_cons(1:NumSamples-4,1); 
data_ANFIS(:,4)=temp_data(1:NumSamples-4,1);
data_ANFIS(:,5)=cons_dif4(1:NumSamples-4,1);
data_ANFIS(:,6)=cons_mean(1:NumSamples-4,1); 
data_ANFIS(:,7)=RES3_cons(5:NumSamples,1); 

data_ANFIS(:,:) = fillmissing(data_ANFIS(:,:),'linear');

% Options
opt=anfisOptions('EpochNumber',3);

% Training
fis_hot = anfis(data_ANFIS(hot_training_period,:),opt);
fis_cold = anfis(data_ANFIS(cold_training_period,:),opt);
fis_all = anfis(data_ANFIS(whole_training_period,:),opt);

%% Testing

% Using season predictors
pred_summer_hotpredictor = evalfis(fis_hot,data_ANFIS(hot_test_month,1:6));
pred_winter_coldpredictor = evalfis(fis_cold,data_ANFIS(cold_test_month,1:6));

% Using whole data predictor
pred_summer_whole = evalfis(fis_all,data_ANFIS(hot_test_month,1:6));
pred_winter_whole = evalfis(fis_all,data_ANFIS(cold_test_month,1:6));

% RMS evaluations
RMS_summer_hotpredictor = rms(pred_summer_hotpredictor-RES3_cons(hot_test_month));
RMS_winter_coldpredictor = rms(pred_winter_coldpredictor-RES3_cons(cold_test_month));
RMS_summer_whole= rms(pred_summer_whole-RES3_cons(hot_test_month));
RMS_winter_whole = rms(pred_winter_whole-RES3_cons(cold_test_month));

% Plots

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_summer_hotpredictor};
figure(1)
plot(1:2976,pred_summer_hotpredictor,1:2976,RES3_cons(hot_test_month,1))
title("Summer month prediction using high temperatures predictor")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time [15 min]")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_winter_coldpredictor};
figure(2)
plot(1:2976,pred_winter_coldpredictor,1:2976,RES3_cons(cold_test_month,1))
title("Winter month prediction using low temperatures predictor")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time [15 min]")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_summer_whole};
figure(3)
plot(1:2976,pred_summer_whole,1:2976,RES3_cons(hot_test_month,1))
title("Summer month prediction using whole year predictor")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time [15 min]")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_winter_whole};
figure(4)
plot(1:2976,pred_winter_whole,1:2976,RES3_cons(cold_test_month,1))
title("Winter month prediction using whole year predictor")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time [15 min]")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")

% Having different predictors depending on temperature doesn't seem to improve
% performance of forecasting.
