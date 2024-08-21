function [BidAmount, BidStep] = serviceSelection(TimeStep, t, quarter_h, Pgen_pred_1h, ...
    PconsForecast1h, price_next_1h, DischargeEfficiency, ServiceSafetyMargin, MaximumStorageCapacity)
%SERVICESELECTION Summary of this function goes here
%   Detailed explanation goes here

EnergyDiff_acum = zeros(1,96);


EnergyDiff_acum(1,1) = (Pgen_pred_1h(t+1,1)/4) - (sum(PconsForecast1h(t+1,:)/4));

for j=2:96

    EnergyDiff_acum(1,j) = EnergyDiff_acum(1,j-1) + (Pgen_pred_1h(t+j,1)/4) - sum(PconsForecast1h(t+j,:)/4);

end

CostDiff_acum = EnergyDiff_acum' .* price_next_1h(t:t+95,1); % Potser fer servir un altre vector de preus

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


BidAmount = BidAmount*ServiceSafetyMargin; % Safety margin to ensure we 
                              % satisfy the bid



end

