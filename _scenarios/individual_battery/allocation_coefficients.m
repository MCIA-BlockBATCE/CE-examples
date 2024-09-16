function [generation_allocation, storage_allocation] = allocation_coefficients(CoR_type, CER)
% ALLOCATION_COEFFICIENTS
%   This function computes allocation coeficients for the selected method
%   (fixed, variable or dynamic) for PV power generation and storage
%   capacity.

    if CoR_type == 0

        members = length(CER);
        generation_allocation = ones(1,members)*(1/members);
        storage_allocation = generation_allocation;

    elseif CoR_type == 1
       
        time_band_bill(CER)
        [generation_allocation] = time_band_coefficients();
        generation_allocation = sum(generation_allocation.');
        generation_allocation = generation_allocation/sum(generation_allocation);
        storage_allocation=generation_allocation;
    
    elseif CoR_type == 2
    
        time_band_bill(CER)
        [generation_allocation] = time_band_coefficients();
        members = length(CER);
        generation_allocation=generation_allocation(1:members,1:3);
        storage_allocation=generation_allocation(1:members,:);
        storage_allocation = sum(storage_allocation.'); %operacions per obtenir un CoR_bateria que no canvii durant el mes
        storage_allocation = storage_allocation/sum(storage_allocation); %operacions per obtenir un CoR_bateria estàtic que no canvii durant el mes
    
    else 
    
        [generation_allocation] = previous_sample_coefficients(CER); 
    
        % Fixed allocation rules are used to allocate storage capacity
        time_band_bill(CER)
        [storage_allocation] = time_band_coefficients();
        storage_allocation = sum(storage_allocation.'); 
        storage_allocation = storage_allocation/sum(storage_allocation); 
    
    end

end

