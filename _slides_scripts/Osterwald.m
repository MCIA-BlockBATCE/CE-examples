% measured generation
PV_energy_generation = [0 0 0 0 0 1 2.1 3.4 2.8 5.1 5.5 5.9 6.1 6 5.5 5 4.2 2.8 2 1.2 0 0 0 0]';

% measured irradiance and temperature
measured_irradiance_G = [0 0 0 0 0 1 2 3 4 5 5.5 6 6.1 6 5.5 5 4 3 2 1 0 0 0 0]';
measured_temperature = [17 17 17 16 16 17 18 19 20 21 22 23 24 25 26 25 24 23 22 21 20 19 18 17]';

% parameter definition
Gref=1;
coef=-0.35/100;
Tref=25;
Pref = 1;

% Osterwald equation
PV_estimated_power_generation = zeros(24,1);
for i = 1:length(PV_energy_generation)
PV_estimated_power_generation(i) = Pref*(measured_irradiance_G(i)/Gref)*(1+coef*(measured_temperature(i)-Tref));
end
delta_T = 1; % for power->energy conversion
PV_estimated_energy_generation = PV_estimated_power_generation*delta_T;

% plot
t = 0:1:23;
plot(t, PV_energy_generation, t, PV_estimated_energy_generation)
title("Measured PV energy generation vs Estimated PV energy generation")
ylabel("Energy [kWh]")
xlabel("Time [h]")
legend("Measured", "Estimated")
