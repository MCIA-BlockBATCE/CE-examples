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
% In this particular case, forecasted data is used as an input for the
% decision functions for each member. Also, EC is allowed to participate in
% the energy market, where it can provide balance services for the
% day-ahead. In short, each 23:00, EC forecasts the vector of surplus of energy (PV
% power vs consumption) for the day-ahead, and uses a dummy price vector which
% would be published by the SO (System Operator). Considering both vectors,
% it selects the highest benefit service, with some security thresholds.
% 
% The script is organized in the following sections:
% 
%   Section 1. PARAMETER DEFINITION
%       This section allows for user interaction as EC consumption profiles
%       can be selected, as well as PV power allocation coefficients. Also
%       here market and service parameters are defined. Doefault values
%       are preset for out of the box running.
% 
%   Section 2. EC TESTED MODEL
%       This section runs the EC model that is being compared to rule-based
%       reference model.
%
%   Section 3. EC RULE-BASED REFERENCE MODEL
%       This section runs the EC rule-based reference model.
%
%   Section 4. RESULTS: KPIs AND PLOTS
%       This section displays plots which illustrate the usage of PV power
%       generation, battery and market interaction (if allowed). KPIs are
%       computed to compare the specific management method vs a rule-based
%       reference model.
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
%   weekends are all-day low price, and working days follow: 0h-8h (low),
%   8h-10h (mid), 10h-14h (high), 14h-18h (mid), 18h-22h(high), 22h-0h (mid).
%   CoR_type = 1.
%
%   - Allocation based on instantly available power consumption
%   measurements, CoR_type = 2.
CoR_type = 2;
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
ServiceSafetyMargin = 0.2; % Value from 0.0 (all margin, no bids) to 1.0 (no margin)
energy_cost_bought_while_bid = 0;
bid_profit = zeros(SimulationSteps,1);
BidPrice = 0.1; % Default value
BidAmount = 0;
BidStep = -4;


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


% Tracking of energy by use
TotalEnergyDecisionIndividual = zeros(members, 4);
StepEnergyDecisionIndividual = zeros(SimulationSteps, 4);
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
    
    % At 23:00 (simulation time) forecasting techniques are used to predict
    % the day-ahead aggregate surplus and select the offert with most
    % revenue.
    if quarter_h == 93
        [BidAmount, BidStep] = serviceSelection(TimeStep, t, quarter_h, Pgen_pred_1h, PconsForecast1h, ...
            price_next_1h, DischargeEfficiency, ServiceSafetyMargin, MaximumStorageCapacity);
    end
    
    
    for n=1:members %Loop for each CE member
    
    % A specific cost function (CF1_Interoperability) is defined for
    % limiting the maximum allowed discharging power in the hours prior to 
    % service providing, to ensure that enough energy is still in the
    % battery to fulfill the service. Otherwise, the regular PV power
    % management cost function is used (CF1).
    [PVPowerManagementDecision(t,n), BidAccepted, MaxDischargingPowerForParticipantIfBid] = chooseCF1(TimeHorizonToBid, ...
            SoC_energy_CER, BidAmount, t, BidStep, PconsForecast3h, PconsForecast1h, Pgen_pred_3h_allocated, ...
            Pgen_pred_1h_allocated, TimeStep, price_next_1h, ElectricitySellingPrice, price_next_3h, ...
            SoC, price_next_6h, MaxDischargingPowerForParticipant, n, DischargeEfficiency, StorageAllocation, MaximumStorageCapacity);
        
   
    % If the participant decides on selling the PV generated power to
    % the grid.
    if PVPowerManagementDecision(t,n)==0

        % If bid was accepted, an extra restriction is applied to max
        % discharging power allowed for the participant
        if (BidAccepted == 1)
            MaxDischargingPowerForParticipant(1,n) = MaxDischargingPowerForParticipantIfBid;
        end
        
        % Discharging power is limited by the allocation for each
        % participant
        MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep)*DischargeEfficiency);
        
        % If there is still energy stored in the battery for the current
        % participant, it has to be decided if the participant's demand
        % will be supplied by the battery or by the grid
        if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)>0

            % If the participant's demand is lower than the maximum
            % available discharging power for the current participant
            if PconsMeasured(t,n)<MaxDischargingPowerForParticipant(1,n)
                
                % This function controlls the use of stored energy. The CF has 2 possible
                % outputs: Using energy from the battery or saving it for later.
                % The outcome depends on future consumption, production and price predictions.
                BatteryManagementDecision(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                % Do not use stored energy: 0, Use stored energy: 1

                % The participant uses the energy stored in its battery
                % allocation in order to supply its demand
                if BatteryManagementDecision(t,n)==1
                    SoC(t+1,n)=SoC(t,n)-(((PconsMeasured(t,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                    StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+PconsMeasured(t,n)*TimeStep;
                    TotalEnergyDecisionIndividual(n,3)=TotalEnergyDecisionIndividual(n,3)+(PconsMeasured(t,n)*TimeStep)/DischargeEfficiency;
                    StepEnergyDecisionIndividual(t,3)=StepEnergyDecisionIndividual(n,3)+(PconsMeasured(t,n)*TimeStep)/DischargeEfficiency;

                % The participant purchases energy from the grid to
                % supply its demand
                else
                    StepProfit(t,n)=StepProfit(t,n)-PconsMeasured(t,n)*TimeStep*price_next_1h(t,1);
                    StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PconsMeasured(t,n)*TimeStep;
                    SoC(t+1,n)=SoC(t,n);
                end
            
            % If the participant's demand is higher than maximum
            % available discharging power for the current participant
            else
                
                % This function controlls the use of stored energy. The CF has 2 possible
                % outputs: Using energy from the battery or saving it for later.
                % The outcome depends on future consumption, production and price predictions.
                BatteryManagementDecision(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                % Do not use stored energy: 0, Use stored energy: 1
                
                % The participant uses the energy stored in its battery
                % allocation to partially supply the participant's
                % demand
                if BatteryManagementDecision(t,n)==1
                    SoC(t+1,n)=SoC(t,n)-((MaxDischargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n)*DischargeEfficiency)*100;
                    StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+MaxDischargingPowerForParticipant(1,n)*TimeStep;
                    StepProfit(t,n)=StepProfit(t,n)-(PconsMeasured(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep*price_next_1h(t,1);
                    StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+(PconsMeasured(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep;
                    TotalEnergyDecisionIndividual(n,3)=TotalEnergyDecisionIndividual(n,3)+MaxDischargingPowerForParticipant(1,n)*TimeStep;
                    StepEnergyDecisionIndividual(t,3)=StepEnergyDecisionIndividual(t,3)+MaxDischargingPowerForParticipant(1,n)*TimeStep;


                % The participant purchases energy from the grid to
                % supply its demand                
                else
                    StepProfit(t,n)=StepProfit(t,n)-PconsMeasured(t,n)*TimeStep*price_next_1h(t,1);
                    StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PconsMeasured(t,n)*TimeStep;
                    SoC(t+1,n)=SoC(t,n);
                end
            end 
        
        % If battery is empty, the participant's demand must be supplied
        % by the grid
        else
            StepProfit(t,n)=StepProfit(t,n)-PconsMeasured(t,n)*TimeStep*price_next_1h(t,1);
            StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PconsMeasured(t,n)*TimeStep;
        end
        
        % Update accounting
        StepProfit(t,n)=StepProfit(t,n)+Pgen_pred_1h_allocated(t,n)*TimeStep*ElectricitySellingPrice(t,1);
        TotalEnergyDecisionIndividual(n,1)=TotalEnergyDecisionIndividual(n,1)+Pgen_real_allocated(t,n)*TimeStep;


    % If the participant decides on instantly consuming PV generated
    % power
    elseif PVPowerManagementDecision(t,n)==1
        
        % If bid was accepted, an extra restriction is applied to max
        % discharging power allowed for the participant
        if (BidAccepted == 1)
            MaxDischargingPowerForParticipant(1,n) = MaxDischargingPowerForParticipantIfBid;
        end
        
        % Charging power allocation for each participant
        MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep)*ChargeEfficiency);
        % Discharging power is limited by the allocation for each
        % participant
        MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep)*DischargeEfficiency);
        
        % If PV power allocated to the participant exceeds its power
        % demand 
        if Pgen_real_allocated(t,n)>PconsMeasured(t,n)

            % Surplus of PV generated power, which will be used to
            % charge the battery allocation for the participant or sold
            % if the battery allocation is full
            PowerSurplus(t,n)=Pgen_pred_1h_allocated(t,n)-PconsMeasured(t,n);
            StepEnergyOriginIndividual(n,1)=StepEnergyOriginIndividual(n,1)+PconsMeasured(t,n)*TimeStep;
            TotalEnergyDecisionIndividual(n,2)=TotalEnergyDecisionIndividual(n,2)+PconsMeasured(t,n)*TimeStep;
            StepEnergyDecisionIndividual(n,2)=StepEnergyDecisionIndividual(n,2)+PconsMeasured(t,n)*TimeStep;


            % If the battery allocation of the particpant is not full
            if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)<100

                % Surplus of PV generated power is lower than maximum
                % charing power for the participant, then it can all be
                % used to charge the battery allocation for the
                % participant                
                if PowerSurplus(t,n)<MaxChargingPowerForParticipant(1,n)
                    SoC(t+1,n)=SoC(t,n)+((PowerSurplus(t,n)*TimeStep*ChargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                
                % Surplus of PV generated power is higher than maximum
                % charging power for the participant, then surplus is
                % split between charging battery at the maximum charing
                % power and selling the rest to the grid.               
                else
                    SoC(t+1,n)=SoC(t,n)+((MaxChargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n))*100;
                    StepProfit(t,n)=StepProfit(t,n)+(PowerSurplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep*ElectricitySellingPrice(t,1);
                    TotalEnergyDecisionIndividual(n,1)=TotalEnergyDecisionIndividual(n,1)+(PowerSurplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep;
                    StepEnergyDecisionIndividual(n,1)=StepEnergyDecisionIndividual(n,1)+(PowerSurplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep;
                end
            
            % If the battery allocation of the participant is full, then
            % all surplus has to be sold to the grid            
            else
                SoC(t+1,n)=SoC(t,n);
                StepProfit(t,n)=StepProfit(t,n)+PowerSurplus(t,n)*TimeStep*ElectricitySellingPrice(t,1);
                TotalEnergyDecisionIndividual(n,1)=TotalEnergyDecisionIndividual(n,1)+PowerSurplus(t,n)*TimeStep;
                StepEnergyDecisionIndividual(n,1)=StepEnergyDecisionIndividual(n,1)+PowerSurplus(t,n)*TimeStep;
            end
        
        % If PV power allocated to the participant does not exceed
        % its power demand, this will have to be supplied with battery
        % power or power purchased from the grid        
        else
            PowerShortage(t,n)=PconsMeasured(t,n)-Pgen_real_allocated(t,n);
            StepEnergyOriginIndividual(n,1)=StepEnergyOriginIndividual(n,1)+Pgen_real_allocated(t,n)*TimeStep;;
            TotalEnergyDecisionIndividual(n,2)=TotalEnergyDecisionIndividual(n,2)+Pgen_real_allocated(t,n)*TimeStep;
            StepEnergyDecisionIndividual(n,2)=StepEnergyDecisionIndividual(n,2)+Pgen_real_allocated(t,n)*TimeStep;
  
            
            % If there is energy in the participant's battery allocation
            if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)>0

                % If the shortage is smaller than the available
                % discharing power from the participant's battery
                % allocation
                if PowerShortage(t,n)<MaxDischargingPowerForParticipant(1,n)

                    % This function controlls the use of stored energy. The CF has 2 possible
                    % outputs: Using energy from the battery or saving it for later.
                    % The outcome depends on future consumption, production and price predictions.
                    BatteryManagementDecision(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                    
                    % The battery is used to supply the remaining 
                    % participant's demand
                    if BatteryManagementDecision(t,n) == 1
                        SoC(t+1,n)=SoC(t,n)-(((PowerShortage(t,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                        StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+PowerShortage(t,n)*TimeStep;
                        TotalEnergyDecisionIndividual(n,3)=TotalEnergyDecisionIndividual(n,3)+(PowerShortage(t,n)*TimeStep)/DischargeEfficiency;
                        StepEnergyDecisionIndividual(n,3)=StepEnergyDecisionIndividual(n,3)+(PowerShortage(t,n)*TimeStep)/DischargeEfficiency;

                    
                    % The grid is used to supply the remaining
                    % participant's demand
                    else
                        StepProfit(t,n)=StepProfit(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
                        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PowerShortage(t,n)*TimeStep;
                        SoC(t+1,n)=SoC(t,n);
                    end
                
                % If the shortage is bigger than the available
                % discharing power from the participant's battery
                % allocation                
                else
                    BatteryManagementDecision(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                    % Do not use stored energy: 0, Use stored energy: 1

                    % A combination of power from the battery and grid
                    % is used to supply the remaining demand                    
                    if BatteryManagementDecision(t,n) == 1
                        SoC(t+1,n)=SoC(t,n)-((MaxDischargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n)*DischargeEfficiency)*100;
                        StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+MaxDischargingPowerForParticipant(1,n)*TimeStep;
                        StepProfit(t,n)= StepProfit(t,n)-(PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep*price_next_1h(t,1);
                        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+(PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep;
                        TotalEnergyDecisionIndividual(n,3)=TotalEnergyDecisionIndividual(n,3)+MaxDischargingPowerForParticipant(1,n)*TimeStep;
                        StepEnergyDecisionIndividual(n,3)=StepEnergyDecisionIndividual(n,3)+MaxDischargingPowerForParticipant(1,n)*TimeStep;
                    
                    
                    % Only the grid is used to supply the remaining
                    % demand                   
                    else
                        StepProfit(t,n)=StepProfit(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
                        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PowerShortage(t,n)*TimeStep;
                        SoC(t+1,n)=SoC(t,n);
                    end
                end
            
            % If the participant's battery allocation is empty, demand
            % can only be supplied by power purchased from grid
            else
                StepProfit(t,n)=StepProfit(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
                StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PowerShortage(t,n)*TimeStep;
                SoC(t+1,n)=SoC(t,n);
            end
        end

    % If the participant decides on storing all PV generated power
    elseif PVPowerManagementDecision(t,n) == 2

        MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep)*ChargeEfficiency);
        
        % If the PV generated power does not exceed the maximum charging
        % power for the participant's battery allocation, all power is used
        % to charge the battery      
        if Pgen_real_allocated(t,n)<MaxChargingPowerForParticipant(1,n)
            SoC(t+1,n)=SoC(t,n)+((Pgen_pred_1h_allocated(t,n)*TimeStep*ChargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
        
        % If the PV generated power exceeds the maximum charging power for
        % the participant's battery allocation, then the power surplus is
        % sold to the grid
        else
            SoC(t+1,n)=SoC(t,n)+(MaxChargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n)*100;
            StepProfit(t,n)=StepProfit(t,n)+(Pgen_real_allocated(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep*ElectricitySellingPrice(t,1);
            TotalEnergyDecisionIndividual(n,1) = TotalEnergyDecisionIndividual(n,1) + (Pgen_real_allocated(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep;
            StepEnergyDecisionIndividual(n,1)=StepEnergyDecisionIndividual(n,1)+(Pgen_real_allocated(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep;
        end
        
        StepProfit(t,n)=StepProfit(t,n)-PconsMeasured(t,n)*TimeStep*price_next_1h(t,1);
        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PconsMeasured(t,n)*TimeStep;
    
    end
    
    % After each member makes its decision, these are overwritten in case
    % that balance services must be provided at that specific time
    % (simulation time).
    ServiceProviding = checkForServiceProviding(t, BidStep);
    if (ServiceProviding == true)
        bid_counter = bid_counter + 1;
        [SoC, bid_profit, StepProfit, energy_cost_bought_while_bid, TotalEnergyDecisionIndividual, StepEnergyDecisionIndividual] = provideService(t, n, SoC, BidStep, StorageAllocation, BidAmount, ...
            MaximumStorageCapacity, StepProfit, GenerationPowerAllocation, BidPrice, ...
            energy_cost_bought_while_bid, step_energy_origin, price_next_1h, TotalEnergyDecisionIndividual, StepEnergyDecisionIndividual);
    end
    
    % Update individual tracking vector
    EnergyOriginInstantIndividual(t,n,:) = StepEnergyOriginIndividual(n,:);
    
    end % Loop for each CE member ends
    
    % --- Update of tracking vectors and counters
    for i=1:3
        EnergyOriginInstant(t,i) = sum(EnergyOriginInstantIndividual(t,:,i));
    end
    SoC_energy_CER(t+1) = getSoCEnergyEC(members, MaximumStorageCapacity, StorageAllocation, SoC, t);
    step_energy_origin = sum(StepEnergyOriginIndividual(:,:));
    DailyEnergyOrigin(quarter_h,:) = DailyEnergyOrigin(quarter_h,:) + sum(StepEnergyOriginIndividual(:,:));
    TotalEnergyOriginIndividual(:,:)=TotalEnergyOriginIndividual(:,:) + StepEnergyOriginIndividual(:,:);
    
    % Advance to the next quarter
    [quarter_h,hour,weekDay] = goToNextTimeStep(quarter_h,weekDay);


end % Simulation loop

% Aggregate variables at simulation end
final_bill = -sum(StepProfit);
SoC_ForecastingAndService=SoC;
total_energy_consumption_individual = sum(TotalEnergyOriginIndividual.');
total_energy_origin = sum(TotalEnergyOriginIndividual);
total_energy_consumption = sum(total_energy_origin);
for i=1:3
    for n=1:members
        TotalEnergyOriginIndividual(n,i) = TotalEnergyOriginIndividual(n,i)/total_energy_consumption_individual(1,n);
    end
end


%% 3. EC RULE-BASED REFERENCE MODEL

% --- Initalization of tracking vectors and counters ---
PowerSurplus=zeros(SimulationSteps,members);
PowerShortage=zeros(SimulationSteps,members);
SoC=ones(SimulationSteps+1,members)*0; % SoC inicial del 50% por poner algo
StepProfitBasicRules=zeros(SimulationSteps,members);
SoldEnergyBasicRules = zeros(24*4,members);
StepEnergyOriginBasicRules = zeros(SimulationSteps,3);
TotalEnergyOriginIndividualBasicRules = zeros(members,3);

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

    % Update tracking vector and counters
    SoC_energy_CER_unoptimised(t+1) = getSoCEnergyEC(members, MaximumStorageCapacity, StorageAllocation, SoC, t);

    StepEnergyOriginBasicRules(t,:) = sum(StepEnergyOriginIndividualBasicRules(:,:));

    TotalEnergyOriginIndividualBasicRules(:,:)=TotalEnergyOriginIndividualBasicRules(:,:) + StepEnergyOriginIndividualBasicRules(:,:);

    % Advance to next quarter
    [quarter_h,hour,weekDay] = goToNextTimeStep(quarter_h,weekDay);
    
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


%% 4. RESULTS: KPIs AND PLOTS

% --- Plots ---
t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t = t1:minutes(15):t2;
t = t';

[ADR,POR,avg_days] = consumption_profile_metrics(PconsMeasured);
[CBU, ADC, BCPD] = battery_metrics(SoC_energy_CER, MaximumStorageCapacity, SimulationDays, SimulationSteps);
[CBU2, ADC2, BCPD2] = battery_metrics(SoC_energy_CER_unoptimised, MaximumStorageCapacity, SimulationDays, SimulationSteps);


CE_SoC_signal = 100*SoC_energy_CER(1:SimulationSteps)/MaximumStorageCapacity;
CE_Soc_signal_unoptimised = 100*SoC_energy_CER_unoptimised(1:SimulationSteps)/MaximumStorageCapacity;

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

PercentualTotalEnergyDecisionIndividual=zeros(members,4);

for n = 1:members
    PercentualTotalEnergyDecisionIndividual(n,:) = (TotalEnergyDecisionIndividual(n,:)/sum(TotalEnergyDecisionIndividual(n,:)))*100;
end

final_bill_unoptimised = -sum(StepProfitBasicRules);

Y = categorical({'Avanced rule model based on predictions with balance services','Basic rule model'});
Y = reordercats(Y,{'Avanced rule model based on predictions with balance services','Basic rule model'});

total_final_bill = sum(final_bill);
total_final_bill_unoptimised = sum(final_bill_unoptimised);

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
subplot(2,1,1)
plot(t(1:672),CE_SoC_signal)
title("Advanced rule model (SoC), AUR: [" + num2str(ADC(1), '%05.2f') + ", " ...
    + num2str(ADC(2), '%05.2f') + "] [%], CBU: " + num2str(CBU, '%05.2f') + ", ADC: " ...
    + num2str(BCPD, '%05.2f'), FontSize=14)
ylabel('SoC [%]')
xlabel('Time')
ylim([0 100])
subplot(2,1,2)
plot(t(1:672),CE_Soc_signal_unoptimised)
title("Basic rule model, AUR: [" + num2str(ADC2(1), '%05.2f') + ", " ...
    + num2str(ADC2(2), '%05.2f') + "] [%], CBU: " + num2str(CBU2, '%05.2f') + ", ADC: " ...
    + num2str(BCPD2, '%05.2f'), FontSize=14)
ylabel('SoC [%]')
xlabel('Time')
ylim([0 100])
sgtitle('Battery State of Charge (SoC)')

% power consumption by origin for each member
figure(4)
subplot(1,2,1)
bar(TotalEnergyOriginIndividualBasicRules*100,'stacked')
title('Basic rule model')
ylabel('Power consumption [%]')
xlabel('EC members')
ylim([0 100])
legend('PV','Battery','Grid')
subplot(1,2,2)
bar(TotalEnergyOriginIndividual*100,'stacked')
title('Advanced rule model based on prediction with balance services')
ylabel('Power consumption [%]')
xlabel('EC members')
ylim([0 100])
legend('PV','Battery','Grid')
sgtitle('Power consumption by origin for each member')

% renewable power usage for each member
figure(5)
subplot(1,2,1)
b = bar(PercentualTotalEnergyDecisionIndividualBasicRules,'stacked', 'FaceColor', 'flat');
title('Basic rule model')
ylim([0 100])
ylabel('Renewable power [%]')
xlabel('EC members')
legend('Sold to grid','Consumed from PV','Consumed from Battery')
b(1).CData = [0.9290, 0.6940, 0.1250];
b(2).CData = [0, 0.4470, 0.7410];
b(3).CData = [0.8500, 0.3250, 0.0980];
subplot(1,2,2)
b2 = bar(PercentualTotalEnergyDecisionIndividual, 'stacked', 'FaceColor', 'flat');
title('Advanced rule model based on prediction with balance services')
ylim([0 100])
ylabel('Renewable power [%]')
xlabel('EC members')
legend('Sold to grid','Consumed from PV','Consumed from Battery','PV energy sold as a service from battery')
b2(1).CData = [0.9290, 0.6940, 0.1250];
b2(2).CData = [0, 0.4470, 0.7410];
b2(3).CData = [0.8500, 0.3250, 0.0980];
b2(4).CData = [0.4940, 0.1840, 0.5560];
sgtitle('Renewable power usage for each member')

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
subplot(1,2,1)
bar(-final_billBasicRules)
title('Rule based model')
ylabel('Monetary units')
xlabel('EC members')
subplot(1,2,2)
bar(-final_bill)
title('Advanced model based on predictions with balance service')
ylabel('Monetary units')
xlabel('EC members')
sgtitle('Economic balance for each member')

figure(8)
bar(Y,[total_final_bill total_final_bill_unoptimised])
title('Aggregated economic balance')
ylabel('Monetary units')


%% LEGACY PLOTS

% figure(101)
% plot(t(1:SimulationSteps), Pcons_agg(1:SimulationSteps), t(1:SimulationSteps), Pgen_real(1:SimulationSteps))
% title('Aggregated power consumption vs aggregated power generation')
% ylabel('Power [kW]')
% xlabel('Time')
% legend('Aggregated power consumption','Aggregated power generation')
% 
% figure(102)
% bar(TotalEnergyOriginIndividual*100,'stacked')
% title('Power consumption by origin')
% ylabel('Power consumption [%]')
% xlabel('Participant')
% ylim([0 100])
% legend('FV','Battery','Grid')
% 
% PercentualTotalEnergyDecisionIndividual=zeros(members,4);
% 
% for n = 1:members
%     PercentualTotalEnergyDecisionIndividual(n,:) = (TotalEnergyDecisionIndividual(n,:)/sum(TotalEnergyDecisionIndividual(n,:)))*100;
% end
% 
% figure(103)
% % total_energy_decision_invidual: 6 filas (members) x 4 cols (acciones)
% % Valores en % para el total de cada fila
% 
% bar(PercentualTotalEnergyDecisionIndividual,'stacked')
% title('Power usage of RE')
% ylim([0 100])
% ylabel('Renewable power [%]')
% xlabel('Participant')
% legend('Sold to grid','Consumed from PV','Consumed from Battery','PV energy sold as a service from battery')
% 
% % Pendiente añadir en este gráfico anotaciones con métricas de BAT
% figure(104)
% plot(t(1:SimulationSteps),CE_SoC_signal)
% title("Battery State of Charge (SoC), AUR: [" + num2str(ADC(1), '%05.2f') + ", " ...
%     + num2str(ADC(2), '%05.2f') + "] [%], CBU: " + num2str(CBU, '%05.2f') + ", ADC: " ...
%     + num2str(BCPD, '%05.2f'), FontSize=14)
% ylabel('SoC [%]')
% xlabel('Time')
% ylim([0 100])
% dim = [0.15 0.5 0.5 0.4];
% str = {'AUR' [AUR(1),AUR(2)], 'CBC' CBC, 'BCPD' BCPD};
% annotation('textbox',dim,'String',str,'FitBoxToText','on');

% Pendiente añadir en este gráfico anotaciones con métricas perfiles de
% consumo

% figure(105)
% qs = 1:1:96;
% plot(qs, avg_days(:,1), qs, avg_days(:,2), qs, avg_days(:,3), qs, avg_days(:,4), qs, avg_days(:,5), qs, avg_days(:,6))
% title("Average-day power consumption for each CE member, POR: [" + num2str(POR(1), '%05.2f') ...
%     + ", " + num2str(POR(2), '%05.2f') + ", " + num2str(POR(3), '%05.2f') + "] [%], ADR: " + num2str(ADR, '%05.2f') + " [kW]", FontSize=14)
% legend('P1', 'P2', 'P3', 'P4', 'P5', 'P6')
% xlim([1 96])
% ylabel('Power [kW]')
% xlabel('Time, in quarters')
% % dim = [0.15 0.5 0.5 0.4];
% % str = {'POR' POR, 'ADR' ADR};
% % annotation('textbox',dim,'String',str,'FitBoxToText','on');
% 
% figure(202)
% bar(TotalEnergyOriginIndividualBasicRules*100,'stacked')
% title('Power consumption by origin')
% ylabel('Power consumption [%]')
% xlabel('Participant')
% ylim([0 100])
% legend('FV','Battery','Grid')
% 
% PercentualTotalEnergyDecisionIndividualBasicRules=zeros(members,3);
% 
% for n = 1:members
%     PercentualTotalEnergyDecisionIndividualBasicRules(n,:) = (TotalEnergyDecisionIndividualBasicRules(n,:)/sum(TotalEnergyDecisionIndividualBasicRules(n,:)))*100;
% end
% 
% figure(203)
% % total_energy_decision_invidual: 6 filas (members) x 4 cols (acciones)
% % Valores en % para el total de cada fila
% 
% bar(PercentualTotalEnergyDecisionIndividualBasicRules,'stacked')
% title('Power usage of RE')
% ylim([0 100])
% ylabel('Renewable power [%]')
% xlabel('Participant')
% legend('Sold to grid','Consumed from PV','Consumed from Battery','PV energy sold as a service from battery')
% 
% % Final bill comparison
% figure(204)
% subplot(1,2,1)
% bar(-final_bill)
% title('Final economic net profit in euros, Forecasting and Sevice providing')
% subplot(1,2,2)
% bar(-final_billBasicRules)
% title('Final economic net profit in euros, Basic Rules')

% figure(7)
% bar(total_energy_origin_individual,'stacked')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% 
% 
% figure(17)
% bar(Y,[total_final_bill total_final_bill_unoptimised])
% title("Facturación agregada de la comunidad (semanal)")
% ylabel('Euros (€)')

% t1 = datetime(2023,5,1,0,0,0);
% t2 = datetime(2023,5,31,0,0,0);
% t = t1:minutes(15):t2;
% t = t';

% figure(18)
% subplot(2,1,1)
% hold on
% bar(t(1:SimulationSteps),origen_por_horas(1:SimulationSteps,:),'stacked')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Energía consumida (kWh equivalente)')
% yyaxis right
% plot(t(5:steps),price_next_1h(5:steps));
% hold off

% subplot(2,1,2)
% plot(t(1:SimulationSteps),100*SoC_energy_CER(1:SimulationSteps)/capacidad)
% ylabel('SoC de la batería (%)')
% ylim([0 100])
% sgtitle("Validación de la regulación del sistema para el cumplimiento de una oferta")

% figure(19)
% plot(t(1:SimulationSteps),100*SoC_energy_CER(1:SimulationSteps)/max_capacity)
% title('Estado de carga (SoC) de la batería')
% ylabel('SoC (%)')
% xlabel('Tiempo')
% ylim([0 100])

% figure(20)
% plot(t(1:SimulationSteps),EnergyOriginInstant(1:SimulationSteps,1),t(1:SimulationSteps),EnergyOriginInstant(1:SimulationSteps,2),t(1:SimulationSteps),EnergyOriginInstant(1:SimulationSteps,3))
% title('Potencia consumida según origen')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Potencia consumida (kW)')
% xlabel('Tiempo')
% yyaxis right
% plot(t(1:SimulationSteps), Pgen_real(1:SimulationSteps))

% figure(21)
% plot(t(1:SimulationSteps),price_next_1h(1:SimulationSteps))
% title('Precio de compra de electricidad a la red')
% ylabel('Precio (€/kWh)')
% xlabel('Tiempo')

%% OUTPUT FOR SIMULATION

% filename = './csv_output/SoC_energy_CER.txt';
% csvwrite(filename,SoC_energy_CER);
% 
% filename = './csv_output/pv_consumption.txt';
% csvwrite(filename, EnergyOriginInstant(1:SimulationSteps,1));
% 
% filename = './csv_output/bat_consumption.txt';
% csvwrite(filename, EnergyOriginInstant(1:SimulationSteps,2));
% 
% filename = './csv_output/grid_consumption.txt';
% csvwrite(filename, EnergyOriginInstant(1:SimulationSteps,3));
% 
% filename = './csv_output/last_day_economic_balance.txt';
% csvwrite(filename, StepProfit(:,1));
% 
% % col 1 = PV energy sold to grid
% % col 2 = PV energy directly consumed 
% % col 3 = PV energy consumed from battery
% % col 4 = PV energy sold as a service from battery
% 
% filename = './csv_output/pv_energy_sold_to_grid.txt';
% csvwrite(filename, StepEnergyDecisionIndividual(:,1));
% 
% filename = './csv_output/pv_energy_directly_consumed.txt';
% csvwrite(filename, StepEnergyDecisionIndividual(:,2));
% 
% filename = './csv_output/pv_energy_consumed_from_battery.txt';
% csvwrite(filename, StepEnergyDecisionIndividual(:,3));
% 
% filename = './csv_output/pv_energy_sold_as_a_service.txt';
% csvwrite(filename, StepEnergyDecisionIndividual(:,4));