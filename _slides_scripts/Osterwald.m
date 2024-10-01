% TODO
% - Enllaç a referencia article científic Osterwald
% - Separar en 3 seccions, (i) lectura de dades (ii) càlcul de prediccions
% (iii) visualització

clear
clc
close all


% This script shows an example of a comparison between the measured and
% estimated energy generation from a photovoltaic system over a 24-hour 
% period. The estimation is performed using the Osterwald equation, which
% takes into account irradiance and temperature variations to predict the
% PV generation output. 
%
% The script is organized as follows:
%
%   Part 1. DATA INITIALIZATION
%       This section defines the measured PV energy generation as well as
%       measured irradiance and temperature. Parameters for Osterwald
%       equation are also defined.
%
%   Part 2. ESTIMATION AND COMPARISON
%       This section calculates the estimated PV energy generation using the 
%       irradiance and temperature data with the Osterwald equation. A
%       comparison plot is generated to visualize the accuracy of the
%       model.

%% -------------- Part 1 Data Initialization --------
% Measured energy generation from PV system (in kWh) over 24 hours
PV_energy_generation = [0 0 0 0 0 1 2.1 3.4 2.8 5.1 5.5 5.9 6.1 6 5.5 5 4.2 2.8 2 1.2 0 0 0 0]';

% Measured irradiance (kW/m^2) and temperature (°C) over the same period
measured_irradiance_G = [0 0 0 0 0 1 2 3 4 5 5.5 6 6.1 6 5.5 5 4 3 2 1 0 0 0 0]';
measured_temperature = [17 17 17 16 16 17 18 19 20 21 22 23 24 25 26 25 24 23 22 21 20 19 18 17]';

% Parameter definitions for the Osterwald equation
Gref = 1;           % Reference irradiance (kW/m^2)
coef = -0.35/100;   % Temperature coefficient (percent per degree Celsius)
Tref = 25;          % Reference temperature (°C)
Pref = 1;           % Reference power (kW)

%% -------------- Part 2 Estimation and comparison --------
% Initialize estimated PV power generation array
PV_estimated_power_generation = zeros(24, 1);

% Loop through the data to calculate estimated power generation at each time step
for i = 1:length(PV_energy_generation)
    PV_estimated_power_generation(i) = Pref * (measured_irradiance_G(i) / Gref) * ...
        (1 + coef * (measured_temperature(i) - Tref));
end

% Convert power (kW) to energy (kWh) using a delta time of 1 hour
delta_T = 1; % Time interval for conversion (in hours)
PV_estimated_energy_generation = PV_estimated_power_generation * delta_T;

% --- Measured VS estimated PV energy generation ---
t = 0:1:23;
plot(t, PV_energy_generation, t, PV_estimated_energy_generation)
title("Measured PV energy generation vs Estimated PV energy generation")
ylabel("Energy [kWh]")
xlabel("Time [h]")
legend("Measured", "Estimated")