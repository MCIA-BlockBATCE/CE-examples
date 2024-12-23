clear all
close all

% Declaracion de variables y ejecución de funciones (Lecturas y predicciones)
% MES DE MAYO TIENE 2976 muestras = 4 cuartos * 24 horas * 31 días
days = 7;
steps = 24*4*days;

% aquí se acotaria la comunidad por ejemplo
CER_excedentaria = [4 7 8 10 12 13];
% CER_deficitaria = [x x x x x x]:
% CER_balanceada = [x x x x x x]:

members=length(CER_excedentaria); % Numero de participantes

% FRECUENCIA HORARIA A CUARTOHORARIA
time_unit=0.25; % Tiempo entre ejecuciones (1h) HABRÁ QUE CAMBIAR A 0.25

tramos_mensuales(CER_excedentaria)
[generation_allocation] = bbce2_calculo_coeficientes_estaticos();

load("..\..\_data\Pgen_real.mat")
load("..\..\_data\Pgen_real_3h.mat")

% NOTA: Estas tablas NO contienen columnas de marca temporal separada dia,
% mes año, hora
% NOTA: Paso a potencia (kW) la magnitud de energía (kWh), multiplico por 4
% NOTA: aquí cargo TODOS los perfiles de consumo, y ya luego elegimos la
% comunidad
load("..\..\_data\energia_cons_CER.mat")
load("..\..\_data\energia_cons_CER_3h.mat")

Pcons_real = energia_cons_CER(:,CER_excedentaria) * 4;
Pcons_real_3h = energia_cons_CER_3h(:,CER_excedentaria) * 4;

% NOTA: Fórmula Osterwald da como output potencia (kW)
load("..\..\_data\Pgen_pred_1h.mat")
load("..\..\_data\Pgen_pred_3h.mat")

% Carguem prediccions ANFIS
load("..\..\_data\Pcons_pred_1h.mat")
load("..\..\_data\Pcons_pred_3h.mat")

% Passem a potencia
Pcons_pred_1h = 4 * Pcons_pred_1h(:,CER_excedentaria);
Pcons_pred_3h = 4 * Pcons_pred_3h(:,CER_excedentaria);

generation_allocation=generation_allocation(1:members,1:3);
storage_allocation=generation_allocation(1:members,:);
storage_allocation = sum(storage_allocation.'); %operacions per obtenir un CoR_bateria que no canvii durant el mes
storage_allocation = storage_allocation/sum(storage_allocation); %operacions per obtenir un CoR_bateria estàtic que no canvii durant el mes

P_surplus=zeros(steps,members);
P_shortage=zeros(steps,members);

SoC=ones(steps+1,members)*0; % SoC inicial

% Parámetros batería
Ef_charge=0.97;
Ef_discharge=0.97;
max_capacity=200;
factor_gen = 1;

selling_price=0.07 * ones(steps,1);

load("..\..\_data\buying_prices.mat");

% TESTING PURPOSES ONLY
hour = 1;
week_day = 1; % Mayo 2023 empieza lunes
quarter_h = 1;

% OFERTA 1 (TARDE VIERNES)
% FristFriSample = 385 (slot de 0:00 a 0:15)
% LastFriSample = 481 (slot de 23:45 a 0:00)
instante_oferta = 470; %(22:00 a 22:15 del viernes)
% instante_oferta = 385 + 4*10; % 7:00
% cantidad_oferta = 180;
cantidad_oferta = 0;

% OFERTA 2 (MAÑANA MARTES)
instante_oferta_2 = 226-88; % (slot 9:15 a 9:30 del martes)
% cantidad_oferta_2 = 200*0.97;
cantidad_oferta_2 = 0;
coste_energia_comprada_mientras_oferta = 0;
SoC_energy_CER = zeros(length(SoC),1);


%% Caso con datos reales

daily_energy_origin = zeros(24*4,3);
total_energy_origin_individual = zeros(members,3);

% USO DE ENERGÍA DE GENERACIÓN
total_energy_decision_individual = zeros(members, 5);
% col 1 = vender red
% col 2 = consumir placas
% col 3 = consumir bat
% col 4 = vender p2p
% col 5 = vender mercado (interop)

step_profit=zeros(steps,members);
energy_origin_instant=zeros(steps,3);
energy_origin_instant_individual=zeros(steps,members,3);

for t=1:steps % EMPIEZA EL AÑO

E_st_max=storage_allocation*max_capacity;
P_charge_max=storage_allocation*100;
P_discharge_max=storage_allocation*100;

step_energy_origin_individual = zeros(members,3);
step_energy_decision_individual = zeros(members,5);

[X] = tramo_coef(week_day,hour);

for n=1:members     
    Pgen_pred_1h_allocated(:,n) = Pgen_pred_1h * generation_allocation(n,X)*factor_gen;
    Pgen_pred_3h_allocated(:,n) = Pgen_pred_3h * generation_allocation(n,X)*factor_gen; 
    
    Pgen_real_allocated(:,n) = Pgen_real * generation_allocation(n,X)*factor_gen;

end

for n=1:members %EMPIEZA EL ALGORITMO

   if ( (t >= instante_oferta - 20) && t < instante_oferta + 4 )
       [Dec1, P_discharge_max_oferta] = AlmacenarVenderConsumirAlternatiu_oferta(SoC_energy_CER(t),cantidad_oferta,t,instante_oferta,Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                     Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),selling_price(t,1),price_next_3h(t,1),SoC(t,n),price_next_6h(t,1),P_discharge_max(1,n));
       Decision1(t,n) = Dec1;
       caso_oferta = 1;
       % La salida de la función sería un entero entre 0 i 2?
       % 0 vender, 1 consumir y 2 almacenar

   elseif ( (t >= instante_oferta_2 - 20) && (t < instante_oferta_2 + 4) )
       [Dec1, P_discharge_max_oferta] = AlmacenarVenderConsumirAlternatiu_oferta(SoC_energy_CER(t),cantidad_oferta_2,t,instante_oferta_2,Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                     Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),selling_price(t,1),price_next_3h(t,1),SoC(t,n),price_next_6h(t,1),P_discharge_max(1,n));
       Decision1(t,n) = Dec1;
       caso_oferta = 2;
       % La salida de la función sería un entero entre 0 i 2?
       % 0 vender, 1 consumir y 2 almacenar

   else
       
       Decision1(t,n) = AlmacenarVenderConsumirAlternatiu(Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                     Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),selling_price(t,1),price_next_3h(t,1),SoC(t,n),price_next_6h(t,1),E_st_max(1,n));
       caso_oferta = 0;
       % La salida de la función sería un entero entre 0 i 2?
       % 0 vender, 1 consumir y 2 almacenar
   end


% Se decide vender la energía generada y a continuación se evalúa para los
% distintos casos si deberíamos o no extraer energía de la batería para
% consumir. En caso de usar la batería, no se extrae más de lo que se vaya
% a consumir (batería individual, sabemos las necesidades de cada uno). En
% cualquier caso se compra la energía que nos falte de la red. 
   if Decision1(t,n)==0
       if (caso_oferta == 1) P_discharge_max(1,n) = P_discharge_max_oferta; end
       
       P_discharge_max(1,n)=min(P_discharge_max(1,n)*Ef_discharge,(SoC(t,n)/100)*E_st_max(1,n)*(1/time_unit));
  
       if E_st_max(1,n)>0 && SoC(t,n)>0
           if Pcons_real(t,n)<P_discharge_max(1,n)
               Decision2(t,n) = ConsumirBatAlternatiu(Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
               % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
               if Decision2(t,n)==1
                   SoC(t+1,n)=SoC(t,n)-(((Pcons_real(t,n)*time_unit)/Ef_discharge)/E_st_max(1,n))*100;
                   step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+Pcons_real(t,n);%*Unidad_t;
                   step_energy_decision_individual(n,3) = Pcons_real(t,n); % consumida batería
               else
                   step_profit(t,n)=step_profit(t,n)-Pcons_real(t,n)*time_unit*price_next_1h(t,1);
                   step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+Pcons_real(t,n);%*Unidad_t;
                   SoC(t+1,n)=SoC(t,n);
               end
           else
               Decision2(t,n) = ConsumirBatAlternatiu(Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
               % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
               if Decision2(t,n)==1
                   SoC(t+1,n)=SoC(t,n)-((P_discharge_max(1,n)*time_unit)/E_st_max(1,n))*100;
                   step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+P_discharge_max(1,n)*Ef_discharge;%*Unidad_t;
                   step_profit(t,n)=step_profit(t,n)-(Pcons_real(t,n)-P_discharge_max(1,n)*Ef_discharge)*time_unit*price_next_1h(t,1);
                   step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+(Pcons_real(t,n)-P_discharge_max(1,n)*Ef_discharge);%*Unidad_t;
                   step_energy_decision_individual(n,3) = Pcons_real(t,n)-P_discharge_max(1,n)*Ef_discharge; % consumida batería
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
      
      step_energy_decision_individual(n,1) = Pgen_real_allocated(t,n); % vendida red 

% Se decide consumir la energía consumida. En caso de déficit se evalua si
% usar la batería y se compra la energía que falte. En caso de superávit se
% almacena toda la posible y se vende el resto.

   elseif Decision1(t,n)==1
       if (caso_oferta == 1) P_discharge_max(1,n) = P_discharge_max_oferta; end
       
       P_charge_max(1,n)=min(P_charge_max(1,n)*Ef_charge,((100-SoC(t,n))/100)*E_st_max(1,n)*(1/time_unit));
       P_discharge_max(1,n)=min(P_discharge_max(1,n)*Ef_discharge,(SoC(t,n)/100)*E_st_max(1,n)*(1/time_unit));
       step_energy_decision_individual(n,2) = Pgen_real_allocated(t,n);

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
                   Decision2(t,n) = ConsumirBatAlternatiu(Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
               
                   % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                   if Decision2(t,n) == 1
                       SoC(t+1,n)=SoC(t,n)-(((P_shortage(t,n)*time_unit)/Ef_discharge)/E_st_max(1,n))*100;
                       step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+P_shortage(t,n);%*Unidad_t;
                       step_energy_decision_individual(n,3) = P_shortage(t,n);
                   else
                       step_profit(t,n)=step_profit(t,n)-P_shortage(t,n)*time_unit*price_next_1h(t,1);
                       step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+P_shortage(t,n);%*Unidad_t;
                       SoC(t+1,n)=SoC(t,n);
                   end
               else
                   Decision2(t,n) = ConsumirBatAlternatiu(Pcons_pred_3h(t,n),Pcons_pred_1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                    Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1),SoC_energy_CER(t));
                   % Salida es 0 o 1, donde 1 es usar la bateria y 0 no usarla
                   if Decision2(t,n) == 1
                        SoC(t+1,n)=SoC(t,n)-((P_discharge_max(1,n)*time_unit)/E_st_max(1,n))*100;
                        step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+P_discharge_max(1,n);%*Unidad_t; %*Ef_discharge
                        step_profit(t,n)= step_profit(t,n)-(P_shortage(t,n)-P_discharge_max(1,n))*time_unit*price_next_1h(t,1); %*Ef_discharge
                        step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+(P_shortage(t,n)-P_discharge_max(1,n));%*Unidad_t; %*Ef_discharge
                        step_energy_decision_individual(n,3) = P_shortage(t,n)-P_discharge_max(1,n);
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

   % Descargo en 4 instantes de tiempo los 120 kW, a 30kWh equivalentes
   % cada cuarto de hora
    if(t==instante_oferta || t==instante_oferta+1 || t==instante_oferta+2 || t==instante_oferta+3)
        energia_a_vender_de_bat = storage_allocation * cantidad_oferta/4;
        step_energy_decision_individual(n,5) = storage_allocation(n) * cantidad_oferta/4;
        energia_SoC_anterior = max_capacity * storage_allocation(n) * (SoC(t,n)/100);
        energia_SoC_actual = energia_SoC_anterior - energia_a_vender_de_bat(n);
        SoC(t+1,n) = 100* energia_SoC_actual/(storage_allocation(n)*max_capacity);

        
    end

    if(t==instante_oferta_2 || t==instante_oferta_2+1 || t==instante_oferta_2+2 || t==instante_oferta_2+3)
        energia_a_vender_de_bat = storage_allocation * cantidad_oferta_2/4;
        step_energy_decision_individual(n,5) = storage_allocation(n) * cantidad_oferta_2/4; % vendida mercado (interop) 
        step_energy_decision_individual(n,4) = 2; % fake mercado p2p
        energia_SoC_anterior = max_capacity * storage_allocation(n) * (SoC(t,n)/100);
        energia_SoC_actual = energia_SoC_anterior - energia_a_vender_de_bat(n);
        SoC(t+1,n) = 100* energia_SoC_actual/(storage_allocation(n)*max_capacity);
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

if(t==instante_oferta || t==instante_oferta+1 || t==instante_oferta+2 || t==instante_oferta+3)
    coste_energia_comprada_mientras_oferta = coste_energia_comprada_mientras_oferta + (step_energy_origin(1,3) * price_next_1h(t));
end

total_energy_origin_individual(:,:)=total_energy_origin_individual(:,:) + step_energy_origin_individual(:,:);
total_energy_decision_individual(:,:)=total_energy_decision_individual(:,:) + step_energy_decision_individual(:,:);


% ch
[quarter_h,hour,week_day] = siguiente_ch(quarter_h,hour,week_day);


end

final_bill = -sum(step_profit);
SoC_pred=SoC;
total_energy_consumption_individual = sum(total_energy_origin_individual.');
total_energy_generation_invidual = sum(total_energy_decision_individual.');

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

for i=1:5
    for n=1:members
        total_energy_decision_individual(n,i) = total_energy_decision_individual(n,i)/total_energy_generation_invidual(1,n);
    end
end

%% Calculo balance economico sin optimizar

P_surplus=zeros(steps,members);
P_shortage=zeros(steps,members);

SoC=ones(steps+1,members)*0; % SoC inicial del 50% por poner algo
Ef_charge=0.97;
Ef_discharge=0.97;

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


for t=1:steps
   
step_energy_origin_individual_unoptimised = zeros(members,3);

E_st_max=storage_allocation*max_capacity;
P_charge_max=storage_allocation*100;
P_discharge_max=storage_allocation*100;


[X] = tramo_coef(week_day,hour);

for n=1:members  
    Pgen_real_allocated(:,n) = Pgen_real * generation_allocation(n,X) * factor_gen;
end


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


%%


% col 1 = vender red
% col 2 = consumir
% col 3 = vender p2p
% col 4 = vender mercado (interop)

% figure(17)
% bar(Y,[total_final_bill total_final_bill_unoptimised])
% title("Facturación agregada de la comunidad (semanal)")
% ylabel('Euros (€)')



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

% figure(20)
% plot(t(1:672),energy_origin_instant(1:672,1),t(1:672),energy_origin_instant(1:672,2),t(1:672),energy_origin_instant(1:672,3))
% title('Potencia consumida según origen')
% legend('Origen placas','Origen batería','Origen red eléctrica')
% ylabel('Potencia consumida (kW)')
% xlabel('Tiempo')
% yyaxis right
% plot(t(1:672), Pgen_real(1:672))

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


%% METRICAS DISPERSIÓN

% Cálculo de día promedio
avg_days = zeros(96,members);

% Primeras 672 muestras de mayo
day = 1;
for j = 1:members
    
    q = 1;
    for i=1:672
        avg_days(q,j) = avg_days(q,j) + Pcons_real(i,j); 
        q = q + 1;
        if q == 97
            q = 1;
        end
    end
end

% Cálculo de métrica de proximidad de máximos y tasa de consumo basal
for j = 1:members

    aux = max(avg_days(:,j));
    [x,y] = find(avg_days(:,j)==aux);
    max_part(1,j) = x;
    mean_part(1,j) = mean(avg_days(:,j));
    %mean_newcons(1,j) = mean(new_CER_Day(:,j));

end

max_part = sort(max_part);
mean_part = sort(mean_part);
POR = 0;
ADR = 0;

for j = 1:members-1
    POR = POR + (max_part(j+1)-max_part(j));
    ADR = ADR + (mean_part(j+1)-mean_part(j));
end

maxD = 95;

POR = 100*(1-(POR/maxD));

% TODO: Cálculo de méctricas SoC (ciclos acumulados, promedio de ciclos por día,
% usabilidad)

CE_SoC_signal = 100*SoC_energy_CER(1:672)/max_capacity;
AUR_low = zeros(days,1);
AUR_high = zeros(days,1); 
grad_zero_counts = 0;
CBC = 0;

q = 1;
day = 1;
for j = 1:steps
    %
    if j>1
        CBC = CBC + abs((CE_SoC_signal(j) - CE_SoC_signal(j-1))); 
    end

    if j>1 && j<steps
        if (CE_SoC_signal(j-1) > CE_SoC_signal(j)) && (CE_SoC_signal(j+1) > CE_SoC_signal(j))
            % it's a min
            grad_zero_counts = grad_zero_counts + 1; 
        elseif (CE_SoC_signal(j-1) < CE_SoC_signal(j)) && (CE_SoC_signal(j+1) < CE_SoC_signal(j))
            % it's a max
            grad_zero_counts = grad_zero_counts + 1; 
        end
    end

    q = q + 1;
    if q == 97
        firstIndex = ((day-1)*96)+1;
        lastIndex = day*96;
        AUR_low(day) = min(CE_SoC_signal(firstIndex:lastIndex));
        AUR_high(day) = max(CE_SoC_signal(firstIndex:lastIndex));
        q = 1;
        day = day + 1;
    end
end

CBU = CBC/100;
AUR = zeros(2,1);
AUR(1) = mean(AUR_low);
AUR(2) = mean(AUR_high);
%BCPD = grad_zero_counts/days;
BCPD = (CBU/2)/days;

% TODO: Crear datos sintéticos?

%% GRÁFICOS
t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t = t1:minutes(15):t2;
t = t';

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
title("Battery State of Charge (SoC), AUR: [" + num2str(AUR(1), '%05.2f') + ", " ...
    + num2str(AUR(2), '%05.2f') + "] [%], CBC: " + num2str(CBU, '%05.2f') + ", BCPD: " ...
    + num2str(BCPD, '%05.2f'))
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
title("Average-day power consumption for each CE member, POR: " + num2str(POR, '%05.2f') ...
    + "[%], ADR: " + num2str(ADR, '%05.2f') + "[kW]")
xlim([1 96])
ylabel('Power [kW]')
xlabel('Time, in quarters')
% dim = [0.15 0.5 0.5 0.4];
% str = {'POR' POR, 'ADR' ADR};
% annotation('textbox',dim,'String',str,'FitBoxToText','on');
