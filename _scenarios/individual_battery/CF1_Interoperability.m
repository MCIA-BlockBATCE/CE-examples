function [FCoste1, P_discharge_max_bid] = CF1_Interoperability(stored_energy,bid_amount,current_step,bid_step,ConsPred3h,ConsPred1h,GenPred3h, ...
                    GenPred1h,Energy_price,Selling_price,Energy_price3h,SoC,Energy_price6h,P_discharge_max,DischargeEfficiency,TimeStep)
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

% Unlike CF1, this cost function allows us to reduce the maximum discharge
% capacity of the battery when Bid Step is being aproached and we want
% to ensure Bid Amount is kept in the battery for service providing.

FCoste1 = 1;

P_discharge_max_bid = P_discharge_max;

current_cost = (ConsPred1h-GenPred1h) * Energy_price;

cost_next3h = ((ConsPred3h-GenPred3h) * Energy_price3h);

diff_bat = stored_energy-bid_amount/DischargeEfficiency;

if ((cost_next3h>current_cost*2) && (SoC<15)) || ((Energy_price6h > Energy_price*1.5))
       FCoste1 = 2;
end   

% While service providing, maximum discharge capacity is set to zero
if((current_step >= bid_step)  && (current_step <= bid_step + 3))
       P_discharge_max_bid = 0;

% Bid Amount is compared to stored energy and discharge capacity is modified
% to make sure service is fulfilled
elseif((bid_amount/DischargeEfficiency)*1.25 <= stored_energy)

       P_discharge_max_bid = diff_bat/TimeStep;   
else
       FCoste1 = 2;
       P_discharge_max_bid = 0;
end

if Energy_price < Selling_price
        FCoste1 = 0;
end

if P_discharge_max_bid > P_discharge_max
        P_discharge_max_bid = P_discharge_max;
end

end