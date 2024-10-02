clear
clc
close all

% This script shows an example of a comparison between the measured and
% estimated energy generation from a photovoltaic system over a 24-hour 
% period. The estimation is performed using the Osterwald equation, which
% takes into account irradiance and temperature variations to predict the
% PV generation output. 
%
% Taken from:
% Osterwald, C. R. 1986. "Translation of device performance measurements to reference conditions."
% https://www.sciencedirect.com/science/article/abs/pii/0379678786901262
%
% The script is organized as follows:
%
%   Part 1. DATA LOADING
%       This section loads the measured PV energy generation as well as
%       measured irradiance and temperature. Parameters for Osterwald
%       equation are defined.
%
%   Part 2. PV ESTIMATION
%       This section calculates the estimated PV energy generation using the 
%       irradiance and temperature data with the Osterwald equation. A
%       comparison plot is generated to visualize the accuracy of the
%       model.
%
%   Part 2. VISUALIZATION
%       This section calculates the estimated PV energy generation using the 
%       irradiance and temperature data with the Osterwald equation. A
%       comparison plot is generated to visualize the accuracy of the
%       model.

%% ------------------ Part 1 Data Loading ----------------------
% Load data, containing:
%   - Measured energy generation from PV system (in kWh) over 24 hours
%   - Measured irradiance (kW/m^2) over 24 hours
%   - Measured temperature (°C) over 24 hours
load data_Osterwald.mat

% Parameter definitions for the Osterwald equation
Gref = 1;           % Reference irradiance (kW/m^2)
coef = -0.35/100;   % Temperature coefficient (percent per degree Celsius)
Tref = 25;          % Reference temperature (°C)
Pref = 1;           % Reference power (kW)

%% ------------------- Part 2 PV Estimation ----------------------
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

%% ------------------- Part 3 Visualization ---------------------

% --- Measured VS estimated PV energy generation ---
t = 0:1:23;
plot(t, PV_energy_generation, t, PV_estimated_energy_generation)
title("Measured PV energy generation vs Estimated PV energy generation")
ylabel("Energy [kWh]")
xlabel("Time [h]")
legend("Measured", "Estimated")