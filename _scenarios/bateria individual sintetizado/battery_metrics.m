function [CBU, AUR, ADC] = battery_metrics(SoC_energy_CER, max_capacity, days, steps)
% BATTERY_METRICS 
%   Battery metrics computed are:
%       - Average Used Range (AUR), as the average range of capacity (in
%       terms of State of Charge, SoC), which consists of the average
%       minimum SoC value (for each day) and the average maximum SoC value. 
%       - Cumulative Battery Usage (CBU), as the cumulative value of the
%       State of Charge (SoC) (i.e. as the odometer of a car). In this
%       case, a charge from 0% to 50% and then a discharge back to 0%, is
%       equivalent to a full charge from 0% to 100%, in the same period of
%       time. CBU would be 100% in both cases, where divided for the full
%       capacity (100) equals 1 cumulative cycle.
%       - Average Daily Cycles (ADC), as the average daily battery cycles,
%       where a cycle is the equivalent SoC cumulative value of a 
%       full charge and discharge.


CE_SoC_signal = 100*SoC_energy_CER(1:672)/max_capacity;
AUR_low = zeros(days,1);
AUR_high = zeros(days,1); 
CBU = 0;

q = 1;
day = 1;
for j = 1:steps
    %
    if j>1
        CBU = CBU + abs((CE_SoC_signal(j) - CE_SoC_signal(j-1))); 
    end

    q = q + 1;
    if q == 97
        firstIndex = ((day-1)*96)+1;
        lastIndex = day*96;
        AUR_low(day) = min(CE_SoC_signal(firstIndex:lastIndex));
        AUR_high(day) = max(CE_SoC_signal(firstIndex:lastIndex));
        q = 1;
        day = day + 1;
    end
end

CBU = CBU/100;
AUR = zeros(2,1);
AUR(1) = mean(AUR_low);
AUR(2) = mean(AUR_high);
ADC = (CBU/2)/days;

end

