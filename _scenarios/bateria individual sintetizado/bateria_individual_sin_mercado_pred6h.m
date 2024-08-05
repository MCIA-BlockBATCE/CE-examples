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


% --- EC consumption profiles ---
surplus_community = [4 7 8 10 12 13];
%deficit_community = [x x x x x x];
%balanced_community = [x x x x x x];

CER = surplus_community;

% --- PV power allocation coefficients ---
CoR_type = 0; % fixed allocation
% CoR_type = 1; % allocation based on the moment of the week (variable)
% CoR_type = 2; % allocation based on consumption of previous step (dynamic variable)


% --- Battery parameters ---
Ef_charge=0.97;
Ef_discharge=0.97;
max_capacity=200;
factor_gen = 1;


% --- Internal parameters ---
days = 7;
steps = 24*4*days;
members=length(CER);
time_unit=0.25; % Time between steps in seconds
P_surplus=zeros(steps,members); 
P_shortage=zeros(steps,members);
SoC=ones(steps+1,members)*0; % Initial SoC
selling_price=0.07 * ones(steps,1); % Selling price in €/kWh

hour = 1;
week_day = 1; % May 2023 started on Monday
quarter_h = 1;

% USO DE ENERGÍA DE GENERACIÓN
total_energy_decision_individual = zeros(members, 5);
% col 1 = vender red
% col 2 = consumir placas
% col 3 = consumir bat
% col 4 = vender p2p ----> En principi aquí no hi ha p2p, no? per tant
                         % serien 4 columnes?
% col 5 = vender mercado (interop)


% --- Input data ---
load("..\..\_data\Pgen_real.mat")
load("..\..\_data\Pgen_real_3h.mat")

% NOTA: Estas tablas NO contienen columnas de marca temporal separada dia,
% mes año, hora
% NOTA: Paso a potencia (kW) la magnitud de energía (kWh), multiplico por 4
% NOTA: aquí cargo TODOS los perfiles de consumo, y ya luego elegimos la
% comunidad
load("..\..\_data\energia_cons_CER.mat")
load("..\..\_data\energia_cons_CER_3h.mat")

Pcons_real = energia_cons_CER(:,CER) * 4;
Pcons_real_3h = energia_cons_CER_3h(:,CER) * 4;

% NOTA: Fórmula Osterwald da como output potencia (kW)
load("..\..\_data\Pgen_pred_1h.mat")
load("..\..\_data\Pgen_pred_3h.mat")

% Carguem prediccions ANFIS
load("..\..\_data\Pcons_pred_1h.mat")
load("..\..\_data\Pcons_pred_3h.mat")

% Passem a potencia
Pcons_pred_1h = 4 * Pcons_pred_1h(:,CER);
Pcons_pred_3h = 4 * Pcons_pred_3h(:,CER);

load("..\..\_data\buying_prices.mat");

[generation_allocation, storage_allocation] = allocation_coefficients(CoR_type, CER);


%% 2. EC TESTED MODEL


daily_energy_origin = zeros(24*4,3);
total_energy_origin_individual = zeros(members,3);
step_profit=zeros(steps,members);
energy_origin_instant=zeros(steps,3);
energy_origin_instant_individual=zeros(steps,members,3);

% TODO: Considerar si este código también puede estar integrado en la
% función mencionada anteriormente.
% Input: Pgen_real, Pgen_pred_1h, Pgen_pred_3h, generation_allocation,
% factor_gen, CoR_type, members, week_day, hour
% Output: Pgen_pred_1h_allocated, Pgen_pred_3h_allocated, Pgen_real_allocated 
[Pgen_pred_1h_allocated, Pgen_pred_3h_allocated, Pgen_real_allocated] = PV_power_allocation_forecasting(Pgen_real, Pgen_pred_1h, ...
    Pgen_pred_3h, generation_allocation, factor_gen, CoR_type, members, week_day, hour);



for t=1:steps % EMPIEZA EL AÑO

E_st_max=storage_allocation*max_capacity;
P_charge_max=storage_allocation*100;
P_discharge_max=storage_allocation*100;

step_energy_origin_individual = zeros(members,3);

for n=1:members %EMPIEZA EL ALGORITMO
       
   PV_energy_management_decission(t,n) = CF1(Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                     Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),selling_price(t,1),price_next_3h(t,1),SoC(t,n),price_next_6h(t,1));
   caso_oferta = 0;
   % La salida de la función sería un entero entre 0 i 2?
   % 0 vender, 1 consumir y 2 almacenar


% Se decide vender la energía generada y a continuación se evalúa para los
% distintos casos si deberíamos o no extraer energía de la batería para
% consumir. En caso de usar la batería, no se extrae más de lo que se vaya
% a consumir (batería individual, sabemos las necesidades de cada uno). En
% cualquier caso se compra la energía que nos falte de la red. 
   if PV_energy_management_decission(t,n)==0
       
       P_discharge_max(1,n)=min(P_discharge_max(1,n)*Ef_discharge,(SoC(t,n)/100)*E_st_max(1,n)*(1/time_unit));
  
       if E_st_max(1,n)>0 && SoC(t,n)>0
           if Pcons_real(t,n)<P_discharge_max(1,n)
               battery_management_decission(t,n) = CF2(Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
               % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
               if battery_management_decission(t,n)==1
                   SoC(t+1,n)=SoC(t,n)-(((Pcons_real(t,n)*time_unit)/Ef_discharge)/E_st_max(1,n))*100;
                   step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+Pcons_real(t,n);%*Unidad_t;
               else
                   step_profit(t,n)=step_profit(t,n)-Pcons_real(t,n)*time_unit*price_next_1h(t,1);
                   step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+Pcons_real(t,n);%*Unidad_t;
                   SoC(t+1,n)=SoC(t,n);
               end
           else
               battery_management_decission(t,n) = CF2(Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
               % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
               if battery_management_decission(t,n)==1
                   SoC(t+1,n)=SoC(t,n)-((P_discharge_max(1,n)*time_unit)/E_st_max(1,n))*100;
                   step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+P_discharge_max(1,n)*Ef_discharge;%*Unidad_t;
                   step_profit(t,n)=step_profit(t,n)-(Pcons_real(t,n)-P_discharge_max(1,n)*Ef_discharge)*time_unit*price_next_1h(t,1);
                   step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+(Pcons_real(t,n)-P_discharge_max(1,n)*Ef_discharge);%*Unidad_t;
               else
                  step_profit(t,n)=step_profit(t,n)-Pcons_real(t,n)*time_unit*price_next_1h(t,1);
                  step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+Pcons_real(t,n);%*Unidad_t;
                  SoC(t+1,n)=SoC(t,n);
               end
           end 
       else
           step_profit(t,n)=step_profit(t,n)-Pcons_real(t,n)*time_unit*price_next_1h(t,1);
           step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+Pcons_real(t,n);%*Unidad_t;
       end
      step_profit(t,n)=step_profit(t,n)+Pgen_pred_1h_allocated(t,n)*time_unit*selling_price(t,1);

% Se decide consumir la energía consumida. En caso de déficit se evalua si
% usar la batería y se compra la energía que falte. En caso de superávit se
% almacena toda la posible y se vende el resto.

   elseif PV_energy_management_decission(t,n)==1
       if (caso_oferta == 1) P_discharge_max(1,n) = P_discharge_max_oferta; end
       
       P_charge_max(1,n)=min(P_charge_max(1,n)*Ef_charge,((100-SoC(t,n))/100)*E_st_max(1,n)*(1/time_unit));
       P_discharge_max(1,n)=min(P_discharge_max(1,n)*Ef_discharge,(SoC(t,n)/100)*E_st_max(1,n)*(1/time_unit));

       if Pgen_real_allocated(t,n)>Pcons_real(t,n)
           P_surplus(t,n)=Pgen_pred_1h_allocated(t,n)-Pcons_real(t,n);
           step_energy_origin_individual(n,1)=step_energy_origin_individual(n,1)+Pcons_real(t,n);%*Unidad_t;
           if E_st_max(1,n)>0 && SoC(t,n)<100
               if P_surplus(t,n)<P_charge_max(1,n)
                   SoC(t+1,n)=SoC(t,n)+((P_surplus(t,n)*time_unit*Ef_charge)/E_st_max(1,n))*100;
               else
                   SoC(t+1,n)=SoC(t,n)+((P_charge_max(1,n)*time_unit)/E_st_max(1,n))*100;
                   step_profit(t,n)=step_profit(t,n)+(P_surplus(t,n)-P_charge_max(1,n)/Ef_charge)*time_unit*selling_price(t,1);
               end
           else
               step_profit(t,n)=step_profit(t,n)+P_surplus(t,n)*time_unit*selling_price(t,1);
               SoC(t+1,n)=SoC(t,n);
           end
       else
           P_shortage(t,n)=Pcons_real(t,n)-Pgen_real_allocated(t,n);
           step_energy_origin_individual(n,1)=step_energy_origin_individual(n,1)+Pgen_real_allocated(t,n);
           if E_st_max(1,n)>0 && SoC(t,n)>0
               if P_shortage(t,n)<P_discharge_max(1,n)
                   battery_management_decission(t,n) = CF2(Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
               
                   % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                   if battery_management_decission(t,n) == 1
                       SoC(t+1,n)=SoC(t,n)-(((P_shortage(t,n)*time_unit)/Ef_discharge)/E_st_max(1,n))*100;
                       step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+P_shortage(t,n);%*Unidad_t;
                   else
                       step_profit(t,n)=step_profit(t,n)-P_shortage(t,n)*time_unit*price_next_1h(t,1);
                       step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+P_shortage(t,n);%*Unidad_t;
                       SoC(t+1,n)=SoC(t,n);
                   end
               else
                   battery_management_decission(t,n) = CF2(Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                   % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                   if battery_management_decission(t,n) == 1
                        SoC(t+1,n)=SoC(t,n)-((P_discharge_max(1,n)*time_unit)/E_st_max(1,n))*100;
                        step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+P_discharge_max(1,n);%*Unidad_t; %*Ef_discharge
                        step_profit(t,n)= step_profit(t,n)-(P_shortage(t,n)-P_discharge_max(1,n))*time_unit*price_next_1h(t,1); %*Ef_discharge
                        step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+(P_shortage(t,n)-P_discharge_max(1,n));%*Unidad_t; %*Ef_discharge
                   else
                        step_profit(t,n)=step_profit(t,n)-P_shortage(t,n)*time_unit*price_next_1h(t,1);
                        step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+P_shortage(t,n);%*Unidad_t;
                        SoC(t+1,n)=SoC(t,n);
                   end
               end
           else
               step_profit(t,n)=step_profit(t,n)-P_shortage(t,n)*time_unit*price_next_1h(t,1);
               step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+P_shortage(t,n);%*Unidad_t;
               SoC(t+1,n)=SoC(t,n);
           end
       end
% Se almacena toda la energía generada o hasta llenar el SoC. En caso de
% llenar el SoC se vende el resto.
   else % Decision1=2
       P_charge_max(1,n)=min(P_charge_max(1,n)*Ef_charge,((100-SoC(t,n))/100)*E_st_max(1,n)*(1/time_unit));
       if Pgen_real_allocated(t,n)<P_charge_max(1,n)
           SoC(t+1,n)=SoC(t,n)+((Pgen_pred_1h_allocated(t,n)*time_unit*Ef_charge)/E_st_max(1,n))*100;
       else
           SoC(t+1,n)=SoC(t,n)+(P_charge_max(1,n)*time_unit)/E_st_max(1,n)*100;
           step_profit(t,n)=step_profit(t,n)+(Pgen_real_allocated(t,n)-P_charge_max(1,n)/Ef_charge)*time_unit*selling_price(t,1);
       end
       step_profit(t,n)=step_profit(t,n)-Pcons_real(t,n)*time_unit*price_next_1h(t,1);
       step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+Pcons_real(t,n);%*Unidad_t;
   end

  energy_origin_instant_individual(t,n,:) = step_energy_origin_individual(n,:);

    
end % AQUÍ ACABA LOOP POR PARTICIPANTE

for i=1:3
    energy_origin_instant(t,i) = sum(energy_origin_instant_individual(t,:,i));
end


acum = 0;
for z = 1:members
    acum = acum + (max_capacity * storage_allocation(z) * (SoC(t+1,z)/100));
end

SoC_energy_CER(t+1) = acum; 

daily_energy_origin(quarter_h,:) = daily_energy_origin(quarter_h,:) + sum(step_energy_origin_individual(:,:));

step_energy_origin = sum(step_energy_origin_individual(:,:));

total_energy_origin_individual(:,:)=total_energy_origin_individual(:,:) + step_energy_origin_individual(:,:);


% ch
[quarter_h,hour,week_day] = siguiente_ch(quarter_h,hour,week_day);


end

final_bill = -sum(step_profit);
SoC_pred=SoC;
total_energy_consumption_individual = sum(total_energy_origin_individual.');
total_energy_origin = sum(total_energy_origin_individual);
total_energy_consumption = sum(total_energy_origin);
for i=1:3
    percentage_energy_origin(i,1) = total_energy_origin(1,i)/total_energy_consumption;
end
for i=1:3
    for n=1:members
        total_energy_origin_individual(n,i) = total_energy_origin_individual(n,i)/total_energy_consumption_individual(1,n);
    end
end

%% 3. EC RULE-BASED REFERENCE MODEL


% --- Internal parameters ---
P_surplus=zeros(steps,members);
P_shortage=zeros(steps,members);
SoC=ones(steps+1,members)*0; % SoC inicial del 50% por poner algo
%Ef_charge=0.97;
%Ef_discharge=0.97;
step_profit_unoptimised=zeros(steps,members);
daily_energy_origin_unoptimised = zeros(24*4,3);
sold_energy_unoptimised = zeros(24*4,members);
step_energy_origin_unoptimised = zeros(steps,3);
total_energy_origin_individual_unoptimised=zeros(members,3);

% TESTING PURPOSES ONLY
hour = 1;
week_day = 1; % Mayo 2023 empieza lunes
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
[Pgen_real_allocated] = PV_power_allocation(Pgen_real, generation_allocation, factor_gen, CoR_type, members, week_day, hour); 

for t=1:steps
   
step_energy_origin_individual_unoptimised = zeros(members,3);

E_st_max=storage_allocation*max_capacity;
P_charge_max=storage_allocation*100;
P_discharge_max=storage_allocation*100;


    for n=1:members %EMPIEZA EL ALGORITMO

    P_charge_max(1,n)=min(P_charge_max(1,n)*Ef_charge,((100-SoC(t,n))/100)*E_st_max(1,n)*(1/time_unit));
    P_discharge_max(1,n)=min(P_discharge_max(1,n)*Ef_discharge,(SoC(t,n)/100)*E_st_max(1,n)*(1/time_unit));

      if Pgen_real_allocated(t,n)>Pcons_real(t,n)
           P_surplus(t,n)=Pgen_real_allocated(t,n)-Pcons_real(t,n);
           step_energy_origin_individual_unoptimised(n,1) = step_energy_origin_individual_unoptimised(n,1) + Pcons_real(t,n);%Unidad_t;
           if E_st_max(1,n)>0 && SoC(t,n)<100
               if P_surplus(t,n)<P_charge_max(1,n)
                   SoC(t+1,n)=SoC(t,n)+((P_surplus(t,n)*time_unit*Ef_charge)/E_st_max(1,n))*100;
               else
                   SoC(t+1,n)=SoC(t,n)+((P_charge_max(1,n)*time_unit)/E_st_max(1,n))*100;
                   sold_energy_unoptimised(quarter_h,n) = sold_energy_unoptimised(quarter_h,n) + (P_surplus(t,n)-P_charge_max(1,n)/Ef_charge)*time_unit;
                   step_profit_unoptimised(t,n)=step_profit_unoptimised(t,n)+(P_surplus(t,n)-P_charge_max(1,n)/Ef_charge)*time_unit*selling_price(t,1);
               end
           else
               step_profit_unoptimised(t,n)=step_profit_unoptimised(t,n)+P_surplus(t,n)*time_unit*selling_price(t,1);
               sold_energy_unoptimised(quarter_h,n) = sold_energy_unoptimised(quarter_h,n) + P_surplus(t,n)*time_unit;
               SoC(t+1,n)=SoC(t,n);
           end
       else
           P_shortage(t,n)=Pcons_real(t,n)-Pgen_real_allocated(t,n);
           step_energy_origin_individual_unoptimised(n,1) = step_energy_origin_individual_unoptimised(n,1) + Pgen_real_allocated(t,n);%Unidad_t
           if E_st_max(1,n)>0 && SoC(t,n)>0
               if P_shortage(t,n)<P_discharge_max(1,n)
                    SoC(t+1,n)=SoC(t,n)-(((P_shortage(t,n)*time_unit)/Ef_discharge)/E_st_max(1,n))*100;
                    step_energy_origin_individual_unoptimised(n,2) = step_energy_origin_individual_unoptimised(n,2) + P_shortage(t,n);%Unidad_t
               else
                    SoC(t+1,n)=SoC(t,n)-(((P_discharge_max(1,n)*time_unit)/Ef_discharge)/E_st_max(1,n))*100;
                    step_energy_origin_individual_unoptimised(n,2) = step_energy_origin_individual_unoptimised(n,2) + P_discharge_max(1,n);%Unidad_t
                    step_profit_unoptimised(t,n)= step_profit_unoptimised(t,n)-(P_shortage(t,n)-P_discharge_max(1,n))*time_unit*price_next_1h(t,1);
                    step_energy_origin_individual_unoptimised(n,3) = step_energy_origin_individual_unoptimised(n,3) + (P_shortage(t,n)-P_discharge_max(1,n));%Unidad_t
               end
           else
               step_profit_unoptimised(t,n)=step_profit_unoptimised(t,n)-P_shortage(t,n)*time_unit*price_next_1h(t,1);
               step_energy_origin_individual_unoptimised(n,3) = step_energy_origin_individual_unoptimised(n,3) + P_shortage(t,n);%Unidad_t
               SoC(t+1,n)=SoC(t,n);
           end
       end  
    end
    
    step_energy_origin_unoptimised(t,:) = sum(step_energy_origin_individual_unoptimised(:,:));

    [quarter_h,hour,week_day] = siguiente_ch(quarter_h,hour,week_day);
end

% Comparació balance optimitzant/sense optimitzar

final_bill_unoptimised = -sum(step_profit_unoptimised);

Y = categorical({'Optimización','Reglas estáticas'});
Y = reordercats(Y,{'Optimización','Reglas estáticas'});

total_final_bill = sum(final_bill);
total_final_bill_unoptimised = sum(final_bill_unoptimised);


%% 4. RESULTS: KPIs AND PLOTS

[ADR,POR,avg_days] = consumption_profile_metrics(Pcons_real);
[CBU, ADC, BCPD] = battery_metrics(SoC_energy_CER, max_capacity, days, steps);

% --- Plots ---
t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t = t1:minutes(15):t2;
t = t';

CE_SoC_signal = 100*SoC_energy_CER(1:672)/max_capacity;

Pcons_agg = zeros(steps,1);
for i = 1:steps
    Pcons_agg(i) = sum(Pcons_real(i,:));
end

figure(101)
plot(t(1:672), Pcons_agg(1:672), t(1:672), Pgen_real(1:672))
title('Aggregated power consumption vs aggregated power generation')
ylabel('Power [kW]')
xlabel('Time')
legend('Aggregated power consumption','Aggregated power generation')

figure(102)
bar(total_energy_origin_individual*100,'stacked')
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
