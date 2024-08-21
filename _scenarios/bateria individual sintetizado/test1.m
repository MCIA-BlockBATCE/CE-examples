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



%% SECTION TO BE DELETED
% 
% % Declaracion de variables y ejecución de funciones (Lecturas y predicciones)
% % MES DE MAYO TIENE 2976 muestras = 4 cuartos * 24 horas * 31 días
% SimulationDays = 7;
% SimulationSteps = 24*4*SimulationDays;
% 
% % aquí se acotaria la comunidad por ejemplo
% CER_excedentaria = [4 7 8 10 12 13];
% % CER_deficitaria = [x x x x x x]:
% % CER_balanceada = [x x x x x x]:
% 
% % aquí elegimos tipo de CoR
% CoR_type = 0; % fixed allocation
% % CoR_type = 1; % allocation based on the moment of the week (variable)
% % CoR_type = 2; % allocation based on consumption of previous step (dynamic variable)
% 
% members=length(CER_excedentaria); % Numero de participantes
% 
% % FRECUENCIA HORARIA A CUARTOHORARIA
% TimeStep=0.25; % Tiempo entre ejecuciones (1h) HABRÁ QUE CAMBIAR A 0.25
% 
% load("..\..\_data\Pgen_real.mat")
% load("..\..\_data\Pgen_real_3h.mat")
% 
% % NOTA: Estas tablas NO contienen columnas de marca temporal separada dia,
% % mes año, hora
% % NOTA: Paso a potencia (kW) la magnitud de energía (kWh), multiplico por 4
% % NOTA: aquí cargo TODOS los perfiles de consumo, y ya luego elegimos la
% % comunidad
% load("..\..\_data\energia_cons_CER.mat")
% load("..\..\_data\energia_cons_CER_3h.mat")
% 
% PconsMeasured = energia_cons_CER(:,CER_excedentaria) * 4;
% PconsMeasured3h = energia_cons_CER_3h(:,CER_excedentaria) * 4;
% 
% % NOTA: Fórmula Osterwald da como output potencia (kW)
% load("..\..\_data\Pgen_pred_1h.mat")
% load("..\..\_data\Pgen_pred_3h.mat")
% 
% % Carguem prediccions ANFIS
% load("..\..\_data\PconsForecast1h.mat")
% load("..\..\_data\PconsForecast3h.mat")
% 
% % Passem a potencia
% PconsForecast1h = 4 * PconsForecast1h(:,CER_excedentaria);
% PconsForecast3h = 4 * PconsForecast3h(:,CER_excedentaria);
% 
% if CoR_type == 0
% 
%     time_band_bill(CER_excedentaria)
%     [generation_allocation] = time_band_coefficients();
%     generation_allocation = sum(generation_allocation.'); %operacions per obtenir un CoR_bateria que no canvii durant el mes
%     generation_allocation = generation_allocation/sum(generation_allocation); %operacions per obtenir un CoR_bateria estàtic que no canvii durant el mes
%     StorageAllocation=generation_allocation;
% 
% elseif CoR_type == 1
% 
%     time_band_bill(CER_excedentaria)
%     [generation_allocation] = time_band_coefficients();
%     generation_allocation=generation_allocation(1:members,1:3);
%     StorageAllocation=generation_allocation(1:members,:);
%     StorageAllocation = sum(StorageAllocation.'); %operacions per obtenir un CoR_bateria que no canvii durant el mes
%     StorageAllocation = StorageAllocation/sum(StorageAllocation); %operacions per obtenir un CoR_bateria estàtic que no canvii durant el mes
% 
% else 
% 
%     [generation_allocation] = previous_sample_coefficients(CER_excedentaria); 
% 
%     % Se usan CoR estaticos para repartir la bateria
%     time_band_bill(CER_excedentaria)
%     [StorageAllocation] = time_band_coefficients();
%     StorageAllocation = sum(StorageAllocation.'); %operacions per obtenir un CoR_bateria que no canvii durant el mes
%     StorageAllocation = StorageAllocation/sum(StorageAllocation); %operacions per obtenir un CoR_bateria estàtic que no canvii durant el mes
% 
% end
% 
% 
% P_surplus=zeros(SimulationSteps,members);
% P_shortage=zeros(SimulationSteps,members);
% 
% SoC=ones(SimulationSteps+1,members)*0; % SoC inicial
% 
% % Parámetros batería
% ChargeEfficiency=0.97;
% DischargeEfficiency=0.97;
% MaximumStorageCapacity=200;
% PVPowerGenerationFactor = 1;
% 
% selling_price=0.07 * ones(SimulationSteps,1);
% bid_price = 0.11; % Chosen arbitrarily
% 
% load("..\..\_data\buying_prices.mat");
% 
% % TESTING PURPOSES ONLY
% hour = 1;
% weekDay = 1; % Mayo 2023 empieza lunes
% quarter_h = 1;
%
%%% Caso con datos reales
% 
% daily_energy_origin = zeros(24*4,3);
% total_energy_origin_individual = zeros(members,3);
% StepProfit=zeros(SimulationSteps,members);
% energy_origin_instant=zeros(SimulationSteps,3);
% energy_origin_instant_individual=zeros(SimulationSteps,members,3);
% energy_cost_bought_while_bid = 0;
% bid_profit = zeros(SimulationSteps,1);
% 
% if CoR_type == 0
% 
%     for n=1:members     
%         Pgen_pred_1h_allocated(:,n) = Pgen_pred_1h * generation_allocation(1,n).'*PVPowerGenerationFactor;
%         Pgen_pred_3h_allocated(:,n) = Pgen_pred_3h * generation_allocation(1,n).'*PVPowerGenerationFactor; 
% 
%         Pgen_real_allocated(:,n) = Pgen_real * generation_allocation(1,n).'*PVPowerGenerationFactor;
% 
%     end
% 
% end
% 
% if CoR_type == 2
% 
%     for n=1:members     
%         Pgen_pred_1h_allocated(:,n) = generation_allocation(:,n).*Pgen_pred_1h*PVPowerGenerationFactor;
%         Pgen_pred_3h_allocated(:,n) = generation_allocation(:,n).*Pgen_pred_3h*PVPowerGenerationFactor; 
% 
%         Pgen_real_allocated(:,n) = generation_allocation(:,n).*Pgen_real*PVPowerGenerationFactor;
% 
%     end
% end


%% END OF SECTION TO BE DELETED

% So I paste here header, and see if code runs OK

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
SoC_energy_CER=zeros(SimulationSteps, members);
ElectricitySellingPrice=0.07 * ones(SimulationSteps,1); % Selling price in €/kWh

hour = 1; % Starting hour
weekDay = 1; % May 2023 started on Monday (thus Monday=1, ..., Sunday=7)
quarter_h = 1; % Starting quarter

TotalEnergyDecisionIndividual = zeros(members, 3);
% col 1 = PV energy sold to grid
% col 2 = PV energy directly consumed 
% col 3 = PV energy consumed from battery
% col 4 = PV energy sold to market from battery %TODO implementar

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

% --- Market parameters ---
ServiceSafetyMargin = 0.4; % Insert here value from 0.0 (all margin, no services will be provided) to 1.0 (no margin)
TimeHorizonToBid = 6; % Time horizon from which we start to limit battery
                     % discharge in order to satisfy the bid
% TODO: new variable Length of services in hours (in current version, must be 1) 
% It is assumed that services will consist in giving 1/4 of the energy in
% 15 minutes, for 1 hour straigth                   


%% 2. EC TESTED MODEL

StepProfit=zeros(SimulationSteps,members);
bid_price = 0.11; % Chosen arbitrarily TODO pregunta Albert
energy_cost_bought_while_bid = 0;
bid_profit = zeros(SimulationSteps,1);

% Initalization of tracking vectors and counters
DailyEnergyOrigin = zeros(24*4,3); % Hauria de ser energia, em faltava multiplicar pel timestep (Fet)
TotalEnergyOriginIndividual = zeros(members,3);
StepProfit=zeros(SimulationSteps,members);
EnergyOriginInstant=zeros(SimulationSteps,3); % Hauria de ser energia, em faltava multiplicar pel timestep (Fet)
EnergyOriginInstantIndividual=zeros(SimulationSteps,members,3); % Hauria de ser energia, em faltava multiplicar pel timestep (Fet)

daily_energy_origin = zeros(24*4,3);
total_energy_origin_individual = zeros(members,3);
step_profit=zeros(SimulationSteps,members);
energy_origin_instant=zeros(SimulationSteps,3);
energy_origin_instant_individual=zeros(SimulationSteps,members,3);
selling_price = ElectricitySellingPrice;

% According to the selected sharing coefficient method and the available
% power consumption data (see --- PV power allocation coefficients --- )
% PV power allocation is computed.
[Pgen_pred_1h_allocated, Pgen_pred_3h_allocated, Pgen_real_allocated] = PV_power_allocation_forecasting(Pgen_real, Pgen_pred_1h, ...
    Pgen_pred_3h, GenerationPowerAllocation, PVPowerGenerationFactor, CoR_type, members, weekDay, hour);

for t=1:SimulationSteps % EMPIEZA EL AÑO

    % --- Internal vectors initialization ---
    EnergyStorageMaximumForParticipant=StorageAllocation*MaximumStorageCapacity;
    MaxChargingPowerForParticipant=StorageAllocation*100;
    MaxDischargingPowerForParticipant=StorageAllocation*100;
    StepEnergyOriginIndividual = zeros(members,3);


    % Instante y cantidad oferta
    
    % TODO: encapsular en función
    %PRIMER FER-HO AQUÍ, DESPRÉS PASSAR A FUNCIÓ
    if quarter_h == 1
    [BidAmount, BidStep] = serviceSelection(TimeStep, t, quarter_h, Pgen_pred_1h, PconsForecast1h, price_next_1h, ...
        DischargeEfficiency, ServiceSafetyMargin, MaximumStorageCapacity);
    end


    % Loop for each EC member
    for n=1:members 
    
    % TODO: documentar función y comentar aquí código
    [PVPowerManagementDecision(t,n), bid_case, MaxDishargingPowerForParticipantIfBid] = chooseCF1(TimeHorizonToBid, SoC_energy_CER, BidAmount, t, BidStep, ...
    PconsForecast3h, PconsForecast1h, Pgen_pred_3h_allocated, Pgen_pred_1h_allocated, TimeStep, ...
    price_next_1h, ElectricitySellingPrice, price_next_3h, SoC, price_next_6h, MaxDischargingPowerForParticipant, n);
 

    % This function controlls the use of PV power. The CF has 3 possible
    % outputs: Sell, consume and store. The outcome depends on future consumption,
    % production and price predictions.
    %PVPowerManagementDecision(t,n) = CF1(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
    %Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),ElectricitySellingPrice(t,1),price_next_3h(t,1),SoC(t,n),price_next_6h(t,1)); 
    % Sell: 0, Consume: 1, Store: 2
    
    % If the participant decides on selling the PV generated power to
    % the grid.
    if PVPowerManagementDecision(t,n)==0
        
        if (bid_case == 1) MaxDishargingPowerForParticipant(1,n) = MaxDishargingPowerForParticipantIfBid; end

        % Discharging power is limited by the allocation for each
        % participant
        MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
        
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
                SoC(t+1,n)=SoC(t,n)-((MaxDischargingPowerForParticipant(1,n)*TimeStep)/(EnergyStorageMaximumForParticipant(1,n)*DischargeEfficiency))*100;
                StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+MaxDischargingPowerForParticipant(1,n)*TimeStep;
                StepProfit(t,n)=StepProfit(t,n)-(PconsMeasured(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep*price_next_1h(t,1);
                StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+(PconsMeasured(t,n)-MaxDischargingPowerForParticipant(1,n)*TimeStep);
                TotalEnergyDecisionIndividual(n,3)=TotalEnergyDecisionIndividual(n,3)+MaxDischargingPowerForParticipant(1,n)*TimeStep;


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
        StepProfit(t,n)=StepProfit(t,n)+Pgen_real_allocated(t,n)*TimeStep*ElectricitySellingPrice(t,1);
        TotalEnergyDecisionIndividual(n,1)=TotalEnergyDecisionIndividual(n,1)+Pgen_real_allocated(t,n)*TimeStep;
        
    
    % If the participant decides on instantly consuming PV generated
    % power
    elseif PVPowerManagementDecision(t,n)==1
           
        if (bid_case == 1) MaxDishargingPowerForParticipant(1,n) = MaxDishargingPowerForParticipantIfBid; end

        % Charging power allocation for each participant
        MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
        % Discharging power is limited by the allocation for each
        % participant
        MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
        
        % If PV power allocated to the participant exceeds its power
        % demand 
        if Pgen_real_allocated(t,n)>PconsMeasured(t,n)
            
            % Surplus of PV generated power, which will be used to
            % charge the battery allocation for the participant or sold
            % if the battery allocation is full
            PowerSurplus(t,n)=Pgen_real_allocated(t,n)-PconsMeasured(t,n);
            StepEnergyOriginIndividual(n,1)=StepEnergyOriginIndividual(n,1)+PconsMeasured(t,n)*TimeStep;
            TotalEnergyDecisionIndividual(n,2)=TotalEnergyDecisionIndividual(n,2)+PconsMeasured(t,n)*TimeStep;
            
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
                end
                
            % If the battery allocation of the participant is full, then
            % all surplus has to be sold to the grid
            else
                StepProfit(t,n)=StepProfit(t,n)+PowerSurplus(t,n)*TimeStep*ElectricitySellingPrice(t,1);
                TotalEnergyDecisionIndividual(n,1)=TotalEnergyDecisionIndividual(n,1)+PowerSurplus(t,n)*TimeStep;
                SoC(t+1,n)=SoC(t,n);
            end
        
        % If PV power allocated to the participant does not exceed
        % its power demand, this will have to be supplied with battery
        % power or power purchased from the grid
        else
            PowerShortage(t,n)=PconsMeasured(t,n)-Pgen_real_allocated(t,n);
            StepEnergyOriginIndividual(n,1)=StepEnergyOriginIndividual(n,1)+Pgen_real_allocated(t,n);
            TotalEnergyDecisionIndividual(n,2)=TotalEnergyDecisionIndividual(n,2)+Pgen_real_allocated(t,n)*TimeStep;
            
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
                    % Do not use stored energy: 0, Use stored energy: 1
                    
                    % The battery is used to supply the remaining 
                    % participant's demand
                    if BatteryManagementDecision(t,n) == 1
                        SoC(t+1,n)=SoC(t,n)-(((PowerShortage(t,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                        StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+PowerShortage(t,n)*TimeStep;
                        TotalEnergyDecisionIndividual(n,3)=TotalEnergyDecisionIndividual(n,3)+(PowerShortage(t,n)*TimeStep)/DischargeEfficiency;

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
                    % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                    
                    % A combination of power from the battery and grid
                    % is used to supply the remaining demand
                    if BatteryManagementDecision(t,n) == 1
                        SoC(t+1,n)=SoC(t,n)-((MaxDischargingPowerForParticipant(1,n)*TimeStep)/(EnergyStorageMaximumForParticipant(1,n)*DischargeEfficiency))*100;
                        StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+MaxDischargingPowerForParticipant(1,n)*TimeStep;
                        StepProfit(t,n)= StepProfit(t,n)-(PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep*price_next_1h(t,1)*DischargeEfficiency;
                        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+(PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep;
                        TotalEnergyDecisionIndividual(n,3)=TotalEnergyDecisionIndividual(n,3)+MaxDischargingPowerForParticipant(1,n)*TimeStep;


                    % Only the grid is used to supply the remaining
                    % demand
                    else
                        StepProfit(t,n)=StepProfit(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
                        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PowerShortage(t,n);%*Unidad_t;
                        SoC(t+1,n)=SoC(t,n);
                    end
                end
            
            % If the participant's battery allocation is empty, demand
            % can only be supplied by power purchased from grid
            else
                StepProfit(t,n)=StepProfit(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
                StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PowerShortage(t,n);%*Unidad_t;
                SoC(t+1,n)=SoC(t,n);
            end
        end
        
    
    % If the participant decides on storing all PV generated power
    elseif PVPowerManagementDecision(t,n) == 2
        MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
        
        % If the PV generated power does not exceed the maximum charging
        % power for the participant's battery allocation, all power is used
        % to charge the battery
        if Pgen_real_allocated(t,n)<MaxChargingPowerForParticipant(1,n)
            SoC(t+1,n)=SoC(t,n)+((Pgen_real_allocated(t,n)*TimeStep*ChargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
        
        % If the PV generated power exceeds the maximum charging power for
        % the participant's battery allocation, then the power surplus is
        % sold to the grid
        else
            SoC(t+1,n)=SoC(t,n)+(MaxChargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n)*100;
            StepProfit(t,n)=StepProfit(t,n)+(Pgen_real_allocated(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep*ElectricitySellingPrice(t,1);
            TotalEnergyDecisionIndividual(n,1) = TotalEnergyDecisionIndividual(n,1) + (Pgen_real_allocated(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep;
        end
        
        StepProfit(t,n)=StepProfit(t,n)-PconsMeasured(t,n)*TimeStep*price_next_1h(t,1);
        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PconsMeasured(t,n)*TimeStep;
    
    end
    
    % Update individual tracking vector
    EnergyOriginInstantIndividual(t,n,:) = StepEnergyOriginIndividual(n,:);

    ServiceProviding = checkForServiceProviding(t, BidStep);
    if (ServiceProviding == true)
        [SoC, bid_profit, StepProfit] = provideService(t, n, SoC, BidStep, StorageAllocation, BidAmount, ...
            MaximumStorageCapacity, StepProfit, GenerationPowerAllocation, bid_price, ...
            energy_cost_bought_while_bid, EnergyOriginInstant, price_next_1h);
    end

    end % Loop for each CE member ends
    
    
    % --- Update of tracking vectors and counters
    for i=1:3
    EnergyOriginInstant(t,i) = sum(EnergyOriginInstantIndividual(t,:,i));
    end
    DailyEnergyOrigin(quarter_h,:) = DailyEnergyOrigin(quarter_h,:) + sum(StepEnergyOriginIndividual(:,:));
    TotalEnergyOriginIndividual(:,:)=TotalEnergyOriginIndividual(:,:) + StepEnergyOriginIndividual(:,:);
    SoC_energy_CER(t+1) = getSoCEnergyEC(members, MaximumStorageCapacity, StorageAllocation, SoC, t);
    
    % Advance to next quarter
    [quarter_h,hour,weekDay] = goToNextTimeStep(quarter_h,hour,weekDay);

end % Simulation loop

% Aggregate variables at simulation end
final_bill = -sum(StepProfit);
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

t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t = t1:minutes(15):t2;
t = t';

figure(20)
plot(t(1:672),EnergyOriginInstant(1:672,1),t(1:672),EnergyOriginInstant(1:672,2),t(1:672),EnergyOriginInstant(1:672,3))
title('Potencia consumida según origen')
legend('Origen placas','Origen batería','Origen red eléctrica')
ylabel('Potencia consumida (kW)')
xlabel('Tiempo')
