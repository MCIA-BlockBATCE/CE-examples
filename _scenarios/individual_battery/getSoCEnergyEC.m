function [SoC_energy_CER] = getSoCEnergyEC(members, MaximumStorageCapacity, StorageAllocation, SoC, t)

% This function returns the total energy amount stored in the battery

acum = 0;
for z = 1:members
    acum = acum + (MaximumStorageCapacity * StorageAllocation(z) * (SoC(t+1,z)/100));
end
SoC_energy_CER = acum; 

end

