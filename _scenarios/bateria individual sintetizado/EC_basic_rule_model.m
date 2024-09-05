clear all
close all
% Authors: M.Delgado-Prieto, A.Llufriu-López, J.Valls-Pérez
% Universitat Politècnica de Catalunya (UPC)
% MCIA Innovation Electronics Research Center

% This script models an energy community (EC) where each of its members
% can use a fix allocation of the EC energy storage system (battery). PV
% power allocation method can be chosen by the user, as well as scenarios
% for consumption profiles (see Section 1).
% 
% In this particular case, basic operation rules for managing PV power
% generation, such as (from top priority to bottom):
%           consumption > storage > sell to grid
% 
% Therefore, no forecasting techniques are used.
%
% The script is organized in the following sections:
% 
%   Section 1. PARAMETER DEFINITION
%       This section allows for user interaction as EC consumption profiles
%       can be selected, as well as PV power allocation coefficients.
%       However, default values are preset for out of the box running.
%
%   Section 2. EC RULE-BASED REFERENCE MODEL
%       This section runs the EC rule-based reference model.
%
%   Section 3. RESULTS: KPIs AND PLOTS
%       This section displays plots which illustrate the usage of PV power
%       generation, battery and market interaction (if allowed). KPIs are
%       computed to compare the specific management method vs a rule-based
%       reference model.
% 

%% Section 1. PARAMETER DEFINITION

% --- EC consumption profiles --
% Assign one of the following values:
%   - Surplus community (i.e. aggregated PV generation is higher than
%   aggregated power consumption), CommunitySelection  = 0
% 
%   - Deficit community (i.e. aggregated PV generation is lower than
%   aggregated power consumption), CommunitySelection  = 1
% 
%   - Balanced (i.e. aggregated PV generation is similar to aggregated
%   power consumption), CommunitySelection  = 2
CommunitySelection = 0;
EnergyCommunityConsumptionProfiles = getCommunityProfiles(CommunitySelection);


% --- PV power allocation coefficients ---
% Assign one of the following values: 
%   - Fixed and constant allocation, CoR_type = 0
%
%   - Variable allocation considering only information that is available to the
%   customer in invoices, which are aggregated power consumption in each of
%   the 3 tariff section (low price, mid price, high price). For reference,
%   weekends are all-day low price, and working days follow: 0h-8h (low),
%   8h-10h (mid), 10h-14h (high), 14h-18h (mid), 18h-22h(high), 22h-0h (mid).
%   CoR_type = 1.
%
%   - Allocation based on instantly available power consumption
%   measurements, CoR_type = 2.
CoR_type = 0;
[GenerationPowerAllocation, StorageAllocation] = allocation_coefficients(CoR_type, EnergyCommunityConsumptionProfiles);


% --- Battery parameters ---
ChargeEfficiency=0.97;
DischargeEfficiency=0.97;
MaximumStorageCapacity=200;
% Default value for PVPowerGenerationFactor (0.8) is according to previously defined
% EC consumption profiles (surplus, deficit, balanced)
PVPowerGenerationFactor = 0.8;


% --- Internal parameters ---
SimulationDays = 7;
TimeStep=0.25; % Time step in fractions of hour (e.g. 0.25 stands for 1/4 hour data)
SimulationSteps = 24*(1/TimeStep)*SimulationDays;
members=length(EnergyCommunityConsumptionProfiles);
PowerSurplus=zeros(SimulationSteps,members);
PowerShortage=zeros(SimulationSteps,members);
SoC=zeros(SimulationSteps+1,members); % Initial SoC
ElectricitySellingPrice=0.07 * ones(SimulationSteps,1); % Selling price in €/kWh


% --- Starting simulation time ---
hour = 1; % Starting hour
weekDay = 1; % May 2023 started on Monday (thus Monday=1, ..., Sunday=7)
quarter_h = 1; % Starting quarter


% --- Input data ---
% Load data from .mat files which contain PV generated power
load("..\..\_data\Pgen_real.mat")
load("..\..\_data\Pgen_real_3h.mat")

% Load data from.mat files which contain measured power consumption
load("..\..\_data\energia_cons_CER.mat")
load("..\..\_data\energia_cons_CER_3h.mat")
PconsMeasured = energia_cons_CER(:,EnergyCommunityConsumptionProfiles)/TimeStep;
PconsMeasured3h = energia_cons_CER_3h(:,EnergyCommunityConsumptionProfiles)/TimeStep;


% Load data from .mat files which contain forecasted PV generation
% following Osterwald equation to estimate the nominal power for generic
% PV equipment.
load("..\..\_data\Pgen_pred_1h.mat")
load("..\..\_data\Pgen_pred_3h.mat")


% Load data which contain forecasted power consumption, obtained offline
% using Adaptive Neuro-Fuzzy Inference System (ANFIS) in MATLAB.
load("..\..\_data\Pcons_pred_1h.mat")
load("..\..\_data\Pcons_pred_3h.mat")
PconsForecast1h = Pcons_pred_1h(:,EnergyCommunityConsumptionProfiles)/TimeStep;
PconsForecast3h = Pcons_pred_3h(:,EnergyCommunityConsumptionProfiles)/TimeStep;


% Load data which contains electricity buying price according to
% OMIE (iberian markets).
load("..\..\_data\buying_prices.mat");

%% 2. EC TESTED MODEL

% --- Initalization of tracking vectors and counters ---
PowerSurplus=zeros(SimulationSteps,members);
PowerShortage=zeros(SimulationSteps,members);

SoC=ones(SimulationSteps+1,members)*0; 
SoC_energy_CER = zeros(SimulationSteps,1);

StepProfitBasicRules=zeros(SimulationSteps,members);
SoldEnergyBasicRules = zeros(24*4,members);

StepEnergyOriginBasicRules = zeros(SimulationSteps,3);
TotalEnergyOriginIndividualBasicRules = zeros(members,3);

% According to the selected sharing coefficient method and the available
% power consumption data (see --- PV power allocation coefficients --- )
% PV power allocation is computed.
[Pgen_pred_1h_allocated, Pgen_pred_3h_allocated, Pgen_real_allocated] = PV_power_allocation_forecasting(Pgen_real, Pgen_pred_1h, ...
    Pgen_pred_3h, GenerationPowerAllocation, PVPowerGenerationFactor, CoR_type, members, weekDay, hour);

% Tracking of energy by use
TotalEnergyDecisionIndividualBasicRules = zeros(members,3);
% col 1 = PV energy sold to grid
% col 2 = PV energy directly consumed 
% col 3 = PV energy consumed from battery

% --- Restar time-related parameters ---
hour = 1; % Starting hour
weekDay = 1; % May 2023 started on Monday (thus Monday=1, ..., Sunday=7)
quarter_h = 1; % Starting quarter


% Simulation loop
for t=1:SimulationSteps 

    % --- Internal vectors initialization ---
    StepEnergyOriginIndividualBasicRules = zeros(members,3);
    EnergyStorageMaximumForParticipant=StorageAllocation*MaximumStorageCapacity;
    MaxChargingPowerForParticipant=StorageAllocation*100;
    MaxDischargingPowerForParticipant=StorageAllocation*100;


    for n=1:members %Loop for each CE member

        % Charging power allocation for each participant
        MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep)*ChargeEfficiency);

        % Discharging power is limited by the allocation for each
        % participant
        MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep)*DischargeEfficiency);

        % If the PV power allocated of the participant exceeds its demand
        if Pgen_real_allocated(t,n)>PconsMeasured(t,n)
            PowerSurplus(t,n)=Pgen_real_allocated(t,n)-PconsMeasured(t,n);
            StepEnergyOriginIndividualBasicRules(n,1) = StepEnergyOriginIndividualBasicRules(n,1) + PconsMeasured(t,n)*TimeStep;
            TotalEnergyDecisionIndividualBasicRules(n,2) = TotalEnergyDecisionIndividualBasicRules(n,2) + PconsMeasured(t,n)*TimeStep;

            % If the battery allocation of the participant its not full,
            % the excess power can be used to charge the battery
            if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)<100

                % If the surplus is smaller than the maximum charging power
                % for the participant, energy is used fully to charge the
                % battery
                if PowerSurplus(t,n)<MaxChargingPowerForParticipant(1,n)
                    SoC(t+1,n)=SoC(t,n)+((PowerSurplus(t,n)*TimeStep*ChargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                    
                % If the surplus is bigger than the maximum charing power
                % for the participant, the energy that can't be used to
                % charge the battery will be sold to the grid
                else
                    SoC(t+1,n)=SoC(t,n)+((MaxChargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n))*100;
                    SoldEnergyBasicRules(quarter_h,n) = SoldEnergyBasicRules(quarter_h,n) + (PowerSurplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep;
                    StepProfitBasicRules(t,n)=StepProfitBasicRules(t,n)+(PowerSurplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep*ElectricitySellingPrice(t,1);
                    TotalEnergyDecisionIndividualBasicRules(n,1) = TotalEnergyDecisionIndividualBasicRules(n,1)+(PowerSurplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep;
                end

            % If the battery allocation of the participant is full, all
            % surplus is sold to the grid
            else
                StepProfitBasicRules(t,n)=StepProfitBasicRules(t,n)+PowerSurplus(t,n)*TimeStep*ElectricitySellingPrice(t,1);
                SoldEnergyBasicRules(quarter_h,n) = SoldEnergyBasicRules(quarter_h,n) + PowerSurplus(t,n)*TimeStep;
                SoC(t+1,n)=SoC(t,n);
                TotalEnergyDecisionIndividualBasicRules(n,1) = TotalEnergyDecisionIndividualBasicRules(n,1) + PowerSurplus(t,n)*TimeStep;
            end

        % If the PV power allocated of the participant does not exceed
        % its demand
        else
            PowerShortage(t,n)=PconsMeasured(t,n)-Pgen_real_allocated(t,n);
            StepEnergyOriginIndividualBasicRules(n,1) = StepEnergyOriginIndividualBasicRules(n,1) + Pgen_real_allocated(t,n)*TimeStep;
            TotalEnergyDecisionIndividualBasicRules(n,2) = TotalEnergyDecisionIndividualBasicRules(n,2) + Pgen_real_allocated(t,n)*TimeStep;

            % If there is energy in the battery allocation of the
            % participant, demand can be supplied partiatime_margin_bidlly or fully by the
            % battery
            if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)>0

                % If the shortage is smaller than the maximum discharging
                % power for the participant, then battery is used to supply
                % the remaining demand
                if PowerShortage(t,n)<MaxDischargingPowerForParticipant(1,n)
                    SoC(t+1,n)=SoC(t,n)-(((PowerShortage(t,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                    StepEnergyOriginIndividualBasicRules(n,2) = StepEnergyOriginIndividualBasicRules(n,2) + PowerShortage(t,n)*TimeStep;
                    TotalEnergyDecisionIndividualBasicRules(n,3) = TotalEnergyDecisionIndividualBasicRules(n,3) + PowerShortage(t,n)*TimeStep;
                % If the shortage is bigger than the maximum discharing
                % power for the participant, then a combination of battery
                % and grid are used to supply the remaining demand
                else
                    SoC(t+1,n)=SoC(t,n)-(((MaxDischargingPowerForParticipant(1,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                    StepEnergyOriginIndividualBasicRules(n,2) = StepEnergyOriginIndividualBasicRules(n,2) + MaxDischargingPowerForParticipant(1,n)*TimeStep;
                    StepProfitBasicRules(t,n)= StepProfitBasicRules(t,n)-(PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep*price_next_1h(t,1);
                    StepEnergyOriginIndividualBasicRules(n,3) = StepEnergyOriginIndividualBasicRules(n,3) + (PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep;
                    TotalEnergyDecisionIndividualBasicRules(n,3) = TotalEnergyDecisionIndividualBasicRules(n,3) + MaxDischargingPowerForParticipant(1,n)*TimeStep;
                end

            % If the battery allocation of the participant is empty,
            % demand must be supplied using power from the grid
            else
                StepProfitBasicRules(t,n)=StepProfitBasicRules(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
                StepEnergyOriginIndividualBasicRules(n,3) = StepEnergyOriginIndividualBasicRules(n,3) + PowerShortage(t,n)*TimeStep;
                SoC(t+1,n)=SoC(t,n);
            end
        end  
    end

    SoC_energy_CER(t+1) = getSoCEnergyEC(members, MaximumStorageCapacity, StorageAllocation, SoC, t);

    % Update tracking vector and counters
    StepEnergyOriginBasicRules(t,:) = sum(StepEnergyOriginIndividualBasicRules(:,:));

    TotalEnergyOriginIndividualBasicRules(:,:)=TotalEnergyOriginIndividualBasicRules(:,:) + StepEnergyOriginIndividualBasicRules(:,:);

    % Advance to next quarter
    [quarter_h,hour,weekDay] = goToNextTimeStep(quarter_h,hour,weekDay);
    
end

% Aggregate variables at simulation end
final_billBasicRules = -sum(StepProfitBasicRules);
SoC_BasicRules = SoC;
total_energy_consumption_individualBasicRules = sum(TotalEnergyOriginIndividualBasicRules.');

for i=1:3
    for n=1:members
        TotalEnergyOriginIndividualBasicRules(n,i) = TotalEnergyOriginIndividualBasicRules(n,i)/total_energy_consumption_individualBasicRules(1,n);
    end
end

%% 3. RESULTS: KPIs AND PLOTS

t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t = t1:minutes(15):t2;
t = t';

[ADR,POR,avg_days] = consumption_profile_metrics(PconsMeasured);
[CBU, ADC, BCPD] = battery_metrics(SoC_energy_CER, MaximumStorageCapacity, SimulationDays, SimulationSteps);

CE_SoC_signal = 100*SoC_energy_CER(1:672)/MaximumStorageCapacity;

Pcons_agg = zeros(SimulationSteps,1);
Pgen_real_allocated_community = zeros(SimulationSteps,1);
for i = 1:SimulationSteps
    Pcons_agg(i) = sum(PconsMeasured(i,:));
    Pgen_real_allocated_community(i) = sum(Pgen_real_allocated(i,:));
end

PercentualTotalEnergyDecisionIndividualBasicRules=zeros(members,3);

for n = 1:members
    PercentualTotalEnergyDecisionIndividualBasicRules(n,:) = (TotalEnergyDecisionIndividualBasicRules(n,:)/sum(TotalEnergyDecisionIndividualBasicRules(n,:)))*100;
end

% info for annotation
if (CommunitySelection == 0)
    scenario = "Surplus";
elseif (CommunitySelection == 1)
    scenario = "Deficit";
elseif (CommunitySelection == 2)
    scenario = "Balanced";
end
dim = [0.15 0.5 0.5 0.4];
str = {'Current EC scenario:' scenario};

% inputs, consumption vs generation
figure(1)
plot(t(1:672), Pcons_agg(1:672), t(1:672), Pgen_real_allocated_community(1:672))
title('Aggregated power consumption vs Aggregated power generation')
ylabel('Power [kW]')
xlabel('Time')
legend('Agg power cons','Agg power gen')
annotation('textbox',dim,'String',str,'FitBoxToText','on');

% power consumption by origin
figure(2)
plot(t(1:SimulationSteps), StepEnergyOriginBasicRules(1:SimulationSteps,1)/TimeStep, ...
    t(1:SimulationSteps),StepEnergyOriginBasicRules(1:SimulationSteps,2)/TimeStep, ...
    t(1:SimulationSteps),StepEnergyOriginBasicRules(1:SimulationSteps,3)/TimeStep)
title('Power consumption by origin')
legend('PV','Battery','Grid')
ylabel('Power consumption [kW]')
xlabel('Time')
annotation('textbox',dim,'String',str,'FitBoxToText','on');

% SoC over time and battery KPIs
figure(3)
plot(t(1:672),CE_SoC_signal)
title("Battery State of Charge (SoC), AUR: [" + num2str(ADC(1), '%05.2f') + ", " ...
    + num2str(ADC(2), '%05.2f') + "] [%], CBU: " + num2str(CBU, '%05.2f') + ", ADC: " ...
    + num2str(BCPD, '%05.2f'), FontSize=14)
ylabel('SoC [%]')
xlabel('Time')
ylim([0 100])

% power consumption by origin for each member
figure(4)
bar(TotalEnergyOriginIndividualBasicRules*100,'stacked')
title('Power consumption by origin for each member')
ylabel('Power consumption [%]')
xlabel('EC members')
ylim([0 100])
legend('PV','Battery','Grid')

% renewable power usage for each member
figure(5)
b = bar(PercentualTotalEnergyDecisionIndividualBasicRules,'stacked', 'FaceColor', 'flat');
title('Renewable power usage for each member')
ylim([0 100])
ylabel('Renewable power [%]')
xlabel('EC members')
legend('Sold to grid','Consumed from PV','Consumed from Battery')
b(1).CData = [0.9290, 0.6940, 0.1250];
b(2).CData = [0, 0.4470, 0.7410];
b(3).CData = [0.8500, 0.3250, 0.0980];

figure(6)
qs = 1:1:96;
plot(qs, avg_days(:,1), qs, avg_days(:,2), qs, avg_days(:,3), qs, avg_days(:,4), qs, avg_days(:,5), qs, avg_days(:,6))
title("Average-day power consumption for each CE member, POR: [" + num2str(POR(1), '%05.2f') ...
    + ", " + num2str(POR(2), '%05.2f') + ", " + num2str(POR(3), '%05.2f') + "] [%], ADR: " + num2str(ADR, '%05.2f') + " [kW]", FontSize=14)
legend('P1', 'P2', 'P3', 'P4', 'P5', 'P6')
xlim([1 96])
ylabel('Power consumption [kW]')
xlabel('Time, in quarters')

% Final bill comparison
figure(7)
bar(-final_billBasicRules)
title('Economic balance for each member')
ylabel('Monetary units')
xlabel('EC members')

%% LEGACY

% figure(106)
% bar(TotalEnergyOriginIndividualBasicRules*100,'stacked')
% title('Power consumption by origin')
% ylabel('Power consumption [%]')
% xlabel('Participant')
% ylim([0 100])
% legend('FV','Battery','Grid')

% figure(107)
% total_energy_decision_invidual: 6 filas (members) x 3 cols (actions)
% Valores en % para el total de cada fila

% figure(108)
% plot(t(1:SimulationSteps),StepEnergyOriginBasicRules(1:SimulationSteps,1),t(1:SimulationSteps),StepEnergyOriginBasicRules(1:SimulationSteps,2),t(1:SimulationSteps),StepEnergyOriginBasicRules(1:SimulationSteps,3))
% title('Consumed energy by origin')
% legend('FV','Battery','Grid')
% ylabel('KWh')
% xlabel('Time')

% Final bill comparison
% figure(201)
% bar(-final_billBasicRules)
% title('Final economic net profit in euros, Basic Rules')