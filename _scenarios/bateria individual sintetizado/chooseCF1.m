function [Dec1, bid_case, MaxDishargingPowerForParticipantIfBid] = chooseCF1(TimeHorizonToBid, SoC_energy_CER, BidAmount, t, BidStep, ...
    PconsForecast3h, PconsForecast1h, Pgen_pred_3h_allocated, Pgen_pred_1h_allocated, TimeStep, ...
    price_next_1h, selling_price, price_next_3h, SoC, price_next_6h, MaxDishargingPowerForParticipant, n, DischargeEfficiency, StorageAllocation)
    
% CHOOSE CF1
%   TO BE REWRITTEN
%   areas below two consumption profile curves. A high POR indicates similar
%   consumption patterns, whereas a low POR indicates different consmpution
%   patterns.
%
%   In this function, area below curves is computed using trapz MATLAB
%   function, which performs trapezoidal numerical integration.

% TODO: Encapsular en función
if (TimeStep == 1)
    OneHour = 1;
elseif (TimeStep < 1)
    OneHour = 1/TimeStep;
end

if ( (t >= BidStep - TimeHorizonToBid*(1/TimeStep)) && t < BidStep + OneHour )
   [Dec1, MaxDishargingPowerForParticipantIfBid] = CF1_Interoperability(SoC_energy_CER(t)*StorageAllocation(n),BidAmount*StorageAllocation(n),t,BidStep,PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                 Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),selling_price(t,1),price_next_3h(t,1),SoC(t,n),price_next_6h(t,1),MaxDishargingPowerForParticipant(1,n),DischargeEfficiency);
   bid_case = 1;
   % La salida de la función sería un entero entre 0 i 2?
   % 0 vender, 1 consumir y 2 almacenar


else
   MaxDishargingPowerForParticipantIfBid = 0;
   Dec1 = CF1(PconsForecast3h(t,n),PconsForecast1h(t,n),Pgen_pred_3h_allocated(t,n), ...
                 Pgen_pred_1h_allocated(t,n),price_next_1h(t,1),selling_price(t,1),price_next_3h(t,1),SoC(t,n),price_next_6h(t,1));
   bid_case = 0;
   % La salida de la función sería un entero entre 0 i 2?
   % 0 vender, 1 consumir y 2 almacenar
end

end