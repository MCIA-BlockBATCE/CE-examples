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

% aquí elegimos tipo de CoR
CoR_type = 0; % fixed allocation
% CoR_type = 1; % allocation based on the moment of the week (variable)
% CoR_type = 2; % allocation based on consumption of previous step (dynamic variable)

members=length(CER_excedentaria); % Numero de participantes

% FRECUENCIA HORARIA A CUARTOHORARIA
time_unit=0.25; % Tiempo entre ejecuciones (1h) HABRÁ QUE CAMBIAR A 0.25

load("..\..\_data\Pgen_real.mat")

% NOTA: Estas tablas NO contienen columnas de marca temporal separada dia,
% mes año, hora
% NOTA: Paso a potencia (kW) la magnitud de energía (kWh), multiplico por 4
% NOTA: aquí cargo TODOS los perfiles de consumo, y ya luego elegimos la
% comunidad

load("..\..\_data\energia_cons_CER.mat")

Pcons_real = energia_cons_CER(:,CER_excedentaria) * 4;

if CoR_type == 0
   
    tramos_mensuales(CER_excedentaria)
    [generation_allocation] = bbce2_calculo_coeficientes_estaticos();
    generation_allocation = sum(generation_allocation.'); %operacions per obtenir un CoR_bateria que no canvii durant el mes
    generation_allocation = generation_allocation/sum(generation_allocation); %operacions per obtenir un CoR_bateria estàtic que no canvii durant el mes
    storage_allocation=generation_allocation;

elseif CoR_type == 1

    tramos_mensuales(CER_excedentaria)
    [generation_allocation] = bbce2_calculo_coeficientes_estaticos();
    generation_allocation=generation_allocation(1:members,1:3);
    storage_allocation=generation_allocation(1:members,:);
    storage_allocation = sum(storage_allocation.'); %operacions per obtenir un CoR_bateria que no canvii durant el mes
    storage_allocation = storage_allocation/sum(storage_allocation); %operacions per obtenir un CoR_bateria estàtic que no canvii durant el mes

else 

    [generation_allocation] = bbce2_calculo_coeficientes_dinamicos(CER_excedentaria); 

    % Se usan CoR estaticos para repartir la bateria
    tramos_mensuales(CER_excedentaria)
    [storage_allocation] = bbce2_calculo_coeficientes_estaticos();
    storage_allocation = sum(storage_allocation.'); %operacions per obtenir un CoR_bateria que no canvii durant el mes
    storage_allocation = storage_allocation/sum(storage_allocation); %operacions per obtenir un CoR_bateria estàtic que no canvii durant el mes

end

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

%% Calculo balance economico sin optimizar

P_surplus=zeros(steps,members);
P_shortage=zeros(steps,members);

SoC=ones(steps+1,members)*0; % SoC inicial del 50% por poner algo
Ef_charge=0.97;
Ef_discharge=0.97;

step_profit=zeros(steps,members);

daily_energy_origin = zeros(24*4,3);

sold_energy = zeros(24*4,members);

step_energy_origin = zeros(steps,3);

total_energy_origin_individual=zeros(members,3);

% TESTING PURPOSES ONLY
hour = 1;
week_day = 1; % Mayo 2023 empieza lunes
quarter_h = 1;

if CoR_type == 0

    for n=1:members     
    
        Pgen_real_allocated(:,n) = Pgen_real * generation_allocation(1,n).'*factor_gen;

    end

end

if CoR_type == 2

    for n=1:members     
  
        Pgen_real_allocated(:,n) = generation_allocation(:,n).*Pgen_real*factor_gen;

    end
end


for t=1:steps
   
step_energy_origin_individual = zeros(members,3);

E_st_max=storage_allocation*max_capacity;
P_charge_max=storage_allocation*100;
P_discharge_max=storage_allocation*100;

if CoR_type == 1

    [X] = tramo_coef(week_day,hour);
    
    for n=1:members     

        Pgen_real_allocated(:,n) = Pgen_real * generation_allocation(n,X)*factor_gen;
    
    end
end

    for n=1:members %EMPIEZA EL ALGORITMO

    P_charge_max(1,n)=min(P_charge_max(1,n)*Ef_charge,((100-SoC(t,n))/100)*E_st_max(1,n)*(1/time_unit));
    P_discharge_max(1,n)=min(P_discharge_max(1,n)*Ef_discharge,(SoC(t,n)/100)*E_st_max(1,n)*(1/time_unit));

      if Pgen_real_allocated(t,n)>Pcons_real(t,n)
           P_surplus(t,n)=Pgen_real_allocated(t,n)-Pcons_real(t,n);
           step_energy_origin_individual(n,1) = step_energy_origin_individual(n,1) + Pcons_real(t,n);%Unidad_t;
           if E_st_max(1,n)>0 && SoC(t,n)<100
               if P_surplus(t,n)<P_charge_max(1,n)
                   SoC(t+1,n)=SoC(t,n)+((P_surplus(t,n)*time_unit*Ef_charge)/E_st_max(1,n))*100;
               else
                   SoC(t+1,n)=SoC(t,n)+((P_charge_max(1,n)*time_unit)/E_st_max(1,n))*100;
                   sold_energy(quarter_h,n) = sold_energy(quarter_h,n) + (P_surplus(t,n)-P_charge_max(1,n)/Ef_charge)*time_unit;
                   step_profit(t,n)=step_profit(t,n)+(P_surplus(t,n)-P_charge_max(1,n)/Ef_charge)*time_unit*selling_price(t,1);
               end
           else
               step_profit(t,n)=step_profit(t,n)+P_surplus(t,n)*time_unit*selling_price(t,1);
               sold_energy(quarter_h,n) = sold_energy(quarter_h,n) + P_surplus(t,n)*time_unit;
               SoC(t+1,n)=SoC(t,n);
           end
       else
           P_shortage(t,n)=Pcons_real(t,n)-Pgen_real_allocated(t,n);
           step_energy_origin_individual(n,1) = step_energy_origin_individual(n,1) + Pgen_real_allocated(t,n);%Unidad_t
           if E_st_max(1,n)>0 && SoC(t,n)>0
               if P_shortage(t,n)<P_discharge_max(1,n)
                    SoC(t+1,n)=SoC(t,n)-(((P_shortage(t,n)*time_unit)/Ef_discharge)/E_st_max(1,n))*100;
                    step_energy_origin_individual(n,2) = step_energy_origin_individual(n,2) + P_shortage(t,n);%Unidad_t
               else
                    SoC(t+1,n)=SoC(t,n)-(((P_discharge_max(1,n)*time_unit)/Ef_discharge)/E_st_max(1,n))*100;
                    step_energy_origin_individual(n,2) = step_energy_origin_individual(n,2) + P_discharge_max(1,n);%Unidad_t
                    step_profit(t,n)= step_profit(t,n)-(P_shortage(t,n)-P_discharge_max(1,n))*time_unit*price_next_1h(t,1);
                    step_energy_origin_individual(n,3) = step_energy_origin_individual(n,3) + (P_shortage(t,n)-P_discharge_max(1,n));%Unidad_t
               end
           else
               step_profit(t,n)=step_profit(t,n)-P_shortage(t,n)*time_unit*price_next_1h(t,1);
               step_energy_origin_individual(n,3) = step_energy_origin_individual(n,3) + P_shortage(t,n);%Unidad_t
               SoC(t+1,n)=SoC(t,n);
           end
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

total_final_bill = sum(final_bill);

%%

t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t = t1:minutes(15):t2;
t = t';

figure(19)
plot(t(1:672),100*SoC_energy_CER(1:672)/max_capacity)
title('Estado de carga (SoC) de la batería')
ylabel('SoC (%)')
xlabel('Tiempo')
ylim([0 100])

figure(20)
plot(t(1:672),energy_origin_instant(1:672,1),t(1:672),energy_origin_instant(1:672,2),t(1:672),energy_origin_instant(1:672,3))
title('Potencia consumida según origen')
legend('Origen placas','Origen batería','Origen red eléctrica')
ylabel('Potencia consumida (kW)')
xlabel('Tiempo')

figure(7)
bar(total_energy_origin_individual,'stacked')
legend('Origen placas','Origen batería','Origen red eléctrica')

