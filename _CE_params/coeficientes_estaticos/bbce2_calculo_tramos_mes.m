clear all
close all


load('..\..\_data\base_data_2023.mat') 

%% Selección de columnas y llenado de vacíos con IL

num_participantes = 13;
data = base_data_2023(:,[[2:13] 17]);


%% Promedio horario consumos
data_agg = get_hourly_energy(data);

%% Completo información horaria correspondiente a cada fila

dias_meses = [31,28,31,30,31,30,31,31,30,31,30,31];
dia = 1;
mes = 1;
anyo = 2023;
hora = 0;
last_i = 1;
% Nueva tabla con la información temporal, que luego se usará para añadir
% nuevas columnas a la tabla data_agg
time_table = zeros(length(data_agg),4);
time_table(1,:) = [dia mes anyo hora];

for i = 2:length(data_agg)
    % Si no se acaba el día y tampoco se acaba el mes
    if dia <= dias_meses(mes) && hora <= 22
        hora = hora + 1;
    % Si se acaba el día pero no se acaba el mes
    elseif dia < dias_meses(mes) && hora > 22
        hora = 0;
        dia = dia + 1;
    % Si se acaba el mes y el día
    elseif dia >= dias_meses(mes) && hora > 22
        hora = 0;
        dia = 1;
        mes = mes + 1;
    end
    time_table(i,:) = [dia mes anyo hora];
end

data_agg_with_time = [data_agg time_table];

% Linea comentada para guardar tabla maestra de timestamp desagregado
% save("..\..\Datos originales Infraestructuras\time_table_2023.mat","time_table");


%% Inicialización de variables temporales y acumulados a 0
% Datos van de domingo 1/1/23 a 1/1/24
dia_setmana=7; % año 2023 empieza en domingo
hora=0; % va de 0 a 23
mes=1; % va de 1 a 10

suma_mes_valle=zeros(13,12);
suma_mes_llano=zeros(13,12);
suma_mes_pico=zeros(13,12);

%% Cálculos

for n=1:num_participantes
    for i=1:length(data_agg_with_time)
        if (mes~=data_agg_with_time(i,15))
            numindex=2+(mes-1)*15+(n-1);
            strindex=int2str(numindex);
            indexValle=strcat('B',strindex);
            indexLlano=strcat('C',strindex);
            indexPico=strcat('D',strindex);
            writematrix(suma_mes_valle(n,mes),'bbce2_Factures_ficticies.xlsx','Sheet','Hoja1','Range',indexValle);
            writematrix(suma_mes_llano(n,mes),'bbce2_Factures_ficticies.xlsx','Sheet','Hoja1','Range',indexLlano);
            writematrix(suma_mes_pico(n,mes),'bbce2_Factures_ficticies.xlsx','Sheet','Hoja1','Range',indexPico);
            mes=mes+1;
            if mes==11
                mes=1;
            end
        end
        
        if (dia_setmana>0 && dia_setmana<6)
            if (hora>=0 && hora<8)
                suma_mes_valle(n,mes)=suma_mes_valle(n,mes)+data_agg_with_time(i,n);
            end
            
            if (hora>=8 && hora<10)||(hora>=14 && hora<18)||(hora>=22 && hora<24)
               suma_mes_llano(n,mes)=suma_mes_llano(n,mes)+data_agg_with_time(i,n);
            end

            if (hora>=10 && hora<14)||(hora>=18 && hora<22)
               suma_mes_pico(n,mes)=suma_mes_pico(n,mes)+data_agg_with_time(i,n);
            end
        else
            suma_mes_valle(n,mes)=suma_mes_valle(n,mes)+data_agg_with_time(i,n);
        end

        hora=hora+1;
        if hora==24
            dia_setmana=dia_setmana+1;
            if dia_setmana==8
                dia_setmana=1;
            end
            hora=0;
        end
        if (i==168)
            numindex=2+(mes-1)*15+(n-1);
            strindex=int2str(numindex);
            indexValle=strcat('B',strindex);
            indexLlano=strcat('C',strindex);
            indexPico=strcat('D',strindex);
            writematrix(suma_mes_valle(n,mes),'bbce2_Factures_ficticies.xlsx','Sheet','Hoja1','Range',indexValle);
            writematrix(suma_mes_llano(n,mes),'bbce2_Factures_ficticies.xlsx','Sheet','Hoja1','Range',indexLlano);
            writematrix(suma_mes_pico(n,mes),'bbce2_Factures_ficticies.xlsx','Sheet','Hoja1','Range',indexPico);
            mes=mes+1;
            if mes==11
                mes=1;
            end
        end
    end

end

%% Función total horario

function agg_table = get_hourly_energy(table_to_agg)

    aux = size(table_to_agg);
    num_rows_tab_to_agg = aux(1);
    num_cols_tab_to_agg = aux(2);
    % Dimensiones de la tabla agregada con promedios horarios
    agg_table = zeros(num_rows_tab_to_agg/4,num_cols_tab_to_agg);
    
    % Para cada columna
    for k = 1:num_cols_tab_to_agg

        last_i = 1;
        new_table_index = 1;
        
        % Recorriendo cada columna con una ventana de 4 muestras = 1h
        for i = 4:4:num_rows_tab_to_agg

                acum = 0;
                % Calculando acumulado en 4h
                for j = last_i:i

                    acum = acum + table_to_agg(j,k);

                end
                
                % Promedio horario
                agg_table(new_table_index,k) = acum;
                last_i = last_i + 4;
                new_table_index = new_table_index + 1;

        end        

    end
    
end