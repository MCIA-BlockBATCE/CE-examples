function [SoC_energy_CER] = getSoCEnergyEC(members, MaximumStorageCapacity, StorageAllocation, SoC, t)
%GETSOCENERGYEC Summary of this function goes here
%   Detailed explanation goes here

% TODO: Crear función para sacar SoC_energy_CER
acum = 0;
for z = 1:members
    acum = acum + (MaximumStorageCapacity * StorageAllocation(z) * (SoC(t+1,z)/100));
end
SoC_energy_CER = acum; 

end

