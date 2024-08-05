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

hour = 1; % Starting hour
weekDay = 1; % May 2023 started on Monday (thus Monday=1, ..., Sunday=7)
quarter_h = 1; % Starting quarter

% USO DE ENERGÍA DE GENERACIÓN
% TODO: Implementar esta agregación del uso de la potencia generada
TotalEnergyDecisionIndividual = zeros(members, 5);
% col 1 = vender red
% col 2 = consumir placas
% col 3 = consumir bat
% col 4 = vender p2p ----> En principi aquí no hi ha p2p, no? per tant
                         % serien 4 columnes?
% col 5 = vender mercado (interop)


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
DailyEnergyOrigin = zeros(24*4,3);
TotalEnergyOriginIndividual = zeros(members,3);
StepProfit=zeros(SimulationSteps,members);
EnergyOriginInstant=zeros(SimulationSteps,3);
EnergyOriginInstantIndividual=zeros(SimulationSteps,members,3);


% According to the selected sharing coefficient method and the available
% power consumption data (see --- PV power allocation coefficients --- )
% PV power allocation is computed.
[Pgen_pred_1h_allocated, Pgen_pred_3h_allocated, Pgen_real_allocated] = PV_power_allocation_forecasting(Pgen_real, Pgen_pred_1h, ...
    Pgen_pred_3h, GenerationPowerAllocation, PVPowerGenerationFactor, CoR_type, members, weekDay, hour);


% Simulation loop
for t=1:SimulationSteps

EnergyStorageMaximumForParticipant=StorageAllocation*MaximumStorageCapacity;
MaxChargingPowerForParticipant=StorageAllocation*100;
MaxDischargingPowerForParticipant=StorageAllocation*100;
StepEnergyOriginIndividual = zeros(members,3);

for n=1:members % Loop for each EC member
       
   PV_energy_management_decission(t,n) = CF1(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                     Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),ElectricitySellingPrice(t,1),price_next_3h(t,1),SoC(t,n),price_next_6h(t,1));
   caso_oferta = 0;
   % La salida de la función sería un entero entre 0 i 2?
   % 0 vender, 1 consumir y 2 almacenar


% Se decide vender la energía generada y a continuación se evalúa para los
% distintos casos si deberíamos o no extraer energía de la batería para
% consumir. En caso de usar la batería, no se extrae más de lo que se vaya
% a consumir (batería individual, sabemos las necesidades de cada uno). En
% cualquier caso se compra la energía que nos falte de la red. 
   if PV_energy_management_decission(t,n)==0
       
       MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
  
       if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)>0
           if PconsMeasured(t,n)<MaxDischargingPowerForParticipant(1,n)
               battery_management_decission(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
               % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
               if battery_management_decission(t,n)==1
                   SoC(t+1,n)=SoC(t,n)-(((PconsMeasured(t,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                   StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+PconsMeasured(t,n);%*Unidad_t;
               else
                   StepProfit(t,n)=StepProfit(t,n)-PconsMeasured(t,n)*TimeStep*price_next_1h(t,1);
                   StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PconsMeasured(t,n);%*Unidad_t;
                   SoC(t+1,n)=SoC(t,n);
               end
           else
               battery_management_decission(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
               % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
               if battery_management_decission(t,n)==1
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

   elseif PV_energy_management_decission(t,n)==1
       if (caso_oferta == 1) MaxDischargingPowerForParticipant(1,n) = P_discharge_max_oferta; end
       
       MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
       MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));

       if Pgen_real_allocated(t,n)>PconsMeasured(t,n)
           PowerSurplus(t,n)=Pgen_pred_1h_allocated(t,n)-PconsMeasured(t,n);
           StepEnergyOriginIndividual(n,1)=StepEnergyOriginIndividual(n,1)+PconsMeasured(t,n);%*Unidad_t;
           if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)<100
               if PowerSurplus(t,n)<MaxChargingPowerForParticipant(1,n)
                   SoC(t+1,n)=SoC(t,n)+((PowerSurplus(t,n)*TimeStep*ChargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
               else
                   SoC(t+1,n)=SoC(t,n)+((MaxChargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n))*100;
                   StepProfit(t,n)=StepProfit(t,n)+(PowerSurplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep*ElectricitySellingPrice(t,1);
               end
           else
               StepProfit(t,n)=StepProfit(t,n)+PowerSurplus(t,n)*TimeStep*ElectricitySellingPrice(t,1);
               SoC(t+1,n)=SoC(t,n);
           end
       else
           PowerShortage(t,n)=PconsMeasured(t,n)-Pgen_real_allocated(t,n);
           StepEnergyOriginIndividual(n,1)=StepEnergyOriginIndividual(n,1)+Pgen_real_allocated(t,n);
           if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)>0
               if PowerShortage(t,n)<MaxDischargingPowerForParticipant(1,n)
                   battery_management_decission(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
               
                   % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                   if battery_management_decission(t,n) == 1
                       SoC(t+1,n)=SoC(t,n)-(((PowerShortage(t,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                       StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+PowerShortage(t,n);%*Unidad_t;
                   else
                       StepProfit(t,n)=StepProfit(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
                       StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PowerShortage(t,n);%*Unidad_t;
                       SoC(t+1,n)=SoC(t,n);
                   end
               else
                   battery_management_decission(t,n) = CF2(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                   % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                   if battery_management_decission(t,n) == 1
                        SoC(t+1,n)=SoC(t,n)-((MaxDischargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n))*100;
                        StepEnergyOriginIndividual(n,2)=StepEnergyOriginIndividual(n,2)+MaxDischargingPowerForParticipant(1,n);%*Unidad_t; %*Ef_discharge
                        StepProfit(t,n)= StepProfit(t,n)-(PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep*price_next_1h(t,1); %*Ef_discharge
                        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+(PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n));%*Unidad_t; %*Ef_discharge
                   else
                        StepProfit(t,n)=StepProfit(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
                        StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PowerShortage(t,n);%*Unidad_t;
                        SoC(t+1,n)=SoC(t,n);
                   end
               end
           else
               StepProfit(t,n)=StepProfit(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
               StepEnergyOriginIndividual(n,3)=StepEnergyOriginIndividual(n,3)+PowerShortage(t,n);%*Unidad_t;
               SoC(t+1,n)=SoC(t,n);
           end
       end
% Se almacena toda la energía generada o hasta llenar el SoC. En caso de
% llenar el SoC se vende el resto.
   else % Decision1=2
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
[quarter_h,hour,weekDay] = siguiente_ch(quarter_h,hour,weekDay);


end

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

%% 3. EC RULE-BASED REFERENCE MODEL


% --- Internal parameters ---
PowerSurplus=zeros(SimulationSteps,members);
PowerShortage=zeros(SimulationSteps,members);
SoC=ones(SimulationSteps+1,members)*0; % SoC inicial del 50% por poner algo
%Ef_charge=0.97;
%Ef_discharge=0.97;
step_profit_unoptimised=zeros(SimulationSteps,members);
daily_energy_origin_unoptimised = zeros(24*4,3);
sold_energy_unoptimised = zeros(24*4,members);
step_energy_origin_unoptimised = zeros(SimulationSteps,3);
total_energy_origin_individual_unoptimised=zeros(members,3);

% TESTING PURPOSES ONLY
hour = 1;
weekDay = 1; % Mayo 2023 empieza lunes
quarter_h = 1;

% FristFriSample = 385 (ch = 1)
% LastFriSample = 480 (ch = 96)
%instante_oferta = 481 - (16*4); %(ch = 88, 22:00 del viernes)
%cantidad_oferta = 0;
%coste_energia_comprada_mientras_oferta = 0;
%SoC_energy_CER = zeros(length(SoC),1);

% TODO: Considerar si este código también puede estar integrado en la
% función mencionada anteriormente.
% Input: Pgen_real, generation_allocation, factor_gen, CoR_type, members
% Output: Pgen_real_allocated
[Pgen_real_allocated] = PV_power_allocation(Pgen_real, GenerationPowerAllocation, PVPowerGenerationFactor, CoR_type, members, weekDay, hour); 

for t=1:SimulationSteps
   
step_energy_origin_individual_unoptimised = zeros(members,3);

EnergyStorageMaximumForParticipant=StorageAllocation*MaximumStorageCapacity;
MaxChargingPowerForParticipant=StorageAllocation*100;
MaxDischargingPowerForParticipant=StorageAllocation*100;


    for n=1:members %EMPIEZA EL ALGORITMO

    MaxChargingPowerForParticipant(1,n)=min(MaxChargingPowerForParticipant(1,n)*ChargeEfficiency,((100-SoC(t,n))/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));
    MaxDischargingPowerForParticipant(1,n)=min(MaxDischargingPowerForParticipant(1,n)*DischargeEfficiency,(SoC(t,n)/100)*EnergyStorageMaximumForParticipant(1,n)*(1/TimeStep));

      if Pgen_real_allocated(t,n)>PconsMeasured(t,n)
           PowerSurplus(t,n)=Pgen_real_allocated(t,n)-PconsMeasured(t,n);
           step_energy_origin_individual_unoptimised(n,1) = step_energy_origin_individual_unoptimised(n,1) + PconsMeasured(t,n);%Unidad_t;
           if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)<100
               if PowerSurplus(t,n)<MaxChargingPowerForParticipant(1,n)
                   SoC(t+1,n)=SoC(t,n)+((PowerSurplus(t,n)*TimeStep*ChargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
               else
                   SoC(t+1,n)=SoC(t,n)+((MaxChargingPowerForParticipant(1,n)*TimeStep)/EnergyStorageMaximumForParticipant(1,n))*100;
                   sold_energy_unoptimised(quarter_h,n) = sold_energy_unoptimised(quarter_h,n) + (PowerSurplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep;
                   step_profit_unoptimised(t,n)=step_profit_unoptimised(t,n)+(PowerSurplus(t,n)-MaxChargingPowerForParticipant(1,n)/ChargeEfficiency)*TimeStep*ElectricitySellingPrice(t,1);
               end
           else
               step_profit_unoptimised(t,n)=step_profit_unoptimised(t,n)+PowerSurplus(t,n)*TimeStep*ElectricitySellingPrice(t,1);
               sold_energy_unoptimised(quarter_h,n) = sold_energy_unoptimised(quarter_h,n) + PowerSurplus(t,n)*TimeStep;
               SoC(t+1,n)=SoC(t,n);
           end
       else
           PowerShortage(t,n)=PconsMeasured(t,n)-Pgen_real_allocated(t,n);
           step_energy_origin_individual_unoptimised(n,1) = step_energy_origin_individual_unoptimised(n,1) + Pgen_real_allocated(t,n);%Unidad_t
           if EnergyStorageMaximumForParticipant(1,n)>0 && SoC(t,n)>0
               if PowerShortage(t,n)<MaxDischargingPowerForParticipant(1,n)
                    SoC(t+1,n)=SoC(t,n)-(((PowerShortage(t,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                    step_energy_origin_individual_unoptimised(n,2) = step_energy_origin_individual_unoptimised(n,2) + PowerShortage(t,n);%Unidad_t
               else
                    SoC(t+1,n)=SoC(t,n)-(((MaxDischargingPowerForParticipant(1,n)*TimeStep)/DischargeEfficiency)/EnergyStorageMaximumForParticipant(1,n))*100;
                    step_energy_origin_individual_unoptimised(n,2) = step_energy_origin_individual_unoptimised(n,2) + MaxDischargingPowerForParticipant(1,n);%Unidad_t
                    step_profit_unoptimised(t,n)= step_profit_unoptimised(t,n)-(PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n))*TimeStep*price_next_1h(t,1);
                    step_energy_origin_individual_unoptimised(n,3) = step_energy_origin_individual_unoptimised(n,3) + (PowerShortage(t,n)-MaxDischargingPowerForParticipant(1,n));%Unidad_t
               end
           else
               step_profit_unoptimised(t,n)=step_profit_unoptimised(t,n)-PowerShortage(t,n)*TimeStep*price_next_1h(t,1);
               step_energy_origin_individual_unoptimised(n,3) = step_energy_origin_individual_unoptimised(n,3) + PowerShortage(t,n);%Unidad_t
               SoC(t+1,n)=SoC(t,n);
           end
       end  
    end
    
    step_energy_origin_unoptimised(t,:) = sum(step_energy_origin_individual_unoptimised(:,:));

    [quarter_h,hour,weekDay] = siguiente_ch(quarter_h,hour,weekDay);
end

% Comparació balance optimitzant/sense optimitzar

final_bill_unoptimised = -sum(step_profit_unoptimised);

Y = categorical({'Optimización','Reglas estáticas'});
Y = reordercats(Y,{'Optimización','Reglas estáticas'});

total_final_bill = sum(final_bill);
total_final_bill_unoptimised = sum(final_bill_unoptimised);


%% 4. RESULTS: KPIs AND PLOTS

[ADR,POR,avg_days] = consumption_profile_metrics(PconsMeasured);
[CBU, ADC, BCPD] = battery_metrics(SoC_energy_CER, MaximumStorageCapacity, SimulationDays, SimulationSteps);

% --- Plots ---
t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t = t1:minutes(15):t2;
t = t';

CE_SoC_signal = 100*SoC_energy_CER(1:672)/MaximumStorageCapacity;

Pcons_agg = zeros(SimulationSteps,1);
for i = 1:SimulationSteps
    Pcons_agg(i) = sum(PconsMeasured(i,:));
end

figure(101)
plot(t(1:672), Pcons_agg(1:672), t(1:672), Pgen_real(1:672))
title('Aggregated power consumption vs aggregated power generation')
ylabel('Power [kW]')
xlabel('Time')
legend('Aggregated power consumption','Aggregated power generation')

figure(102)
bar(TotalEnergyOriginIndividual*100,'stacked')
title('Power consumption by origin')
ylabel('Power consumption [%]')
xlabel('Participant')
ylim([0 100])
legend('FV','Battery','Grid')

figure(103)
% total_energy_decision_invidual: 6 filas (members) x 5 cols (acciones)
% Valores en % para el total de cada fila
aux_fig102 = [0.2, 0.1, 0.25, 0.15, 0.3;
    0.1, 0.25, 0.2, 0.15, 0.3;
    0.2, 0.1, 0.15, 0.15, 0.4;
    0.25, 0.15, 0.2, 0.10, 0.3;
    0.2, 0.1, 0.2, 0.25, 0.25];
aux_fig102 = 100*aux_fig102;
bar(aux_fig102,'stacked')
title('Power usage of RE')
ylim([0 100])
ylabel('Renewable power [%]')
xlabel('Participant')
legend('Sold to grid','Consumed from PV', 'Consumed from Battery','Sold P2P', 'Sold to Market')

% Pendiente añadir en este gráfico anotaciones con métricas de BAT
figure(104)
plot(t(1:672),CE_SoC_signal)
title("Battery State of Charge (SoC), AUR: [" + num2str(ADC(1), '%05.2f') + ", " ...
    + num2str(ADC(2), '%05.2f') + "] [%], CBU: " + num2str(CBU, '%05.2f') + ", ADC: " ...
    + num2str(BCPD, '%05.2f'), FontSize=14)
ylabel('SoC [%]')
xlabel('Time')
ylim([0 100])
% dim = [0.15 0.5 0.5 0.4];
% str = {'AUR' [AUR(1),AUR(2)], 'CBC' CBC, 'BCPD' BCPD};
% annotation('textbox',dim,'String',str,'FitBoxToText','on');


% Pendiente añadir en este gráfico anotaciones con métricas perfiles de
% consumo
figure(105)
qs = 1:1:96;
plot(qs, avg_days(:,1), qs, avg_days(:,2), qs, avg_days(:,3), qs, avg_days(:,4), qs, avg_days(:,5), qs, avg_days(:,6))
title("Average-day power consumption for each CE member, POR: [" + num2str(POR(1), '%05.2f') ...
    + ", " + num2str(POR(2), '%05.2f') + ", " + num2str(POR(3), '%05.2f') + "] [%], ADR: " + num2str(ADR, '%05.2f') + " [kW]", FontSize=14)
legend('P1', 'P2', 'P3', 'P4', 'P5', 'P6')
xlim([1 96])
ylabel('Power [kW]')
xlabel('Time, in quarters')
% dim = [0.15 0.5 0.5 0.4];
% str = {'POR' POR, 'ADR' ADR};
% annotation('textbox',dim,'String',str,'FitBoxToText','on');


%% 5. LEGACY
% figure(7)
% bar(total_energy_origin_individual,'stacked')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% 
% 
% figure(17)
% bar(Y,[total_final_bill total_final_bill_unoptimised])
% title("Facturación agregada de la comunidad (semanal)")
% ylabel('Euros (€)')
% 
% t1 = datetime(2023,5,1,0,0,0);
% t2 = datetime(2023,5,31,0,0,0);
% t = t1:minutes(15):t2;
% t = t';

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
% 
% figure(20)
% plot(t(1:672),energy_origin_instant(1:672,1),t(1:672),energy_origin_instant(1:672,2),t(1:672),energy_origin_instant(1:672,3))
% title('Potencia consumida según origen')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Potencia consumida (kW)')
% xlabel('Tiempo')
% % yyaxis right
% % plot(t(1:672), Pgen_real(1:672))
% 
% figure(21)
% plot(t(1:672),price_next_1h(1:672))
% title('Precio de compra de electricidad a la red')
% ylabel('Precio (€/kWh)')
% xlabel('Tiempo')

% figure(22)
% plot(t(1:672), Pgen_real(1:672))
% 
% consumo_part_segun_origen = zeros(6,3);
% 
% for i = 1:num_parts
%     acum_plac = 0;
%     acum_bat = 0;
%     acum_red = 0;
%     for j = 1:steps
%         acum_plac = acum_plac + origen_por_horas_por_part(j,i,1);
%         acum_bat = acum_bat + origen_por_horas_por_part(j,i,2);
%         acum_red = acum_red + origen_por_horas_por_part(j,i,3);
%     end
%     total_aux = acum_plac + acum_bat + acum_red;
%     consumo_part_segun_origen(i,1) = acum_plac/total_aux;
%     consumo_part_segun_origen(i,2) = acum_bat/total_aux;
%     consumo_part_segun_origen(i,3) = acum_red/total_aux;
% end
% 
% X = categorical({'P1','P2','P3','P4','P5','P6'});
% X = reordercats(X,{'P1','P2','P3','P4','P5','P6'});
% figure(23)
% bar(X,consumo_part_segun_origen*100,'stacked')
% title('Desglose del consumo por participante (semanal)')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('%')
% % ylim([0 100])

% SoC_energy_CER_no_oferta = SoC_energy_CER;
% save("SoC_energy_CER_no_oferta.mat", "SoC_energy_CER_no_oferta");
% 
% SoC_energy_CER_ofertas = SoC_energy_CER;
% load SoC_energy_CER_no_oferta.mat

% plot(t(96*1:96*2),SoC_energy_CER_ofertas(96*1:96*2),t(96*1:96*2),SoC_energy_CER_no_oferta(96*1:96*2));
% title('Comparación de la gestión de la batería al considerar la prestación de servicios')
% legend('Con oferta','Sin oferta')
% ylabel('SoC (%)')
% xlabel('Tiempo')
% ylim([0 100])
% 
% figure(24)
% plot(t(96+1:96*2+1),100*SoC_energy_CER(96+1:96*2+1)/capacidad,t(96+1:96*2+1),100*SoC_energy_CER_no_oferta(96+1:96*2+1)/capacidad)
% title('Comparación de la gestión de la batería al considerar el cumplimiento de una oferta')
% ylabel('SoC (%)')
% xlabel('Tiempo')
% legend('Con oferta', 'Sin oferta')
% ylim([0 100])
% 
% figure(25)
% plot(t(4*96+1:96*5+1),100*SoC_energy_CER(4*96+1:96*5+1)/capacidad,t(4*96+1:96*5+1),100*SoC_energy_CER_no_oferta(4*96+1:96*5+1)/capacidad)
% title('Comparación de la gestión de la batería al considerar el cumplimiento de una oferta')
% ylabel('SoC (%)')
% xlabel('Tiempo')
% legend('Con oferta', 'Sin oferta')
% ylim([0 100])

% figure(26)
% plot(t(1:672),origen_por_horas_por_part(1:672,1,1),t(1:672),origen_por_horas_por_part(1:672,1,2),t(1:672),origen_por_horas_por_part(1:672,1,3))
% title('Potencia consumida según origen, participante 1')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Potencia consumida (kW)')
% xlabel('Tiempo')
% 
% figure(27)
% plot(t(1:672),origen_por_horas_por_part(1:672,2,1),t(1:672),origen_por_horas_por_part(1:672,2,2),t(1:672),origen_por_horas_por_part(1:672,2,3))
% title('Potencia consumida según origen, participante 2')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Potencia consumida (kW)')
% xlabel('Tiempo')
% 
% figure(28)
% plot(t(1:672),origen_por_horas_por_part(1:672,3,1),t(1:672),origen_por_horas_por_part(1:672,3,2),t(1:672),origen_por_horas_por_part(1:672,3,3))
% title('Potencia consumida según origen, participante 3')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Potencia consumida (kW)')
% xlabel('Tiempo')
% 
% figure(29)
% plot(t(1:672),origen_por_horas_por_part(1:672,4,1),t(1:672),origen_por_horas_por_part(1:672,4,2),t(1:672),origen_por_horas_por_part(1:672,4,3))
% title('Potencia consumida según origen, participante 4')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Potencia consumida (kW)')
% xlabel('Tiempo')
% 
% figure(30)
% plot(t(1:672),origen_por_horas_por_part(1:672,5,1),t(1:672),origen_por_horas_por_part(1:672,5,2),t(1:672),origen_por_horas_por_part(1:672,5,3))
% title('Potencia consumida según origen, participante 5')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Potencia consumida (kW)')
% xlabel('Tiempo')
% 
% figure(31)
% plot(t(1:672),origen_por_horas_por_part(1:672,6,1),t(1:672),origen_por_horas_por_part(1:672,6,2),t(1:672),origen_por_horas_por_part(1:672,6,3))
% title('Potencia consumida según origen, participante 6')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Potencia consumida (kW)')
% xlabel('Tiempo')
