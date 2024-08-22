function [SoC, bid_profit, StepProfit, energy_cost_bought_while_bid, TotalEnergyDecisionIndividual] = provideService(t, n, SoC, BidStep, StorageAllocation, BidAmount, ...
           MaximumStorageCapacity, StepProfit, GenerationPowerAllocation, bid_price, energy_cost_bought_while_bid, ...
           step_energy_origin, price_next_1h, TotalEnergyDecisionIndividual)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here


   % TODO: Encapsular en función
    if(t==BidStep || t==BidStep+1 || t==BidStep+2 || t==BidStep+3)
        storage_energy_for_bid = StorageAllocation * BidAmount/4;
        previous_SoC_energy = MaximumStorageCapacity * StorageAllocation(n) * (SoC(t,n)/100);
        current_SoC_energy = previous_SoC_energy - storage_energy_for_bid(n);
        SoC(t+1,n) = 100* current_SoC_energy/(StorageAllocation(n)*MaximumStorageCapacity);
        energy_cost_bought_while_bid = energy_cost_bought_while_bid + (step_energy_origin(1,3) * price_next_1h(t));
        bid_profit(t,1) = 0;
        TotalEnergyDecisionIndividual(n,4) = TotalEnergyDecisionIndividual(n,4) +  storage_energy_for_bid(n);

        if t == BidStep+3
            bid_profit(t,1) = BidAmount * bid_price;
            StepProfit(t,n) = StepProfit(t,n) + bid_profit(t,1) * GenerationPowerAllocation(n);
        end

    end

end

