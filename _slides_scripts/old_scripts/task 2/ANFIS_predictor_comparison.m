clear all
close all

%% Prepare Inputs

% Load data
base_data = readmatrix("Dades_iCat_base.xlsx");
RES3_cons = base_data(1:64216,13);
temp_data = readmatrix("temperaturas_2022_2023_15minutal.xlsx");
NumSamples = 64216;


%%

% Set indexes
% hot_test_month = 17373:20348;
% cold_test_month = 32061:35036;
% hot_training_period = [9981:17372 20349:29180 45017:64216-4];
% cold_training_period = [(4*24*7*2+1):9980 29181:32060 35037:45016];
% whole_training_period = [(4*24*7*2+1):17372 20349:32060 35037:64216-4];

hot_test_month = 55400:56000;
cold_test_month = 35000:36000;
hot_training_period = 20300:23000;
cold_training_period = [1:2800 32000:35000];
whole_training_period = 43705:52416;

t1 = datetime(2022,1,1,0,0,0);
t2 = datetime(2023,10,31,21,45,0);
t_dates = t1:minutes(15):t2;
t_dates = t_dates';

hot_test_month_dates = t_dates(55400:56000);
cold_test_month_dates = t_dates(35000:36000);

ini_hot_test = t_dates(55400);
end_hot_test = t_dates(56400);

ini_cold_test = t_dates(35000);
end_cold_test = t_dates(36000);

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
opt=anfisOptions('EpochNumber',10);

% Training
% fis_hot = anfis(data_ANFIS(hot_training_period,:),opt);
% fis_cold = anfis(data_ANFIS(cold_training_period,:),opt);
% fis_all = anfis(data_ANFIS(whole_training_period,:),opt);

load anfis_trained.mat % So we avoid waiting for training......

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

%%
close all

% Plots
figure(1)
subplot(2,1,1)
plot(t_dates, temp_data)
ylabel('Temperature [Celsius degrees]')
xlabel('Time')
title('Temperature data')
xlim([t1 t2])

subplot(2,1,2)
plot(t_dates, RES3_cons)
ylabel('Energy consumption [kWh]')
xlabel('Time')
title('Energy Consumption data')
xlim([t1 t2])

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_summer_hotpredictor};
figure(2)
subplot(2,1,1)
plot(hot_test_month_dates,pred_summer_hotpredictor,hot_test_month_dates,RES3_cons(hot_test_month,1))
title("Summer month prediction using high temperatures predictor")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlim([ini_hot_test end_hot_test])
xlabel("Time")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")
subplot(2,1,2)
plot(hot_test_month_dates, pred_summer_hotpredictor-RES3_cons(hot_test_month))
xlim([ini_hot_test end_hot_test])
title("Error")
xlabel("Time")
ylabel("Energy [kWh]")

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_winter_coldpredictor};
figure(3)
subplot(2,1,1)
plot(cold_test_month_dates,pred_winter_coldpredictor,cold_test_month_dates,RES3_cons(cold_test_month,1))
title("Winter month prediction using low temperatures predictor")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlim([ini_cold_test end_cold_test])
xlabel("Time")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")
subplot(2,1,2)
plot(cold_test_month_dates, pred_winter_coldpredictor-RES3_cons(cold_test_month))
xlim([ini_cold_test end_cold_test])
title("Error")
xlabel("Time")
ylabel("Energy [kWh]")

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_summer_whole};
figure(4)
subplot(2,1,1)
plot(hot_test_month_dates,pred_summer_whole,hot_test_month_dates,RES3_cons(hot_test_month,1))
title("Summer month prediction using whole year predictor")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlim([ini_hot_test end_hot_test])
xlabel("Time")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")
subplot(2,1,2)
plot(hot_test_month_dates, pred_summer_whole-RES3_cons(hot_test_month))
xlim([ini_hot_test end_hot_test])
title("Error")
xlabel("Time")
ylabel("Energy [kWh]")

dim = [0.15 0.5 0.5 0.4];
str = {'RMS' RMS_winter_whole};
figure(5)
subplot(2,1,1)
plot(cold_test_month_dates,pred_winter_whole,cold_test_month_dates,RES3_cons(cold_test_month,1))
xlim([ini_cold_test end_cold_test])
title("Winter month prediction using whole year predictor")
annotation('textbox',dim,'String',str,'FitBoxToText','on');
xlabel("Time")
ylabel("Power consumption [kW]")
legend("Predicted consumption data","Real consumption data")
subplot(2,1,2)
plot(cold_test_month_dates, pred_winter_whole-RES3_cons(cold_test_month))
xlim([ini_cold_test end_cold_test])
title("Error")
xlabel("Time")
ylabel("Energy [kWh]")

err_high_temp_specific = pred_summer_hotpredictor-RES3_cons(hot_test_month);
err_high_temp_whole = pred_summer_whole-RES3_cons(hot_test_month);

figure(6)
plot(cold_test_month_dates, RES3_cons(cold_test_month,1), cold_test_month_dates, pred_winter_whole, cold_test_month_dates, pred_winter_coldpredictor)
xlim([ini_cold_test end_cold_test])
ylabel("Energy Consumption [kWh]")
xlabel("Time")
legend("Real", "Predicted by whole", "Predicted by specific")
title("Model comparison in cold month")

figure(7)
plot(hot_test_month_dates, RES3_cons(hot_test_month,1), hot_test_month_dates, pred_summer_whole, hot_test_month_dates, pred_summer_hotpredictor)
xlim([ini_hot_test end_hot_test])
ylabel("Energy Consumption [kWh]")
xlabel("Time")
legend("Real", "Predicted by whole", "Predicted by specific")
title("Model comparison in hot month")


