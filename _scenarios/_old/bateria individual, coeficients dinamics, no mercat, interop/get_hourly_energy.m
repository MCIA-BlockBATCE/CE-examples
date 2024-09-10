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
