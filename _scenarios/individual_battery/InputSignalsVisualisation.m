%% 1. PARAMETER DEFINITION

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

% --- Internal parameters ---
SimulationDays = 7;
TimeStep=0.25; % Time step in fractions of hour (e.g. 0.25 stands for 1/4 hour data)
SimulationSteps = 24*(1/TimeStep)*SimulationDays;
members=length(EnergyCommunityConsumptionProfiles);

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

% Arbitrary selling price
ElectricitySellingPrice=0.07 * ones(SimulationSteps,1); % Selling price in €/kWh

%% 2. PLOTS

t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t = t1:minutes(15):t2;
t = t';

Pcons_agg = zeros(SimulationSteps,1);
for i = 1:SimulationSteps
    Pcons_agg(i) = sum(PconsMeasured(i,:));
end

figure(101)
plot(t(1:SimulationSteps), Pcons_agg(1:SimulationSteps), t(1:SimulationSteps), Pgen_real(1:SimulationSteps))
title('Aggregated power consumption vs aggregated power generation')
ylabel('Power [kW]')
xlabel('Time')
legend('Aggregated power consumption','Aggregated power generation')


figure(102)
plot(t(1:SimulationSteps), PconsMeasured(1:SimulationSteps,1),t(1:SimulationSteps), PconsMeasured(1:SimulationSteps,2), ...
    t(1:SimulationSteps), PconsMeasured(1:SimulationSteps,3),t(1:SimulationSteps), PconsMeasured(1:SimulationSteps,4), ...
    t(1:SimulationSteps), PconsMeasured(1:SimulationSteps,5),t(1:SimulationSteps), PconsMeasured(1:SimulationSteps,6))
title('Power consumption for each member')
legend('P1', 'P2', 'P3', 'P4', 'P5', 'P6')
ylabel('Power [kW]')
xlabel('Time')


figure(103)
plot(t(1:SimulationSteps), price_next_1h(1:SimulationSteps))
title('Electricity buying price')
ylabel('Price [€/kWh]')
xlabel('Time')
