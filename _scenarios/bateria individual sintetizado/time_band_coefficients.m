function [time_band_allocation_coefficients] = time_band_coefficients()

    % This function uses the time band bill, previously saved into a
    % spreadsheet, to compute allocation coefficients.

    consumption_data=readmatrix("..\..\_data\bbce2_Factures_ficticies.xlsx");
    
    % Initialization and declaration of variables and vectors
    members = length(consumption_data)/12;
    months = 10;
    coefficients = zeros(members,3,months);
    rowStart = 1;
    rowEnd = members;
    consumption_data(consumption_data == 0) = 0.1;
    
    for mes = 1:months
        valley_aggregate = sum(consumption_data(rowStart:rowEnd,1));
        plain_aggregate = sum(consumption_data(rowStart:rowEnd,2));
        peak_aggregate = sum(consumption_data(rowStart:rowEnd,3));
        k = 1;
    
        for j = rowStart:rowEnd
            % Valley
            coefficients(k,1,mes) = consumption_data(j,1)/valley_aggregate;
            % Plain
            coefficients(k,2,mes) = consumption_data(j,2)/plain_aggregate;
            % Peak
            coefficients(k,3,mes) = consumption_data(j,3)/peak_aggregate;
            k = k + 1;
        end
       
        rowStart = rowStart + (members);
        rowEnd = rowEnd + (members);
    end
    
    
    coefficients_table_2d = coefficients(:,:,1);
    for k = 2:months
    
        coefficients_table_2d = [coefficients_table_2d; coefficients(:,:,k)];
    
    end
    
    % 3 consumption averages for each member and each month
    time_band_allocation_coefficients = zeros(members,3);
    for j = 1:members
        
       acum = 0;
       for z = 1:months
            acum = acum + coefficients(j,:,z);
       end
    
       time_band_allocation_coefficients(j,:) = acum/months;
    
    end
end