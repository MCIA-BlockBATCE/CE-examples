function [Pgen_real_allocated] = PV_power_allocation(Pgen_real, generation_allocation, factor_gen, CoR_type, members, week_day, hour)

% Allocated generated power is returned multiplying allocation coefficients
% with total generated power

    if (CoR_type == 1) || (CoR_type == 0)
        for n=1:members     
            Pgen_real_allocated(:,n) = Pgen_real * generation_allocation(1,n).'*factor_gen;
        end
    
    elseif (CoR_type == 3) || (CoR_type == 4)
        for n=1:members     
            Pgen_real_allocated(:,n) = generation_allocation(:,n).*Pgen_real*factor_gen;
        end

    elseif CoR_type == 2

        if CoR_type == 2

            for t=1:steps
                [X] = time_band(week_day,hour);
    
                    for n=1:members     
        
                        Pgen_real_allocated(:,n) = Pgen_real * generation_allocation(n,X)*factor_gen;
            
                    end
            end

        end
    end

end

