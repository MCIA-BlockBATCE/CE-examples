function [tabla_coeficientes_2d_promedios] = bbce2_calculo_coeficientes_estaticos()

    dades_factures=readmatrix("bbce2_Factures_ficticies.xlsx");
    num_participantes = length(dades_factures)/12;
    num_meses = 10;
    coeficientes = zeros(num_participantes,3,num_meses);
    
    %% Declaración de vectores para sumatorios y tabla para CoR
    filaStart = 1;
    filaEnd = num_participantes;
    dades_factures(dades_factures == 0) = 0.1;
    
    for mes = 1:num_meses
        sumatorio_valle_total = sum(dades_factures(filaStart:filaEnd,1));
        sumatorio_llano_total = sum(dades_factures(filaStart:filaEnd,2));
        sumatorio_pico_total = sum(dades_factures(filaStart:filaEnd,3));
        k = 1;
    
        for j = filaStart:filaEnd
            % Valle
            coeficientes(k,1,mes) = dades_factures(j,1)/sumatorio_valle_total;
            % Llano
            coeficientes(k,2,mes) = dades_factures(j,2)/sumatorio_llano_total;
            % Pico
            coeficientes(k,3,mes) = dades_factures(j,3)/sumatorio_pico_total;
            k = k + 1;
        end
       
        filaStart = filaStart + (num_participantes);
        filaEnd = filaEnd + (num_participantes);
    end
    
    
    tabla_coeficientes_2d = coeficientes(:,:,1);
    for k = 2:num_meses
    
        tabla_coeficientes_2d = [tabla_coeficientes_2d; coeficientes(:,:,k)];
    
    end
    
    % Para cada participante, 3 promedios
    tabla_coeficientes_2d_promedios = zeros(num_participantes,3);
    for j = 1:num_participantes
        
       % Hago el promedio de todos los meses
       acum = 0;
       for z = 1:num_meses
            acum = acum + coeficientes(j,:,z);
       end
    
       tabla_coeficientes_2d_promedios(j,:) = acum/num_meses;
    
    end
end