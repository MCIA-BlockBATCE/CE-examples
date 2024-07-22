clear all
close all

% Declaracion de variables y ejecución de funciones (Lecturas y predicciones)
% MES DE MAYO TIENE 2976 muestras = 4 cuartos * 24 hours * 31 días
days = 7;
steps = 24*4*days;

% aquí se acotaria la comunidad por ejemplo
CER_excedentaria = [4 7 8 10 12 13];
% CER_deficitaria = [x x x x x x]:
% CER_balanceada = [x x x x x x]:

members=length(CER_excedentaria); % Numero de participantes

% FRECUENCIA HORARIA A CUARTOHORARIA
time_unit=0.25; % Tiempo entre ejecuciones (1h) HABRÁ QUE CAMBIAR A 0.25

[generation_allocation] = bbce2_calculo_coeficientes_dinamicos(CER_excedentaria); 

% Se usan CoR estaticos para repartir la bateria
tramos_mensuales(CER_excedentaria)
[storage_allocation] = bbce2_calculo_coeficientes_estaticos();

load("..\..\_data\Pgen_real.mat")
load("..\..\_data\Pgen_real_3h.mat")

% NOTA: Estas tablas NO contienen columnas de marca temporal separada dia,
% mes año, hour
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


%% Caso con datos reales

daily_energy_origin = zeros(24*4,3);
total_energy_origin_individual = zeros(members,3);
step_profit=zeros(steps,members);
energy_origin_instant=zeros(steps,3);
energy_origin_instant_individual=zeros(steps,members,3);

for n=1:members     
    Pgen_pred_1h_allocated(:,n) = generation_allocation(:,n).*Pgen_pred_1h*factor_gen;
    Pgen_pred_3h_allocated(:,n) = generation_allocation(:,n).*Pgen_pred_3h*factor_gen; 
    
    Pgen_real_allocated(:,n) = generation_allocation(:,n).*Pgen_real*factor_gen;

end

for t=1:steps % EMPIEZA EL AÑO

E_st_max=storage_allocation*max_capacity;
P_charge_max=storage_allocation*100;
P_discharge_max=storage_allocation*100;

step_energy_origin_individual = zeros(members,3);

% Consumir o no de la batería?
Decision2(t,1) = DecisionBateria(Pcons_pred_3h(t,:),Pcons_pred_1h(t,:),Pgen_pred_3h_allocated(t,:), ...
    Pgen_pred_1h_allocated(t,:),price_next_1h(t,1),price_next_3h(t,1),price_next_6h(t,1));

for n=1:members %EMPIEZA EL ALGORITMO

   Decision1(t,n) = AlmacenarVenderConsumirColectivo(price_next_1h(t,1),selling_price(t,1),Decision2(t,1));
   % La salida de la función sería un entero entre 0 i 2
   % 0 vender, 1 consumir y 2 almacenar

   if Decision1(t,n)==0 
% Venta de toda la potencia generada: 

% Se empieza encontrando el máximo que se puede extraer de la bateria (se
% escoge el mínimo entre la potencia max. de descarga de la batería y el
% 50% del SoC)
       P_discharge_max(n)=min(P_discharge_max(n)/Ef_discharge,((SoC(t,n)*0.25)/100)*E_st_max(n));
% Si hay energia en la batería y la energía a consumir es menor o igual que la
% energía máxima que se puede extraer, se evalúa si utilizarla (DecisionBateria()).
% Al no extraer la energía justa para cada usuario (bateria colectiva), se
% vende el resto.
       if E_st_max(n)>0 && SoC(t,n)>0
           if Pcons_real(t,n)<P_discharge_max(n)
               if Decision2(t,1)==1
                   SoC(t+1,n)=(SoC(t,n)*3)/4;
                   step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+Pcons_real(t,n);
                   step_profit(t,n)=step_profit(t,n)+(P_discharge_max(n)/Ef_discharge-Pcons_real(t,n))*price_next_1h(t,1);
               end
               if Decision2(t,1)==0
                   step_profit(t,n)=step_profit(t,n)-Pcons_real(t,n)*time_unit*price_next_1h(t,1);
                   step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+Pcons_real(t,n);
                   SoC(t+1,n)=SoC(t,n);
               end
% Si hay energia en la batería y la energía a consumir es mayor a la energia
% máxima que se puede extraer, se evalúa si extraer igualmente (DecisionBateria()).
% El resto de la potencia se compra de la red eléctrica.
           else
               if Decision2(t,1)==1
                   SoC(t+1,n)=(SoC(t,n)*3)/4;
                   step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+P_discharge_max(n)*Ef_discharge;
                   step_profit(t,n)=step_profit(t,n)-(Pcons_real(t,n)-P_discharge_max(n)*Ef_discharge)*time_unit*price_next_1h(t,1);
                   step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+(Pcons_real(t,n)-P_discharge_max(n)*Ef_discharge);
               end
               if Decision2(t,1)==0
                  step_profit(t,n)=step_profit(t,n)-Pcons_real(t,n)*time_unit*price_next_1h(t,1);
                  step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+Pcons_real(t,n);
                  SoC(t+1,n)=SoC(t,n);
               end
           end 
       else
           step_profit(t,n)=step_profit(t,n)-Pcons_real(t,n)*time_unit*price_next_1h(t,1);
           step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+Pcons_real(t,n);
       end
% Se vende finalmente la energía generada
      step_profit(t,n)=step_profit(t,n)+Pgen_real_allocated(t,n)*time_unit*selling_price(t,1);
       
   elseif Decision1(t,n)==1
% Consumo de la energía generada

% Se empieza encontrando el máximo que se puede extraer de la bateria (se
% escoge el mínimo entre la potencia max. de descarga de la batería y el
% 50% del SoC)
       P_discharge_max(n)=min(P_discharge_max(n)/Ef_discharge,((SoC(t,n)*0.25)/100)*E_st_max(n));
% En caso de decidir extraer energía de la bat., si la energía generada es
% mayor a la consumida, se vende tanto el excedente como la energia
% extraida de la bateria. Si la energía generada no es mayor que la
% consumida, se consume lo necesario del 50% extraído y se vende el resto.
       if Decision2(t,1)==1
           if Pgen_real_allocated(t,n)>Pcons_real(t,n)
               step_energy_origin_individual(n,1)=step_energy_origin_individual(n,1)+Pcons_real(t,n);
               SoC(t+1,n)=(SoC(t,n)*3)/4;
               step_profit(t,n)=step_profit(t,n)+(Pgen_real_allocated(t,n)-Pcons_real(t,n)+P_discharge_max(n)*Ef_discharge)*selling_price(t,1);
           else
               P_shortage(t,n)=Pcons_real(t,n)-Pgen_real_allocated(t,n);
               step_energy_origin_individual(n,1)=step_energy_origin_individual(n,1)+Pgen_real_allocated(t,n);
               if P_shortage(t,n)<P_discharge_max(n)*Ef_discharge
                   SoC(t+1,n)=(SoC(t,n)*3)/4;
                   step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+P_shortage(t,n);
                   step_profit(t,n)=step_profit(t,n)+(P_discharge_max(n)*Ef_discharge-P_shortage(t,n))*selling_price(t,1);
               else
                   SoC(t+1,n)=(SoC(t,n)*3)/4;
                   step_energy_origin_individual(n,2)=step_energy_origin_individual(n,2)+P_discharge_max(n)*Ef_discharge;
                   step_profit(t,n)= step_profit(t,n)-(P_shortage(t,n)-P_discharge_max(n)*Ef_discharge)*time_unit*price_next_1h(t,1);
                   step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+(P_shortage(t,n)-P_discharge_max(n)*Ef_discharge);
               end
           end
       end
% En caso de decidir NO extraer energía de la bat., si hay excedente éste
% se vende y si hay escasez se compra.
       if Decision2(t,1)==0
           if Pgen_real_allocated(t,n)>Pcons_real(t,n)
               step_energy_origin_individual(n,1)=step_energy_origin_individual(n,1)+Pcons_real(t,n);
               SoC(t+1,n)=SoC(t,n);
               step_profit(t,n)=step_profit(t,n)+(Pgen_real_allocated(t,n)-Pcons_real(t,n))*selling_price(t,1);
           else
               SoC(t+1,n)=SoC(t,n);
               step_energy_origin_individual(n,1)=step_energy_origin_individual(n,1)+Pgen_real_allocated(t,n);
               step_profit(t,n)= step_profit(t,n)-(Pcons_real(t,n)-Pgen_real_allocated(t,n))*price_next_1h(t,1);
               step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+(Pcons_real(t,n)-Pgen_real_allocated(t,n));
           end
       end
% En caso de almacenar, se guarda un tercio de lo generado (no sabemos con
% exactitud el excedente, decision colectiva por el tipo de batería). Si
% tras el almacenamiento aún hay excedente, éste se vende. Si hay escasez
% se debe comprar de la red.
   else % Decision1=2
       P_charge_max(n)=min(P_charge_max(n)*Ef_charge,((100-SoC(t,n))/100)*E_st_max(n));
       if (Pgen_real_allocated(t,n)*0.33)<P_charge_max(n) %emmagatzemem un terç de la generacio
           SoC(t+1,n)=SoC(t,n)+(((Pgen_real_allocated(t,n)*0.33)*time_unit*Ef_charge)/E_st_max(n))*100;
       else
           SoC(t+1,n)=SoC(t,n)+(P_charge_max(n)*time_unit)/E_st_max(n)*100;
           step_profit(t,n)=step_profit(t,n)+((Pgen_real_allocated(t,n)*0.33)-P_charge_max(n)/Ef_charge)*time_unit*selling_price(t,1);
       end
       
       if Pgen_real_allocated(t,n)*0.67 < Pcons_real(t,n)
            step_energy_origin_individual(n,1)=step_energy_origin_individual(n,1)+Pgen_real_allocated(t,n)*0.67;
            step_profit(t,n)=step_profit(t,n)-(Pcons_real(t,n)-Pgen_real_allocated(t,n)*0.67)*price_next_1h(t,1);
            step_energy_origin_individual(n,3)=step_energy_origin_individual(n,3)+(Pcons_real(t,n)-Pgen_real_allocated(t,n)*0.67);
       else
            step_energy_origin_individual(n,1)=step_energy_origin_individual(n,1)+Pcons_real(t,n); 
            step_profit(t,n)=step_profit(t,n)+(Pgen_real_allocated(t,n)*0.67-Pcons_real(t,n))*selling_price(t,1);
       end
            
   end

   energy_origin_instant_individual(t,n,:) = step_energy_origin_individual(n,:);

end

for i=1:3
    energy_origin_instant(t,i) = sum(energy_origin_instant_individual(t,:,i));
end

acum = 0;
for z = 1:members
    acum = acum + (max_capacity * storage_allocation(z) * (SoC(t+1,z)/100));
end

SoC_energy_CER(t+1) = acum; 

daily_energy_origin(quarter_h,:) = daily_energy_origin(quarter_h,:) + sum(step_energy_origin_individual(:,:));
 
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


%% Calculo balance economico sin optimizar
% IN THIS CASE, UNOPTIMISED = NO BATTERY

P_surplus=zeros(steps,members);
P_shortage=zeros(steps,members);

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


for t=1:steps
    
step_energy_origin_individual_unoptimised = zeros(members,3);

[X] = tramo_coef(week_day,hour);

for n=1:members  
    Pgen_real_allocated(:,n) = Pgen_real * generation_allocation(n,X) * factor_gen;
end

for n=1:members %EMPIEZA EL ALGORITMO

      if Pgen_real_allocated(t,n)>Pcons_real(t,n)
           P_surplus(t,n)=Pgen_real_allocated(t,n)-Pcons_real(t,n);
           step_energy_origin_individual_unoptimised(n,1) = step_energy_origin_individual_unoptimised(n,1) + Pcons_real(t,n);
           step_profit_unoptimised(t,n)=step_profit_unoptimised(t,n)+P_surplus(t,n)*time_unit*selling_price(t,1);
           sold_energy_unoptimised(hour,n) = sold_energy_unoptimised(hour,n) + P_surplus(t,n);
       else
           P_shortage(t,n)=Pcons_real(t,n)-Pgen_real_allocated(t,n);
           step_energy_origin_individual_unoptimised(n,1) = step_energy_origin_individual_unoptimised(n,1) + Pgen_real_allocated(t,n);
           step_profit_unoptimised(t,n)=step_profit_unoptimised(t,n)-P_shortage(t,n)*time_unit*price_next_1h(t,1);
           step_energy_origin_individual_unoptimised(n,3) = step_energy_origin_individual_unoptimised(n,3) + P_shortage(t,n);
      end  
end

total_energy_origin_individual_unoptimised(:,:)=total_energy_origin_individual_unoptimised(:,:) + step_energy_origin_individual_unoptimised(:,:);

[quarter_h,hour,week_day] = siguiente_ch(quarter_h,hour,week_day);

end

% Comparació balance optimitzant/sense optimitzar

final_bill_unoptimised = -sum(step_profit_unoptimised);

total_energy_consumption_individual_unoptimised = sum(total_energy_origin_individual_unoptimised.');

Y = categorical({'Optimización','Reglas estáticas'});
Y = reordercats(Y,{'Optimización','Reglas estáticas'});

for i=1:3
    for n=1:members
        total_energy_origin_individual_unoptimised(n,i) = total_energy_origin_individual_unoptimised(n,i)/total_energy_consumption_individual_unoptimised(1,n);
    end
end

total_final_bill = sum(final_bill);
total_final_bill_unoptimised = sum(final_bill_unoptimised);

%% socs

% SoC_real_total = sum((SoC_real.*CoR_bateria).');
% SoC_noOpt_total = sum((SoC_noOpt.*CoR_bateria).');
% hour=1;
% dia_setmana = 5;
% SoC_real_total_hourri=zeros(24,1);
% SoC_noOpt_total_hourri=zeros(24,1);
% for t=1:744
%     SoC_real_total_hourri(hour,1)=SoC_real_total_hourri(hour,1) + SoC_real_total(1,t);
%     SoC_noOpt_total_hourri(hour,1)=SoC_noOpt_total_hourri(hour,1) + SoC_noOpt_total(1,t);
%     [quarter_h,hour,week_day] = siguiente_ch(quarter_h,hour,week_day);
% end
% SoC_real_total_hourri(:,1) = SoC_real_total_hourri(:,1)/31;
% SoC_noOpt_total_hourri(:,1) = SoC_noOpt_total_hourri(:,1)/31;
% 
% SoC_real_total_hourri(:,1) = (SoC_real_total_hourri(:,1)/100) * 15;
% SoC_noOpt_total_hourri(:,1) = (SoC_noOpt_total_hourri(:,1)/100) * 15;

%%
figure(1)
bar(total_energy_origin_individual,'stacked')
legend('Origen placas','Origen batería','Origen red eléctrica')


figure(2)
bar(Y,[total_final_bill total_final_bill_unoptimised])
title("Facturación agregada de la comunidad (semanal)")
ylabel('Euros (€)')

t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t = t1:minutes(15):t2;
t = t';

figure(3)
plot(t(1:672),energy_origin_instant(1:672,1),t(1:672),energy_origin_instant(1:672,2),t(1:672),energy_origin_instant(1:672,3))
title('Potencia consumida según origen')
legend('Origen placas','Origen batería','Origen red eléctrica')
ylabel('Potencia consumida (kW)')
xlabel('Tiempo')

