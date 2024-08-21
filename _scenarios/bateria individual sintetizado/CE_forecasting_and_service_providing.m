clear all
close all

% This script models an energy community (EC) where each of its members
% can use a fix allocation of the EC energy storage system (battery). The
% script is organized in the following sections:
% 
%   1. PARAMETER DEFINITION
%       This section allows for user interaction as EC consumption profiles
%       can be selected, as well as PV power allocation coefficients.
%       However, default values are preset for out of the box running.
% 
%   2. EC TESTED MODEL
%       This section runs the EC model that is being compared to rule-based
%       reference model.
%
%   3. EC RULE-BASED REFERENCE MODEL
%       This section runs the EC rule-based reference model.
%
%   4. RESULTS: KPIs AND PLOTS
%       This section displays plots which illustrate the usage of PV power
%       generation, battery and market interaction (if allowed). KPIs are
%       computed to 
% 


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
%   weekends are all-day low price, and working days forllow: 0h-8h (low),
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
PVPowerGenerationFactor = 1;


% --- Internal parameters ---
SimulationDays = 7;
TimeStep=0.25; % Time step in fractions of hour (e.g. 0.25 stands for 1/4 hour data)
SimulationSteps = 24*(1/TimeStep)*SimulationDays;
members=length(EnergyCommunityConsumptionProfiles);
PowerSurplus=zeros(SimulationSteps,members);
PowerShortage=zeros(SimulationSteps,members);
SoC=zeros(SimulationSteps+1,members); % Initial SoC
ElectricitySellingPrice=0.07 * ones(SimulationSteps,1); % Selling price in €/kWh


% --- Market parameters ---
TimeHorizonToBid = 6; % Time horizon from which we start to limit battery
                     % discharge in order to satisfy the bid
bid_counter = 0;
ServiceSafetyMargin = 0.4;
energy_cost_bought_while_bid = 0;
bid_profit = zeros(SimulationSteps,1);
BidPrice = 0.1; % arbitrary? Preguntar Albert TODO


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

% Initalization of tracking vectors and counters
StepProfit=zeros(SimulationSteps,members);
SoC_energy_CER = zeros(SimulationSteps,1);

% Tracking of energy by origin
EnergyOriginInstant=zeros(SimulationSteps,3); % Hauria de ser energia, em faltava multiplicar pel timestep (Fet)
EnergyOriginInstantIndividual=zeros(SimulationSteps,members,3); % Hauria de ser energia, em faltava multiplicar pel timestep (Fet)
DailyEnergyOrigin = zeros(24*4,3); % Hauria de ser energia, em faltava multiplicar pel timestep (Fet)
TotalEnergyOriginIndividual = zeros(members,3);


% TODO!!
% Tracking of energy by use
TotalEnergyDecisionIndividual = zeros(members, 3);
% col 1 = PV energy sold to grid
% col 2 = PV energy directly consumed 
% col 3 = PV energy consumed from battery
% col 4 = PV energy sold as a service from battery


% According to the selected sharing coefficient method and the available
% power consumption data (see --- PV power allocation coefficients --- )
% PV power allocation is computed.
[Pgen_pred_1h_allocated, Pgen_pred_3h_allocated, Pgen_real_allocated] = PV_power_allocation_forecasting(Pgen_real, Pgen_pred_1h, ...
    Pgen_pred_3h, GenerationPowerAllocation, PVPowerGenerationFactor, CoR_type, members, weekDay, hour);


% Simualtion loop
for t=1:SimulationSteps
    
    % --- Internal vectors initialization ---
    EnergyStorageMaximumForParticipant=StorageAllocation*MaximumStorageCapacity;
    MaxChargingPowerForParticipant=StorageAllocation*100;
    MaxDischargingPowerForParticipant=StorageAllocation*100;
    StepEnergyOriginIndividual = zeros(members,3);
    
    % TODO comment here
    if quarter_h == 1
    [BidAmount, BidStep] = serviceSelection(TimeStep, t, quarter_h, Pgen_pred_1h, PconsForecast1h, ...
    price_next_1h, DischargeEfficiency, ServiceSafetyMargin, MaximumStorageCapacity);
    end
    
    
    for n=1:members %EMPIEZA EL ALGORITMO
    
    % TODO: documentar función y comentar aquí código
    [PVPowerManagementDecision(t,n), BidAccepted, MaxDischargingPowerForParticipantIfBid] = chooseCF1(TimeHorizonToBid, SoC_energy_CER, BidAmount, t, BidStep, ...
    PconsForecast3h, PconsForecast1h, Pgen_pred_3h_allocated, Pgen_pred_1h_allocated, TimeStep, ...
    price_next_1h, ElectricitySellingPrice, price_next_3h, SoC, price_next_6h, MaxDischargingPowerForParticipant, n);
    
    
    % Se decide vender la energía generada y a continuación se evalúa para los
    % distintos casos si deberíamos o no extraer energía de la batería para
    % consumir. En caso de usar la batería, no se extrae más de lo que se vaya
    % a consumir (batería individual, sabemos las necesidades de cada uno). En
    % cualquier caso se compra la energía que nos falte de la red. 
    if PVPowerManagementDecision(t,n)==0

        if (BidAccepted == 1) MaxDischargingPowerForParticipant(1,n) = MaxDischargingPowerForParticipantIfBid; end
        
        MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
        
        if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)>0

            if PconsMeasured(t,n)<MaxDischargingPowerForParticipant(1,n)
                BatteryManagementDecision(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                if BatteryManagementDecision(t,n)==1
                    SoC(t+1,n)=SoC(t,n)-(((PconsMeasured(t,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                    StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+PconsMeasured(t,n);%*Unidad_t;
                else
                    StepProfit(t,n)=StepProfit(t,n)-PconsMeasured(t,n)*TimeStep*price_next_1h(t,1);
                    StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PconsMeasured(t,n);%*Unidad_t;
                    SoC(t+1,n)=SoC(t,n);
                end
            else
                BatteryManagementDecision(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                if BatteryManagementDecision(t,n)==1
                    SoC(t+1,n)=SoC(t,n)-((MaxDischargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n))*100;
                    StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency;%*Unidad_t;
                    StepProfit(t,n)=StepProfit(t,n)-(PconsMeasured(t,n)-MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency)*TimeStep*price_next_1h(t,1);
                    StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+(PconsMeasured(t,n)-MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency);%*Unidad_t;
                else
                    StepProfit(t,n)=StepProfit(t,n)-PconsMeasured(t,n)*TimeStep*price_next_1h(t,1);
                    StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PconsMeasured(t,n);%*Unidad_t;
                    SoC(t+1,n)=SoC(t,n);
                end
            end 
        else
            StepProfit(t,n)=StepProfit(t,n)-PconsMeasured(t,n)*TimeStep*price_next_1h(t,1);
            StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PconsMeasured(t,n);%*Unidad_t;
        end
        StepProfit(t,n)=StepProfit(t,n)+Pgen_pred_1h_allocated(t,n)*TimeStep*ElectricitySellingPrice(t,1);
        
        % Se decide consumir la energía consumida. En caso de déficit se evalua si
        % usar la batería y se compra la energía que falte. En caso de superávit se
        % almacena toda la posible y se vende el resto.
    
    elseif PVPowerManagementDecision(t,n)==1
        if (BidAccepted == 1) MaxDischargingPowerForParticipant(1,n) = MaxDischargingPowerForParticipantIfBid; end
        
        MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
        MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
        
        if Pgen_real_allocated(t,n)>PconsMeasured(t,n)
            P_surplus(t,n)=Pgen_pred_1h_allocated(t,n)-PconsMeasured(t,n);
            StepEnergyOriginIndividual(n,1)=StepEnergyOriginIndividual(n,1)+PconsMeasured(t,n);%*Unidad_t;
            
            if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)<100
                if P_surplus(t,n)<MaxChargingPowerForParticipant(1,n)
                    SoC(t+1,n)=SoC(t,n)+((P_surplus(t,n)*TimeStep*ChargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                else
                    SoC(t+1,n)=SoC(t,n)+((MaxChargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n))*100;
                    StepProfit(t,n)=StepProfit(t,n)+(P_surplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep*ElectricitySellingPrice(t,1);
                end
            else
                StepProfit(t,n)=StepProfit(t,n)+P_surplus(t,n)*TimeStep*ElectricitySellingPrice(t,1);
                SoC(t+1,n)=SoC(t,n);
            end
        else
            P_shortage(t,n)=PconsMeasured(t,n)-Pgen_real_allocated(t,n);
            StepEnergyOriginIndividual(n,1)=StepEnergyOriginIndividual(n,1)+Pgen_real_allocated(t,n);
            if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)>0

                if P_shortage(t,n)<MaxDischargingPowerForParticipant(1,n)
                    BatteryManagementDecision(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                    
                    % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                    if BatteryManagementDecision(t,n) == 1
                        SoC(t+1,n)=SoC(t,n)-(((P_shortage(t,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                        StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+P_shortage(t,n);%*Unidad_t;
                    else
                        StepProfit(t,n)=StepProfit(t,n)-P_shortage(t,n)*TimeStep*price_next_1h(t,1);
                        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+P_shortage(t,n);%*Unidad_t;
                        SoC(t+1,n)=SoC(t,n);
                    end
                else
                    BatteryManagementDecision(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                    % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                    if BatteryManagementDecision(t,n) == 1
                        SoC(t+1,n)=SoC(t,n)-((MaxDischargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n))*100;
                        StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+MaxDischargingPowerForParticipant(1,n);%*Unidad_t; %*DischargeEfficiency
                        StepProfit(t,n)= StepProfit(t,n)-(P_shortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep*price_next_1h(t,1); %*DischargeEfficiency
                        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+(P_shortage(t,n)-MaxDischargingPowerForParticipant(1,n));%*Unidad_t; %*DischargeEfficiency
                    else
                        StepProfit(t,n)=StepProfit(t,n)-P_shortage(t,n)*TimeStep*price_next_1h(t,1);
                        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+P_shortage(t,n);%*Unidad_t;
                        SoC(t+1,n)=SoC(t,n);
                    end
                end
            else
                StepProfit(t,n)=StepProfit(t,n)-P_shortage(t,n)*TimeStep*price_next_1h(t,1);
                StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+P_shortage(t,n);%*Unidad_t;
                SoC(t+1,n)=SoC(t,n);
            end
        end
    % Se almacena toda la energía generada o hasta llenar el SoC. En caso de
    % llenar el SoC se vende el resto.
    elseif PVPowerManagementDecision(t,n) == 2 % PVPowerManagementDecision=2
        MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
        if Pgen_real_allocated(t,n)<MaxChargingPowerForParticipant(1,n)
            SoC(t+1,n)=SoC(t,n)+((Pgen_pred_1h_allocated(t,n)*TimeStep*ChargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
        else
            SoC(t+1,n)=SoC(t,n)+(MaxChargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n)*100;
            StepProfit(t,n)=StepProfit(t,n)+(Pgen_real_allocated(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep*ElectricitySellingPrice(t,1);
        end
        StepProfit(t,n)=StepProfit(t,n)-PconsMeasured(t,n)*TimeStep*price_next_1h(t,1);
        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PconsMeasured(t,n);%*Unidad_t;
    end
    
    ServiceProviding = checkForServiceProviding(t, BidStep);
    if (ServiceProviding == true)
        bid_counter = bid_counter + 1;
        [SoC, bid_profit, StepProfit] = provideService(t, n, SoC, BidStep, StorageAllocation, BidAmount, ...
        MaximumStorageCapacity, StepProfit, GenerationPowerAllocation, BidPrice, ...
        energy_cost_bought_while_bid, step_energy_origin, price_next_1h);
    end
    
    
    EnergyOriginInstantIndividual(t,n,:) = StepEnergyOriginIndividual(n,:);
    
    
    end % AQUÍ ACABA LOOP POR PARTICIPANTE
    
    for i=1:3
    EnergyOriginInstant(t,i) = sum(EnergyOriginInstantIndividual(t,:,i));
    end
    
    
    acum = 0;
    for z = 1:members
    acum = acum + (MaximumStorageCapacity * StorageAllocation(z) * (SoC(t+1,z)/100));
    end
    
    SoC_energy_CER(t+1) = acum; 
    
    DailyEnergyOrigin(quarter_h,:) = DailyEnergyOrigin(quarter_h,:) + sum(StepEnergyOriginIndividual(:,:));
    
    step_energy_origin = sum(StepEnergyOriginIndividual(:,:));
    
   
    TotalEnergyOriginIndividual(:,:)=TotalEnergyOriginIndividual(:,:) + StepEnergyOriginIndividual(:,:);
    
    % ch
    [quarter_h,hour,weekDay] = goToNextTimeStep(quarter_h,hour,weekDay);


end

% HERE ENDS SIMULATION

% Aggregate variables at simulation end
final_bill = -sum(StepProfit);
SoC_pred=SoC;
total_energy_consumption_individual = sum(TotalEnergyOriginIndividual.');
total_energy_origin = sum(TotalEnergyOriginIndividual);
total_energy_consumption = sum(total_energy_origin);
for i=1:3
    percentage_energy_origin(i,1) = total_energy_origin(1,i)/total_energy_consumption;
end
for i=1:3
    for n=1:members
        TotalEnergyOriginIndividual(n,i) = TotalEnergyOriginIndividual(n,i)/total_energy_consumption_individual(1,n);
    end
end

%% Calculo balance economico sin optimizar
% 
% P_surplus=zeros(SimulationSteps,members);
% P_shortage=zeros(SimulationSteps,members);
% 
% SoC=ones(SimulationSteps+1,members)*0; % SoC inicial del 50% por poner algo
% ChargeEfficiency=0.97;
% DischargeEfficiency=0.97;
% 
% StepProfit_unoptimised=zeros(SimulationSteps,members);
% 
% DailyEnergyOrigin_unoptimised = zeros(24*4,3);
% 
% sold_energy_unoptimised = zeros(24*4,members);
% 
% step_energy_origin_unoptimised = zeros(SimulationSteps,3);
% 
% TotalEnergyOriginIndividual_unoptimised=zeros(members,3);
% 
% % TESTING PURPOSES ONLY
% hour = 1;
% weekDay = 1; % Mayo 2023 empieza lunes
% quarter_h = 1;
% 
% if CoR_type == 0
% 
%     for n=1:members     
% 
%         Pgen_real_allocated(:,n) = Pgen_real * GenerationPowerAllocation(1,n).'*PVPowerGenerationFactor;
% 
%     end
% 
% end
% 
% if CoR_type == 2
% 
%     for n=1:members     
% 
%         Pgen_real_allocated(:,n) = GenerationPowerAllocation(:,n).*Pgen_real*PVPowerGenerationFactor;
% 
%     end
% end
% 
% 
% for t=1:SimulationSteps
% 
% StepEnergyOriginIndividual_unoptimised = zeros(members,3);
% 
% EnergyStorageMaximumForParticipant=StorageAllocation*MaximumStorageCapacity;
% MaxChargingPowerForParticipant=StorageAllocation*100;
% MaxDischargingPowerForParticipant=StorageAllocation*100;
% 
% if CoR_type == 1
% 
%     [X] = time_band(weekDay,hour);
% 
%     for n=1:members     
% 
%         Pgen_real_allocated(:,n) = Pgen_real * GenerationPowerAllocation(n,X)*PVPowerGenerationFactor;
% 
%     end
% end
% 
%     for n=1:members %EMPIEZA EL ALGORITMO
% 
%     MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
%     MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
% 
%       if Pgen_real_allocated(t,n)>PconsMeasured(t,n)
%            P_surplus(t,n)=Pgen_real_allocated(t,n)-PconsMeasured(t,n);
%            StepEnergyOriginIndividual_unoptimised(n,1) = StepEnergyOriginIndividual_unoptimised(n,1) + PconsMeasured(t,n);%Unidad_t;
%            if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)<100
%                if P_surplus(t,n)<MaxChargingPowerForParticipant(1,n)
%                    SoC(t+1,n)=SoC(t,n)+((P_surplus(t,n)*TimeStep*ChargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
%                else
%                    SoC(t+1,n)=SoC(t,n)+((MaxChargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n))*100;
%                    sold_energy_unoptimised(quarter_h,n) = sold_energy_unoptimised(quarter_h,n) + (P_surplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep;
%                    StepProfit_unoptimised(t,n)=StepProfit_unoptimised(t,n)+(P_surplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep*ElectricitySellingPrice(t,1);
%                end
%            else
%                StepProfit_unoptimised(t,n)=StepProfit_unoptimised(t,n)+P_surplus(t,n)*TimeStep*ElectricitySellingPrice(t,1);
%                sold_energy_unoptimised(quarter_h,n) = sold_energy_unoptimised(quarter_h,n) + P_surplus(t,n)*TimeStep;
%                SoC(t+1,n)=SoC(t,n);
%            end
%        else
%            P_shortage(t,n)=PconsMeasured(t,n)-Pgen_real_allocated(t,n);
%            StepEnergyOriginIndividual_unoptimised(n,1) = StepEnergyOriginIndividual_unoptimised(n,1) + Pgen_real_allocated(t,n);%Unidad_t
%            if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)>0
%                if P_shortage(t,n)<MaxDischargingPowerForParticipant(1,n)
%                     SoC(t+1,n)=SoC(t,n)-(((P_shortage(t,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
%                     StepEnergyOriginIndividual_unoptimised(n,2) = StepEnergyOriginIndividual_unoptimised(n,2) + P_shortage(t,n);%Unidad_t
%                else
%                     SoC(t+1,n)=SoC(t,n)-(((MaxDischargingPowerForParticipant(1,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
%                     StepEnergyOriginIndividual_unoptimised(n,2) = StepEnergyOriginIndividual_unoptimised(n,2) + MaxDischargingPowerForParticipant(1,n);%Unidad_t
%                     StepProfit_unoptimised(t,n)= StepProfit_unoptimised(t,n)-(P_shortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep*price_next_1h(t,1);
%                     StepEnergyOriginIndividual_unoptimised(n,3) = StepEnergyOriginIndividual_unoptimised(n,3) + (P_shortage(t,n)-MaxDischargingPowerForParticipant(1,n));%Unidad_t
%                end
%            else
%                StepProfit_unoptimised(t,n)=StepProfit_unoptimised(t,n)-P_shortage(t,n)*TimeStep*price_next_1h(t,1);
%                StepEnergyOriginIndividual_unoptimised(n,3) = StepEnergyOriginIndividual_unoptimised(n,3) + P_shortage(t,n);%Unidad_t
%                SoC(t+1,n)=SoC(t,n);
%            end
%        end  
%     end
% 
%     step_energy_origin_unoptimised(t,:) = sum(StepEnergyOriginIndividual_unoptimised(:,:));
% 
%     [quarter_h,hour,weekDay] = goToNextTimeStep(quarter_h,hour,weekDay);
% end
% 
% % Comparació balance optimitzant/sense optimitzar
% 
% final_bill_unoptimised = -sum(StepProfit_unoptimised);
% 
% Y = categorical({'Optimización','Reglas estáticas'});
% Y = reordercats(Y,{'Optimización','Reglas estáticas'});
% 
% total_final_bill = sum(final_bill);
% total_final_bill_unoptimised = sum(final_bill_unoptimised);

%% 3. EC RULE-BASED REFERENCE MODEL

% --- Initalization of tracking vectors and counters ---
PowerSurplus=zeros(SimulationSteps,members);
PowerShortage=zeros(SimulationSteps,members);
SoC=ones(SimulationSteps+1,members)*0; % SoC inicial del 50% por poner algo
StepProfitBasicRules=zeros(SimulationSteps,members);
SoldEnergyBasicRules = zeros(24*4,members);
StepEnergyOriginBasicRules = zeros(SimulationSteps,3);
TotalEnergyOriginIndividualBasicRules = zeros(members,3);

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
        MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
        
        % Discharging power is limited by the allocation for each
        % participant
        MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
        
        % If the PV power allocated of the participant exceeds its demand
        if Pgen_real_allocated(t,n)>PconsMeasured(t,n)
            PowerSurplus(t,n)=Pgen_real_allocated(t,n)-PconsMeasured(t,n);
            StepEnergyOriginIndividualBasicRules(n,1) = StepEnergyOriginIndividualBasicRules(n,1) + PconsMeasured(t,n)*TimeStep;
            
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
                end
            
            % If the battery allocation of the participant is full, all
            % surplus is sold to the grid
            else
                StepProfitBasicRules(t,n)=StepProfitBasicRules(t,n)+PowerSurplus(t,n)*TimeStep*ElectricitySellingPrice(t,1);
                SoldEnergyBasicRules(quarter_h,n) = SoldEnergyBasicRules(quarter_h,n) + PowerSurplus(t,n)*TimeStep;
                SoC(t+1,n)=SoC(t,n);
            end
        
        % If the PV power allocated of the participant does not exceed
        % its demand
        else
            PowerShortage(t,n)=PconsMeasured(t,n)-Pgen_real_allocated(t,n);
            StepEnergyOriginIndividualBasicRules(n,1) = StepEnergyOriginIndividualBasicRules(n,1) + Pgen_real_allocated(t,n)*TimeStep;
            
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
                % If the shortage is bigger than the maximum discharing
                % power for the participant, then a combination of battery
                % and grid are used to supply the remaining demand
                else
                    SoC(t+1,n)=SoC(t,n)-(((MaxDischargingPowerForParticipant(1,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                    StepEnergyOriginIndividualBasicRules(n,2) = StepEnergyOriginIndividualBasicRules(n,2) + MaxDischargingPowerForParticipant(1,n)*TimeStep;
                    StepProfitBasicRules(t,n)= StepProfitBasicRules(t,n)-(PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep*price_next_1h(t,1);
                    StepEnergyOriginIndividualBasicRules(n,3) = StepEnergyOriginIndividualBasicRules(n,3) + (PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep;
                end
            
            % If the battery allocation of the participant is empty,
            % demand must be supplied using power from the grid
            else
                StepProfitBasicRules(t,n)=StepProfitBasicRules(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
                StepEnergyOriginIndividualBasicRules(n,3) = StepEnergyOriginIndividualBasicRules(n,3) + PowerShortage(t,n);%Unidad_t
                SoC(t+1,n)=SoC(t,n);
            end
        end  
    end
    
    % Update tracking vector
    StepEnergyOriginBasicRules(t,:) = sum(StepEnergyOriginIndividualBasicRules(:,:));
    
    % Advance to next quarter
    [quarter_h,hour,weekDay] = goToNextTimeStep(quarter_h,hour,weekDay);
end


%%

% figure(7)
% bar(total_energy_origin_individual,'stacked')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% 
% 
% figure(17)
% bar(Y,[total_final_bill total_final_bill_unoptimised])
% title("Facturación agregada de la comunidad (semanal)")
% ylabel('Euros (€)')

t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t = t1:minutes(15):t2;
t = t';

% figure(18)
% subplot(2,1,1)
% hold on
% bar(t(1:672),origen_por_horas(1:672,:),'stacked')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Energía consumida (kWh equivalente)')
% yyaxis right
% plot(t(5:steps),price_next_1h(5:steps));
% hold off

% subplot(2,1,2)
% plot(t(1:672),100*SoC_energy_CER(1:672)/capacidad)
% ylabel('SoC de la batería (%)')
% ylim([0 100])
% sgtitle("Validación de la regulación del sistema para el cumplimiento de una oferta")

% figure(19)
% plot(t(1:672),100*SoC_energy_CER(1:672)/max_capacity)
% title('Estado de carga (SoC) de la batería')
% ylabel('SoC (%)')
% xlabel('Tiempo')
% ylim([0 100])

figure(20)
plot(t(1:672),EnergyOriginInstant(1:672,1),t(1:672),EnergyOriginInstant(1:672,2),t(1:672),EnergyOriginInstant(1:672,3))
title('Potencia consumida según origen')
legend('Origen placas','Origen batería','Origen red eléctrica')
ylabel('Potencia consumida (kW)')
xlabel('Tiempo')
% yyaxis right
% plot(t(1:672), Pgen_real(1:672))

% figure(21)
% plot(t(1:672),price_next_1h(1:672))
% title('Precio de compra de electricidad a la red')
% ylabel('Precio (€/kWh)')
% xlabel('Tiempo')
