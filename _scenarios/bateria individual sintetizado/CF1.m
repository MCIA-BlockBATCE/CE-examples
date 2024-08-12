function FCoste1 = CF1(ConsPred3h,ConsPred1h,GenPred3h, ...
                    GenPred1h,Energy_price,Selling_price,Energy_price3h,SoC,Energy_price6h)
% CF1
% Consumption of allocated power is the default output.

% To decide if we should store the energy for later we compute the
% current deficit and the average deficit over the next three hours,
% applying the energy prices to obtain a cost we can use to compare. A
% threshold is applied to this comparison to ensure that even if the 
% battery is needed more later, we don't deprive ourselves of its use now.
% Additionally, a comparison between the current energy price and the
% energy price in 6 hours is also used, in order to be able to look further
% into the future.

% Finally, if the selling price is higher than the buying price, we will
% always choose to sell the allocated power.

FCoste1 = 1; % Consume allocated energy

current_cost = (ConsPred1h-GenPred1h) * Energy_price;

cost_next3h = ((ConsPred3h-GenPred3h) * Energy_price3h);

if ((cost_next3h>current_cost*2.5) && (SoC<5)) || ((Energy_price6h > Energy_price*1.25) && (SoC<5))

       FCoste1 = 2; % Store allocated energy
end   

if Energy_price < Selling_price
        FCoste1 = 0; % Sell allocated energy
end

end
    
    