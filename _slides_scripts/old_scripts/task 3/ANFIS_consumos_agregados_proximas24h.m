%% Load data

load base_data.mat
datos_consumo = base_data;

FirstSample = 35037;
LastSample = 63928;
NumSamples = 63928 - 35037 + 1;

% Data from 1/1/2023 to 28/10/2023
CER_excedentaria = [datos_consumo(FirstSample:LastSample,5) datos_consumo(FirstSample:LastSample,8:9) ...
    datos_consumo(FirstSample:LastSample,11) datos_consumo(FirstSample:LastSample,13) datos_consumo(FirstSample:LastSample,16)];
% Miembros provisionales: CAP1, EDU1, EDU2, RES1, RES3, RV4

CAP1_consumption = CER_excedentaria(:,1);

% Apply moving window
CAP1_consumption=matlab.tall.movingWindow(@mean,12,CAP1_consumption);


 %% Time inputs

instant_day = zeros(NumSamples,1);
instant_week = zeros(NumSamples,1);

qh=1;
week_day=7; %2023 started on sunday

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

%% Temperature inputs

temp_data = readmatrix("temperaturas_2022_2023_15minutal.xlsx");

temp_data = temp_data(FirstSample:LastSample,6);

%% Inputs related to previous consumption

cons_dif4 = zeros(NumSamples,1);
mean_cons = zeros(NumSamples,1);

for t=1:28892 
    
    % Differential consumption from last 4 hours
    if t>=(4*4)+1
        cons_dif4(t,1)=(CAP1_consumption(t,1)-CAP1_consumption(t-4*4,1));
    end

    % Mean consumption from last 2 weeks for current week instant
    if t>=(4*24*7*2)+1
        mean_cons(t,1)=(CAP1_consumption(t-(4*24*7),1)+CAP1_consumption(t-(4*24*7*2),1))/2;
    end

end
%% ANFIS configuration

% for hours=1:25
% 
%     % Matriz Inputs/Outputs
%     data_ANFIS(:,1)=instant_day(1:NumSamples-4*hours,1); % Cuarto de hora del dia (INPUT)
%     data_ANFIS(:,2)=instant_week(1:NumSamples-4*hours,1); % Dia de la semana (INPUT)
%     data_ANFIS(:,3)=CAP1_consumption(1:NumSamples-4*hours,1); % Consumo anterior (INPUT)
%     data_ANFIS(:,4)=temp_data(1:NumSamples-4*hours,1); % Temperatura (INPUT)
%     data_ANFIS(:,5)=cons_dif4(1:NumSamples-4*hours,1); % Consumo diferencial 4 hours (INPUT)
%     data_ANFIS(:,6)=mean_cons(1:NumSamples-4*hours,1); % Media de consumo del instante actual (INPUT)
%     data_ANFIS(:,7)=CAP1_consumption(1+4*hours:NumSamples,1); % Consumo siguiente X hours (OUTPUT)
% 
%     data_ANFIS(:,:) = fillmissing(data_ANFIS(:,:),'linear');
% 
%     % Options
%     opt=anfisOptions('EpochNumber',2);
% 
%     fis = anfis([data_ANFIS((4*24*7*2+1):11520,:);data_ANFIS(14497:28892-hours*4,:)],opt);
% 
% %% Testing
% 
%     for t=11521:14496
% 
%         consumption_pred(t,1) = evalfis(fis,data_ANFIS(t,1:6));
% 
%         if consumption_pred(t,1) < 0
%             consumption_pred(t,1) = 0;
%         end 
% 
%     end
% 
%     consumption_pred = filloutliers(consumption_pred,'nearest','mean');
%     consumption_pred(consumption_pred<0, 1) = NaN;
%     consumption_pred(:,1) = fillmissing(consumption_pred(:,1),'linear');
%     consumption_pred_N_hours(1:length(consumption_pred),hours) = consumption_pred(:,1);
% 
% %% Error
% 
%     error_N_hours(1,hours) = rms(consumption_pred(11521:14496,1) - CAP1_consumption(11521+hours*4:14496+hours*4,1));
% 
%     error_N_hours_percentage(1,hours) = (error_N_hours(1,hours)*100)/mean(CAP1_consumption(11521+hours*4:14496+hours*4,1));
% 
% %% Restart variables
% 
%     clear data_ANFIS consumption_pred
% 
% end

load workspace.mat

%% Plot RMS/horizon

figure(1)
plot(1:25,error_N_hours)
title("RMS error and forecasting horizon plot")
xlabel("Time horizon (h)")
ylabel("RMS error (kW)")




