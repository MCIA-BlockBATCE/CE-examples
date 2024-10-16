function [BidAmount, BidStep] = serviceSelection(TimeStep, t, quarter_h, Pgen_pred_1h, ...
    PconsForecast1h, price_next_1h, DischargeEfficiency, ServiceSafetyMargin, MaximumStorageCapacity)

% This function uses consumption, generation and energy price forecast to
% find the moment of highest surplus. This TimeStep is chosen to be the
% BidStep for the following day, and the forcasted surplus is the
% BidAmount.
% BidAmount is then limited by the maximum battery capacity and
% then multiplied by a safety margin to ensure the bid is satisfied.

EnergyDiff_acum = zeros(1,96);


EnergyDiff_acum(1,1) = (Pgen_pred_1h(t+1,1)/4) - (sum(PconsForecast1h(t+1,:)/4));

for j=2:96

    EnergyDiff_acum(1,j) = EnergyDiff_acum(1,j-1) + (Pgen_pred_1h(t+j,1)/4) - sum(PconsForecast1h(t+j,:)/4);

end

CostDiff_acum = EnergyDiff_acum' .* price_next_1h(t:t+95,1);

[cost,bid_quarter_h] = max(CostDiff_acum);

BidAmount = EnergyDiff_acum(bid_quarter_h);

BidStep = t + bid_quarter_h;

% This prevents for selecting offers that are too small
if BidAmount < MaximumStorageCapacity * 0.1
    BidAmount = 0;
    BidStep = -5;
end

% Limit bid amount to max available energy
if BidAmount > MaximumStorageCapacity*DischargeEfficiency
    BidAmount = MaximumStorageCapacity*DischargeEfficiency;
end


BidAmount = BidAmount*ServiceSafetyMargin; % Safety margin to ensure the bid
                                           % is satisfied



end

