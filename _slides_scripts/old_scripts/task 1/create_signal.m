close all
clear all

% Parámetros de la señal
Fs = 1000;                % Frecuencia de muestreo (Hz)
T = 1/Fs;                 % Periodo de muestreo
L = 20000;                 % Número de puntos de la señal
t = (0:L-1)*T;            % Vector de tiempo

% Frecuencias de los senos
f1 = 50;                  % Frecuencia del primer seno (Hz)
f2 = 65;                 % Frecuencia del segundo seno (Hz)
f3 = 90;                 % Frecuencia del tercer seno (Hz)

% Crear la señal como la suma de senos
signal = 10 + sin(2*pi*f1*t) + sin(2*pi*f2*t) + sin(2*pi*f3*t);

% Añadir ruido aleatorio (ruido gaussiano)
noise = 0.05 * randn(size(t));  % Ruido con una varianza ajustable (0.5 aquí)
synthetic_signal = signal + noise;

% Graficar la señal
figure;
subplot(2,1,1);
plot(t, signal);
title('Señal original (suma de senos)');
xlabel('Tiempo (s)');
ylabel('Amplitud');

subplot(2,1,2);
plot(t, synthetic_signal);
title('Señal sintética con ruido');
xlabel('Tiempo (s)');
ylabel('Amplitud');

save("signal.mat", "synthetic_signal")