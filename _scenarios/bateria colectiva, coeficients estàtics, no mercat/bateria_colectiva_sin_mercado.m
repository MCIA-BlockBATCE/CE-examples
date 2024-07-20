% capacidad=[1 2 3 4 5 7 10 15 20 30 40 50];
% for iter=1:12

capacidad=[200];
for iter=1:1

% Declaracion de variables y ejecución de funciones (Lecturas y predicciones)
n=8; % Numero de participantes
Unidad_t=1; % Tiempo entre ejecuciones (1h)

%CoR_generacion=readmatrix("Coeficients_Tramos_igualat.xlsx");
%CoR_bateria=readmatrix("Coeficients_Tramos_igualat.xlsx");
CoR_generacion=readmatrix("Coeficients_Tramos_tardes.xlsx");

Pgen_pred1h=readmatrix("PrediccioProduccioGener_1h.xlsx");
Pgen_pred3h=readmatrix("PrediccioProduccioGener_3h.xlsx");
Pcons_pred_1h=readmatrix("Prediccio_consum_gener_1h.xlsx"); %Caso prediccion perfecta
Pcons_pred_3h=readmatrix("Prediccio_consum_gener_3h.xlsx"); %Caso prediccion perfecta
origen_potencia_CasoPerfecto = zeros(n,3); %1 es placas, 2 bateria y 3 comprada

CoR_generacion=CoR_generacion(1:8,2:4);
CoR_bateria=CoR_generacion;

Pcons_pred_1h=[Pcons_pred_1h(1:744,2) Pcons_pred_1h(1:744,4) Pcons_pred_1h(1:744,9:14)]; %Cas tardes
Pcons_pred_3h=[Pcons_pred_3h(1:744,2) Pcons_pred_3h(1:744,4) Pcons_pred_3h(1:744,9:14)]; %Cas tardes
%Pcons_pred_1h=Pcons_pred_1h(1:744,1:8); %Cas igualat
%Pcons_pred_3h=Pcons_pred_3h(1:744,1:8); %Cas igualat
Pgen_pred1h=Pgen_pred1h(1:744,1);
Pgen_pred3h=Pgen_pred3h(1:744,1);

Pexd=zeros(744,n);
Pfal=zeros(744,n);

SoC=ones(744+1,n)*50; % SoC inicial del 50% por poner algo
Ef_charge=0.97;
Ef_discharge=0.97;
Nciclos=0; 

Precio_venta=rand(744,1)*0.05+0.075;
Precio_compra = readmatrix("Preus2022.xlsx");
Precio_compra = Precio_compra/1000;
Balance_dinero_pred=zeros(744,n);
Precio_compra_3h = readmatrix("Preus2022_3h.xlsx");
Precio_compra_3h = Precio_compra_3h/1000;
Precio_compra_6h = readmatrix("Preus2022_6h.xlsx");
Precio_compra_6h = Precio_compra_6h/1000;

dia_setmana=5; %L'any va començar en divendres
hora=1; %anirà del 0 al 23, començam a la 1:00 l'array

origen_sumatorio_pred = zeros(24,3);

total_origen_porcentual_CasoPerfecto = zeros(8,3);


%% Calculo prediccion balance economico 

for t=1:744 % EMPIEZA EL AÑO

origen_potencia_CasoPerfecto = zeros(8,3);

     if (dia_setmana>0 && dia_setmana<6)
          if (hora>=0 && hora<8)
             X=1;
          end
            
          if (hora>=8 && hora<10)||(hora>=14 && hora<18)||(hora>=22 && hora<24)
             X=2;
          end

          if (hora>=10 && hora<14)||(hora>=18 && hora<22)
             X=3;
          end
      else
          X=1;
     end
     
E_st_max=CoR_bateria(:,X)*capacidad(1,iter);
P_charge_max=CoR_bateria(:,X)*81;
P_discharge_max=CoR_bateria(:,X)*81;

for n=1:8     
    
    Pgen_pred1h_comunidad(:,n) = Pgen_pred1h * CoR_generacion(n,X);
    Pgen_pred3h_comunidad(:,n) = Pgen_pred3h * CoR_generacion(n,X); 

end

% Consumir o no de la batería?
Decision2(t,1) = DecisionBateria(Pcons_pred_3h(t,:),Pcons_pred_1h(t,:),Pgen_pred3h_comunidad(t,:), ...
    Pgen_pred1h_comunidad(t,:),Precio_compra(t,1),Precio_compra_3h(t,1),Precio_compra_6h(t,1));


for n=1:8 %EMPIEZA EL ALGORITMO

   Decision1(t,n) = AlmacenarVenderConsumirColectivo(Precio_compra(t,1),Precio_venta(t,1),Decision2(t,1));
   % La salida de la función sería un entero entre 0 i 2
   % 0 vender, 1 consumir y 2 almacenar

   if Decision1(t,n)==0 
% Venta de toda la potencia generada: 

% Se empieza encontrando el máximo que se puede extraer de la bateria (se
% escoge el mínimo entre la potencia max. de descarga de la batería y el
% 50% del SoC)
       P_discharge_max(n,1)=min(P_discharge_max(n,1)/Ef_discharge,((SoC(t,n)*0.5)/100)*E_st_max(n,1));
% Si hay energia en la batería y la energía a consumir es menor o igual que la
% energía máxima que se puede extraer, se evalúa si utilizarla (DecisionBateria()).
% Al no extraer la energía justa para cada usuario (bateria colectiva), se
% vende el resto.
       if E_st_max(n,1)>0 && SoC(t,n)>0
           if Pcons_pred_1h(t,n)<P_discharge_max(n,1)
               if Decision2(t,1)==1
                   SoC(t+1,n)=SoC(t,n)/2;
                   origen_potencia_CasoPerfecto(n,2)=origen_potencia_CasoPerfecto(n,2)+Pcons_pred_1h(t,n);
                   Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)+(P_discharge_max(n,1)/Ef_discharge-Pcons_pred_1h(t,n))*Precio_compra(t,1);
               end
               if Decision2(t,1)==0
                   Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)-Pcons_pred_1h(t,n)*Unidad_t*Precio_compra(t,1);
                   origen_potencia_CasoPerfecto(n,3)=origen_potencia_CasoPerfecto(n,3)+Pcons_pred_1h(t,n);
                   SoC(t+1,n)=SoC(t,n);
               end
% Si hay energia en la batería y la energía a consumir es mayor a la energia
% máxima que se puede extraer, se evalúa si extraer igualmente (DecisionBateria()).
% El resto de la potencia se compra de la red eléctrica.
           else
               if Decision2(t,1)==1
                   SoC(t+1,n)=SoC(t,n)/2;
                   origen_potencia_CasoPerfecto(n,2)=origen_potencia_CasoPerfecto(n,2)+P_discharge_max(n,1)*Ef_discharge;
                   Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)-(Pcons_pred_1h(t,n)-P_discharge_max(n,1)*Ef_discharge)*Unidad_t*Precio_compra(t,1);
                   origen_potencia_CasoPerfecto(n,3)=origen_potencia_CasoPerfecto(n,3)+(Pcons_pred_1h(t,n)-P_discharge_max(n,1)*Ef_discharge);
               end
               if Decision2(t,1)==0
                  Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)-Pcons_pred_1h(t,n)*Unidad_t*Precio_compra(t,1);
                  origen_potencia_CasoPerfecto(n,3)=origen_potencia_CasoPerfecto(n,3)+Pcons_pred_1h(t,n);
                  SoC(t+1,n)=SoC(t,n);
               end
           end 
       else
           Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)-Pcons_pred_1h(t,n)*Unidad_t*Precio_compra(t,1);
           origen_potencia_CasoPerfecto(n,3)=origen_potencia_CasoPerfecto(n,3)+Pcons_pred_1h(t,n);
       end
% Se vende finalmente la energía generada
      Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)+Pgen_pred1h_comunidad(t,n)*Unidad_t*Precio_venta(t,1);
       
   elseif Decision1(t,n)==1
% Consumo de la energía generada

% Se empieza encontrando el máximo que se puede extraer de la bateria (se
% escoge el mínimo entre la potencia max. de descarga de la batería y el
% 50% del SoC)
       P_discharge_max(n,1)=min(P_discharge_max(n,1)/Ef_discharge,((SoC(t,n)*0.5)/100)*E_st_max(n,1));
% En caso de decidir extraer energía de la bat., si la energía generada es
% mayor a la consumida, se vende tanto el excedente como la energia
% extraida de la bateria. Si la energía generada no es mayor que la
% consumida, se consume lo necesario del 50% extraído y se vende el resto.
       if Decision2(t,1)==1
           if Pgen_pred1h_comunidad(t,n)>Pcons_pred_1h(t,n)
               origen_potencia_CasoPerfecto(n,1)=origen_potencia_CasoPerfecto(n,1)+Pcons_pred_1h(t,n);
               SoC(t+1,n)=SoC(t,n)/2;
               Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)+(Pgen_pred1h_comunidad(t,n)-Pcons_pred_1h(t,n)+P_discharge_max(n,1)*Ef_discharge)*Precio_venta(t,1);
           else
               Pfal(t,n)=Pcons_pred_1h(t,n)-Pgen_pred1h_comunidad(t,n);
               origen_potencia_CasoPerfecto(n,1)=origen_potencia_CasoPerfecto(n,1)+Pgen_pred1h_comunidad(t,n);
               if Pfal(t,n)<P_discharge_max(n,1)*Ef_discharge
                   SoC(t+1,n)=SoC(t,n)/2;
                   origen_potencia_CasoPerfecto(n,2)=origen_potencia_CasoPerfecto(n,2)+Pfal(t,n);
                   Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)+(P_discharge_max(n,1)*Ef_discharge-Pfal(t,n))*Precio_venta(t,1);
               else
                   SoC(t+1,n)=SoC(t,n)/2;
                   origen_potencia_CasoPerfecto(n,2)=origen_potencia_CasoPerfecto(n,2)+P_discharge_max(n,1)*Ef_discharge;
                   Balance_dinero_pred(t,n)= Balance_dinero_pred(t,n)-(Pfal(t,n)-P_discharge_max(n,1)*Ef_discharge)*Unidad_t*Precio_compra(t,1);
                   origen_potencia_CasoPerfecto(n,3)=origen_potencia_CasoPerfecto(n,3)+(Pfal(t,n)-P_discharge_max(n,1)*Ef_discharge);
               end
           end
       end
% En caso de decidir NO extraer energía de la bat., si hay excedente éste
% se vende y si hay escasez se compra.
       if Decision2(t,1)==0
           if Pgen_pred1h_comunidad(t,n)>Pcons_pred_1h(t,n)
               origen_potencia_CasoPerfecto(n,1)=origen_potencia_CasoPerfecto(n,1)+Pcons_pred_1h(t,n);
               SoC(t+1,n)=SoC(t,n);
               Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)+(Pgen_pred1h_comunidad(t,n)-Pcons_pred_1h(t,n))*Precio_venta(t,1);
           else
               SoC(t+1,n)=SoC(t,n);
               origen_potencia_CasoPerfecto(n,1)=origen_potencia_CasoPerfecto(n,1)+Pgen_pred1h_comunidad(t,n);
               Balance_dinero_pred(t,n)= Balance_dinero_pred(t,n)-(Pcons_pred_1h(t,n)-Pgen_pred1h_comunidad(t,n))*Precio_compra(t,1);
               origen_potencia_CasoPerfecto(n,3)=origen_potencia_CasoPerfecto(n,3)+(Pcons_pred_1h(t,n)-Pgen_pred1h_comunidad(t,n));
           end
       end
% En caso de almacenar, se guarda un tercio de lo generado (no sabemos con
% exactitud el excedente, decision colectiva por el tipo de batería). Si
% tras el almacenamiento aún hay excedente, éste se vende. Si hay escasez
% se debe comprar de la red.
   else % Decision1=2
       P_charge_max(n,1)=min(P_charge_max(n,1)*Ef_charge,((100-SoC(t,n))/100)*E_st_max(n,1));
       if (Pgen_pred1h_comunidad(t,n)*0.33)<P_charge_max(n,1) %emmagatzemem un terç de la generacio
           SoC(t+1,n)=SoC(t,n)+(((Pgen_pred1h_comunidad(t,n)*0.33)*Unidad_t*Ef_charge)/E_st_max(n,1))*100;
       else
           SoC(t+1,n)=SoC(t,n)+(P_charge_max(n,1)*Unidad_t)/E_st_max(n,1)*100;
           Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)+((Pgen_pred1h_comunidad(t,n)*0.33)-P_charge_max(n,1)/Ef_charge)*Unidad_t*Precio_venta(t,1);
       end
       
       if Pgen_pred1h_comunidad(t,n)*0.67 < Pcons_pred_1h(t,n)
            origen_potencia_CasoPerfecto(n,1)=origen_potencia_CasoPerfecto(n,1)+Pgen_pred1h_comunidad(t,n)*0.67;
            Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)-(Pcons_pred_1h(t,n)-Pgen_pred1h_comunidad(t,n)*0.67)*Precio_compra(t,1);
            origen_potencia_CasoPerfecto(n,3)=origen_potencia_CasoPerfecto(n,3)+(Pcons_pred_1h(t,n)-Pgen_pred1h_comunidad(t,n)*0.67);
       else
            origen_potencia_CasoPerfecto(n,1)=origen_potencia_CasoPerfecto(n,1)+Pcons_pred_1h(t,n); 
            Balance_dinero_pred(t,n)=Balance_dinero_pred(t,n)+(Pgen_pred1h_comunidad(t,n)*0.67-Pcons_pred_1h(t,n))*Precio_venta(t,1);
       end
            
   end
end

origen_sumatorio_pred(hora,:) = origen_sumatorio_pred(hora,:) + sum(origen_potencia_CasoPerfecto(:,:));


total_origen_porcentual_CasoPerfecto(:,:)=total_origen_porcentual_CasoPerfecto(:,:) + origen_potencia_CasoPerfecto(:,:);


[hora,dia_setmana] = siguiente_hora(hora,dia_setmana);

end

Balance_anual_prediccion = sum(Balance_dinero_pred);
SoC_pred=SoC;
consums_totals_CasoPerfecto = sum(total_origen_porcentual_CasoPerfecto.');
origen_potencia_comunitat_CasoPerfecto = sum(total_origen_porcentual_CasoPerfecto);
consums_totals_comunitat_CasoPerfecto = sum(origen_potencia_comunitat_CasoPerfecto);
for i=1:3
    origen_porcentual_comunitat_CasoPerfecto(i,1) = origen_potencia_comunitat_CasoPerfecto(1,i)/consums_totals_comunitat_CasoPerfecto;
end
for i=1:3
    for n=1:8
        total_origen_porcentual_CasoPerfecto(n,i) = total_origen_porcentual_CasoPerfecto(n,i)/consums_totals_CasoPerfecto(1,n);
    end
end

origen_sumatorio_pred(:,:) = origen_sumatorio_pred(:,:)/31;


%% Calculo balance economico real

%reinicializacion de variables
n=8; % Numero de participantes
Unidad_t=1; % Tiempo entre ejecuciones (1h)

%CoR_generacion=readmatrix("Coeficients_Tramos_igualat.xlsx");
%CoR_bateria=readmatrix("Coeficients_Tramos_igualat.xlsx");
CoR_generacion=readmatrix("Coeficients_Tramos_tardes.xlsx");

Pgen_real=readmatrix("Produccio12mesos_1h.xlsx");
Pcons_real=readmatrix("Consumos Participantes.xlsx");
origen_potencia_CasoReal = zeros(n,3);

CoR_generacion=CoR_generacion(1:8,2:4);
CoR_bateria=CoR_generacion;



Pcons_real=[Pcons_real(8761:9504,3) Pcons_real(8761:9504,5) Pcons_real(8761:9504,10:15)]; %Cas tardes
%Pcons_real=Pcons_real(8761:9504,2:9); %Cas igualat
Pgen_real=Pgen_real(1:744,1);
Pexd=zeros(744,n);
Pfal=zeros(744,n);

SoC=ones(744+1,n)*50; % SoC inicial del 50% por poner algo
Ef_charge=0.97;
Ef_discharge=0.97;
Nciclos=0; 

Precio_compra = readmatrix("Preus2022.xlsx");
Precio_compra = Precio_compra/1000;
Balance_dinero=zeros(744,n);
Precio_compra_3h = readmatrix("Preus2022_promig3h.xlsx");
Precio_compra_3h = Precio_compra_3h/1000;

dia_setmana=6; %L'any va començar en divendres
hora=1; %anirà del 0 al 23, començam a la 1:00 l'array

origen_sumatorio_real = zeros(24,3);

total_origen_porcentual_CasoReal = zeros(8,3);

P_sold_real = zeros (24,8);


for t=1:744 % EMPIEZA EL AÑO

origen_potencia_CasoReal = zeros(8,3);

[X] = tramo_coef(dia_setmana,hora);

E_st_max=CoR_bateria(:,X)*capacidad(1,iter);;
P_charge_max=CoR_bateria(:,X)*81;
P_discharge_max=CoR_bateria(:,X)*81;
     
for n=1:8     
    Pgen_real_comunidad(:,n) = Pgen_real * CoR_generacion(n,X);
end


for n=1:8 %EMPIEZA EL ALGORITMO 

   if Decision1(t,n)==0
       P_discharge_max(n,1)=min(P_discharge_max(n,1)/Ef_discharge,((SoC(t,n)*0.5)/100)*E_st_max(n,1));
       if E_st_max(n,1)>0 && SoC(t,n)>0
           if Pcons_real(t,n)<P_discharge_max(n,1)
               if Decision2(t,1)==1
                   SoC(t+1,n)=SoC(t,n)/2;
                   origen_potencia_CasoReal(n,2)=origen_potencia_CasoReal(n,2)+Pcons_real(t,n);
                   Balance_dinero(t,n)=Balance_dinero(t,n)+(P_discharge_max(n,1)*Ef_discharge-Pcons_real(t,n))*Precio_compra(t,1);
                   P_sold_real(hora,n) = P_sold_real(hora,n) + (P_discharge_max(n,1)*Ef_discharge-Pcons_real(t,n));
               end
               if Decision2(t,1)==0
                   Balance_dinero(t,n)=Balance_dinero(t,n)-Pcons_real(t,n)*Unidad_t*Precio_compra(t,1);
                   origen_potencia_CasoReal(n,3)=origen_potencia_CasoReal(n,3)+Pcons_real(t,n);
                   SoC(t+1,n)=SoC(t,n);
               end
           else
               if Decision2(t,1)==1
                   SoC(t+1,n)=SoC(t,n)/2;
                   origen_potencia_CasoReal(n,2)=origen_potencia_CasoReal(n,2)+P_discharge_max(n,1)*Ef_discharge;
                   Balance_dinero(t,n)=Balance_dinero(t,n)-(Pcons_real(t,n)-P_discharge_max(n,1)*Ef_discharge)*Unidad_t*Precio_compra(t,1);
                   origen_potencia_CasoReal(n,3)=origen_potencia_CasoReal(n,3)+(Pcons_real(t,n)-P_discharge_max(n,1)*Ef_discharge);
               end
               if Decision2(t,1)==0
                  Balance_dinero(t,n)=Balance_dinero(t,n)-Pcons_real(t,n)*Unidad_t*Precio_compra(t,1);
                  origen_potencia_CasoReal(n,3)=origen_potencia_CasoReal(n,3)+Pcons_real(t,n);
                  SoC(t+1,n)=SoC(t,n);
               end
           end 
       else
           Balance_dinero(t,n)=Balance_dinero(t,n)-Pcons_real(t,n)*Unidad_t*Precio_compra(t,1);
           origen_potencia_CasoReal(n,3)=origen_potencia_CasoReal(n,3)+Pcons_real(t,n);
       end
       Balance_dinero(t,n)=Balance_dinero(t,n)+Pgen_real_comunidad(t,n)*Unidad_t*Precio_venta(t,1);
       P_sold_real(hora,n) = P_sold_real(hora,n) + Pgen_real_comunidad(t,n);
       
   elseif Decision1(t,n)==1
       P_discharge_max(n,1)=min(P_discharge_max(n,1)/Ef_discharge,((SoC(t,n)*0.5)/100)*E_st_max(n,1));
       if Decision2(t,1)==1
           if Pgen_real_comunidad(t,n)>Pcons_real(t,n)
               origen_potencia_CasoReal(n,1)=origen_potencia_CasoReal(n,1)+Pcons_real(t,n);
               SoC(t+1,n)=SoC(t,n)/2;
               Balance_dinero(t,n)=Balance_dinero(t,n)+(Pgen_real_comunidad(t,n)-Pcons_real(t,n)+P_discharge_max(n,1)*Ef_discharge)*Precio_venta(t,1);
               P_sold_real(hora,n) = P_sold_real(hora,n) + (Pgen_real_comunidad(t,n)-Pcons_real(t,n)+P_discharge_max(n,1)*Ef_discharge);
           else
               Pfal(t,n)=Pcons_real(t,n)-Pgen_real_comunidad(t,n);
               origen_potencia_CasoReal(n,1)=origen_potencia_CasoReal(n,1)+Pgen_real_comunidad(t,n);
               if Pfal(t,n)<P_discharge_max(n,1)*Ef_discharge
                   SoC(t+1,n)=SoC(t,n)/2;
                   origen_potencia_CasoReal(n,2)=origen_potencia_CasoReal(n,2)+Pfal(t,n);
                   Balance_dinero(t,n)=Balance_dinero(t,n)+(P_discharge_max(n,1)*Ef_discharge-Pfal(t,n))*Precio_venta(t,1);
                   P_sold_real(hora,n) = P_sold_real(hora,n) + (P_discharge_max(n,1)*Ef_discharge-Pfal(t,n));
               else
                   SoC(t+1,n)=SoC(t,n)/2;
                   origen_potencia_CasoReal(n,2)=origen_potencia_CasoReal(n,2)+P_discharge_max(n,1)*Ef_discharge;
                   Balance_dinero(t,n)= Balance_dinero(t,n)-(Pfal(t,n)-P_discharge_max(n,1)*Ef_discharge)*Unidad_t*Precio_compra(t,1);
                   origen_potencia_CasoReal(n,3)=origen_potencia_CasoReal(n,3)+(Pfal(t,n)-P_discharge_max(n,1)*Ef_discharge);
               end
           end
       end
       if Decision2(t,1)==0
           if Pgen_real_comunidad(t,n)>Pcons_real(t,n)
               origen_potencia_CasoReal(n,1)=origen_potencia_CasoReal(n,1)+Pcons_real(t,n);
               SoC(t+1,n)=SoC(t,n);
               Balance_dinero(t,n)=Balance_dinero(t,n)+(Pgen_real_comunidad(t,n)-Pcons_real(t,n))*Precio_venta(t,1);
               P_sold_real(hora,n) = P_sold_real(hora,n) + (Pgen_real_comunidad(t,n)-Pcons_real(t,n));
           else
               SoC(t+1,n)=SoC(t,n);
               origen_potencia_CasoReal(n,1)=origen_potencia_CasoReal(n,1)+Pgen_real_comunidad(t,n);
               Balance_dinero(t,n)= Balance_dinero(t,n)-(Pcons_real(t,n)-Pgen_real_comunidad(t,n))*Precio_compra(t,1);
               origen_potencia_CasoReal(n,3)=origen_potencia_CasoReal(n,3)+(Pcons_real(t,n)-Pgen_real_comunidad(t,n));
           end
       end

   else % Decision1=2
       P_charge_max(n,1)=min(P_charge_max(n,1)*Ef_charge,((100-SoC(t,n))/100)*E_st_max(n,1));
       if (Pgen_real_comunidad(t,n)*0.3)<P_charge_max(n,1) %emmagatzemem un terç de la generacio
           SoC(t+1,n)=SoC(t,n)+(((Pgen_real_comunidad(t,n)*0.3)*Unidad_t*Ef_charge)/E_st_max(n,1))*100;
       else
           SoC(t+1,n)=SoC(t,n)+(P_charge_max(n,1)*Unidad_t)/E_st_max(n,1)*100;
           Balance_dinero(t,n)=Balance_dinero(t,n)+((Pgen_real_comunidad(t,n)*0.3)-P_charge_max(n,1)/Ef_charge)*Unidad_t*Precio_venta(t,1);
       end
       
       if Pgen_real_comunidad(t,n)*0.7 < Pcons_real(t,n)
            origen_potencia_CasoReal(n,1)=origen_potencia_CasoReal(n,1)+Pgen_real_comunidad(t,n)*0.7;
            Balance_dinero(t,n)=Balance_dinero(t,n)-(Pcons_real(t,n)-Pgen_real_comunidad(t,n)*0.7)*Precio_compra(t,1);
            origen_potencia_CasoReal(n,3)=origen_potencia_CasoReal(n,3)+(Pcons_real(t,n)-Pgen_real_comunidad(t,n)*0.7);
       else
            origen_potencia_CasoReal(n,1)=origen_potencia_CasoReal(n,1)+Pcons_real(t,n); 
            Balance_dinero(t,n)=Balance_dinero(t,n)+(Pgen_real_comunidad(t,n)*0.7-Pcons_real(t,n))*Precio_venta(t,1);
            P_sold_real(hora,n) = P_sold_real(hora,n) + (Pgen_real_comunidad(t,n)*0.7-Pcons_real(t,n));

       end
   end
end

origen_sumatorio_real(hora,:) = origen_sumatorio_real(hora,:) + sum(origen_potencia_CasoReal(:,:));


total_origen_porcentual_CasoReal(:,:)=total_origen_porcentual_CasoReal(:,:) + origen_potencia_CasoReal(:,:);


[hora,dia_setmana] = siguiente_hora(hora,dia_setmana);

end

Balance_anual_real = sum(Balance_dinero);
SoC_real=SoC;
consums_totals_CasoReal = sum(total_origen_porcentual_CasoReal.');
origen_potencia_comunitat_CasoReal = sum(total_origen_porcentual_CasoReal);
consums_totals_comunitat_CasoReal = sum(origen_potencia_comunitat_CasoReal);
for i=1:3
    origen_porcentual_comunitat_CasoReal(i,1) = origen_potencia_comunitat_CasoReal(1,i)/consums_totals_comunitat_CasoReal;
end
for i=1:3
    for n=1:8
        total_origen_porcentual_CasoReal(n,i) = total_origen_porcentual_CasoReal(n,i)/consums_totals_CasoReal(1,n);
        origen_pot_comunidad_porBat_colectiva(iter,i) = sum(total_origen_porcentual_CasoReal(:,i));

    end
end

origen_sumatorio_real(:,:) = origen_sumatorio_real(:,:)/31;

consumo_energia_bat(1,iter) = origen_potencia_comunitat_CasoReal(1,2);


%% Calculo balance economico sin optimizar

%reinicializacion de variables
n=8; % Numero de participantes
Unidad_t=1; % Tiempo entre ejecuciones (1h)

%CoR_generacion=readmatrix("Coeficients_Tramos_igualat.xlsx");
%CoR_bateria=readmatrix("Coeficients_Tramos_igualat.xlsx");
CoR_generacion=readmatrix("Coeficients_Tramos_tardes.xlsx");
CoR_bateria=readmatrix("Coeficients_Tramos_tardes.xlsx");

Pgen_real=readmatrix("Produccio12mesos_1h.xlsx");
Pcons_real=readmatrix("Consumos Participantes.xlsx");
origen_potencia_NoOptimo = zeros(n,3);

CoR_generacion=CoR_generacion(1:8,2:4);
CoR_bateria=CoR_bateria(1:8,2:4);
CoR_bateria = sum(CoR_bateria.'); %operacions per obtenir un CoR_bateria que no canvii durant el mes
CoR_bateria = CoR_bateria/sum(CoR_bateria); %operacions per obtenir un CoR_bateria estàtic que no canvii durant el mes
Pcons_real=[Pcons_real(8761:9504,3) Pcons_real(8761:9504,5) Pcons_real(8761:9504,10:15)]; %Cas tardes
%Pcons_real=Pcons_real(8761:9504,2:9); %Cas igualat
Pgen_real=Pgen_real(1:744,1);

Pexd=zeros(744,n);
Pfal=zeros(744,n);

SoC=ones(744+1,n)*0; % SoC inicial del 50% por poner algo
Ef_charge=0.97;
Ef_discharge=0.97;
Nciclos=0; 

Precio_compra = readmatrix("Preus2022.xlsx");
Precio_compra = Precio_compra/1000;
Balance_dinero_no_optim=zeros(744,n);
Precio_compra_3h = readmatrix("Preus2022_promig3h.xlsx");
Precio_compra_3h = Precio_compra_3h/1000;

dia_setmana=6; %L'any va començar en divendres
hora=1; %anirà del 0 al 23, començam a la 1:00 l'array

origen_sumatorio_NoOptimo = zeros(24,3);

P_sold_noOpt = zeros(24,8);

total_origen_porcentual_NoOptimo = zeros(8,3);

for t=1:744
    
origen_potencia_NoOptimo=zeros(8,3);

[X] = tramo_coef(dia_setmana,hora);

for n=1:8     
    Pgen_real_comunidad(:,n) = Pgen_real * CoR_generacion(n,X);
end

for n=1:8 %EMPIEZA EL ALGORITMO

      if Pgen_real_comunidad(t,n)>Pcons_real(t,n)
           Pexd(t,n)=Pgen_real_comunidad(t,n)-Pcons_real(t,n);
           origen_potencia_NoOptimo(n,1) = origen_potencia_NoOptimo(n,1) + Pcons_real(t,n);
           Balance_dinero_no_optim(t,n)=Balance_dinero_no_optim(t,n)+Pexd(t,n)*Unidad_t*Precio_venta(t,1);
           P_sold_noOpt(hora,n) = P_sold_noOpt(hora,n) + Pexd(t,n);
       else
           Pfal(t,n)=Pcons_real(t,n)-Pgen_real_comunidad(t,n);
           origen_potencia_NoOptimo(n,1) = origen_potencia_NoOptimo(n,1) + Pgen_real_comunidad(t,n);
           Balance_dinero_no_optim(t,n)=Balance_dinero_no_optim(t,n)-Pfal(t,n)*Unidad_t*Precio_compra(t,1);
           origen_potencia_NoOptimo(n,3) = origen_potencia_NoOptimo(n,3) + Pfal(t,n);
       end  
end

origen_sumatorio_NoOptimo(hora,:) = origen_sumatorio_NoOptimo(hora,:) + sum(origen_potencia_NoOptimo(:,:));

total_origen_porcentual_NoOptimo(:,:) = total_origen_porcentual_NoOptimo(:,:) + origen_potencia_NoOptimo(:,:);

[hora,dia_setmana] = siguiente_hora(hora,dia_setmana);


end

Balance_anual_no_optim = sum(Balance_dinero_no_optim);
SoC_noOpt= SoC;
consums_totals_noOpt = sum(total_origen_porcentual_NoOptimo.');
origen_potencia_comunitat_NoOptimo = sum(total_origen_porcentual_NoOptimo);
consums_totals_comunitat_NoOptimo = sum(origen_potencia_comunitat_NoOptimo);
for i=1:3
    origen_porcentual_comunitat_NoOptimo(i,1) = origen_potencia_comunitat_NoOptimo(1,i)/consums_totals_comunitat_NoOptimo;
end
origen_porcentual_comunitat_NoOptimo(4,1) = 0; 


for i=1:3
    for n=1:8
        total_origen_porcentual_NoOptimo(n,i) = total_origen_porcentual_NoOptimo(n,i)/consums_totals_noOpt(1,n);
    end
end

origen_sumatorio_NoOptimo(:,:) = origen_sumatorio_NoOptimo(:,:)/31;

%% 
Balance_dinero_no_autoconsumo = zeros(744,8);
Pcons_real=readmatrix("Consumos Participantes.xlsx");

Pcons_real=[Pcons_real(8761:9504,3) Pcons_real(8761:9504,5) Pcons_real(8761:9504,10:15)]; %Cas tardes
%Pcons_real=Pcons_real(8761:9504,2:9); %Cas igualat

Precio_compra = readmatrix("Preus2022.xlsx");
Precio_compra = Precio_compra/1000;

for t=1:744
    for n=1:8
        Balance_dinero_no_autoconsumo(t,n)=-Pcons_real(t,n)*Precio_compra(t,1);
    end
end

Balance_anual_no_autoconsum = sum(Balance_dinero_no_autoconsumo);

%% socs

SoC_real_total = sum((SoC_real.*CoR_bateria).');
SoC_noOpt_total = sum((SoC_noOpt.*CoR_bateria).');
hora=1;
dia_setmana = 5;
SoC_real_total_horari=zeros(24,1);
SoC_noOpt_total_horari=zeros(24,1);
for t=1:744
    SoC_real_total_horari(hora,1)=SoC_real_total_horari(hora,1) + SoC_real_total(1,t);
    SoC_noOpt_total_horari(hora,1)=SoC_noOpt_total_horari(hora,1) + SoC_noOpt_total(1,t);
    [hora,dia_setmana] = siguiente_hora(hora,dia_setmana);
end
SoC_real_total_horari(:,1) = SoC_real_total_horari(:,1)/31;
SoC_noOpt_total_horari(:,1) = SoC_noOpt_total_horari(:,1)/31;

SoC_real_total_horari(:,1) = (SoC_real_total_horari(:,1)/100) * 15;
SoC_noOpt_total_horari(:,1) = (SoC_noOpt_total_horari(:,1)/100) * 15;

%% Psold

P_sold_real = sum(P_sold_real.')/31;
P_sold_noOpt = sum(P_sold_noOpt.')/31;
%%
figure(1)
tiledlayout(2,1)

X = categorical({'R2','COM','SIN5','SIN6','SIN7','SIN8','SIN9','SIN10'});
X = reordercats(X,{'R2','COM','SIN5','SIN6','SIN7','SIN8','SIN9','SIN10'});

nexttile
bar(X,total_origen_porcentual_CasoReal*100,'stacked')
title('Desglose del consumo mensual por participante, con batería colectiva')
legend('Origen placas','Origen batería','Origen red eléctrica')
ylabel('%')
ylim([0 100])

nexttile
bar(X,total_origen_porcentual_NoOptimo*100,'stacked')
title('Desglose del consumo mensual por participante, sin bateria')
legend('Origen placas','Origen batería','Origen red eléctrica')
ylabel('%')
ylim([0 100])


balance_coef_estatics_participant = -Balance_anual_real;

Balance_anual_individuals_2models = [-Balance_anual_real.' -Balance_anual_no_optim.'];

Y = categorical({'Bateria col·lectiva','Sense bateria'});
Y = reordercats(Y,{'Bateria col·lectiva','Sense bateria'});

figure(2)
Balance_anual_totals = sum(Balance_anual_individuals_2models);
bar(Y,Balance_anual_totals)
title("Facturació mensual de la comunitat")
ylabel('Euros (€)')

figure(3)
tiledlayout(2,1)

nexttile

plot([1:24],origen_sumatorio_real(:,1),'b',[1:24],origen_sumatorio_real(:,2),'r',[1:24],origen_sumatorio_real(:,3),	"c",[1:24],P_sold_real,'g',[1:24],SoC_real_total_horari(:,1),'k')
ylabel('Energía (kWh)')
xlim([1 24])
ylim([0 12])
legend('Consumo placas','Consumo batería','Consumo red eléctrica','Energía vendida','Energíaa almacenada en la bateria')
title("Consumo diario de la comunidad, batería colectiva")

nexttile
plot([1:24],origen_sumatorio_NoOptimo(:,1),'b',[1:24],origen_sumatorio_NoOptimo(:,3),"c",[1:24],P_sold_noOpt,'g',[1:24],SoC_noOpt_total_horari(:,1),'k')
ylabel('Energía (kWh)')
xlim([1 24])
ylim([0 12])
legend('Consumo placas','Consumo red eléctrica','Energía vendida','Energía almacenada en la bateria')
title("Consumo diario de la comunidad, sin batería")

balance_bat_colectiva_sin_mercado = sum(-Balance_anual_real);
origen_porcentual_bat_colectiva_sin = total_origen_porcentual_CasoReal;

end

