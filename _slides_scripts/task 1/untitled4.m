% Limpieza del espacio de trabajo
clear; clc; close all;

% Paso 1: Generar una señal sintética (senoidal con ruido)
N = 1000; % Número de puntos
t = linspace(0, 10, N); % Vector de tiempo
signal_real = sin(2 * pi * 0.2 * t) + 0.1 * randn(1, N); % Señal con ruido

load ConsProfileExample.mat

% Normalización de la señal
signal_real = ConsProfileExample + 2;
N = length(signal_real);
t = linspace(0, 10, N); % Vector de tiempo

signal_real = (signal_real - mean(signal_real)) / std(signal_real);

% Paso 2: Definir la cantidad de pasos a predecir
nStepsAhead = 20;  % Cantidad de pasos a futuro que queremos predecir

% Paso 3: Crear los conjuntos de entrenamiento
trainRatio = 0.8;
numTrain = floor(trainRatio * N);

% Entradas de entrenamiento (XTrain) y salidas desplazadas nStepsAhead (YTrain)
XTrain = signal_real(1:numTrain - nStepsAhead);
YTrain = signal_real((1+nStepsAhead):(numTrain)); % Valores desplazados nStepsAhead

% Convertir en formato cell para la RNN (secuencia)
XTrain = num2cell(XTrain);
YTrain = num2cell(YTrain);

% Paso 4: Definir la estructura de la red RNN
inputSize = 1;
numHiddenUnits = 100;
numResponses = 1;

layers = [ ...
    sequenceInputLayer(inputSize)
    lstmLayer(numHiddenUnits,'OutputMode','sequence')
    fullyConnectedLayer(numResponses)
    regressionLayer];

% Paso 5: Configurar las opciones de entrenamiento
options = trainingOptions('adam', ...
    'MaxEpochs', 200, ...
    'GradientThreshold', 1, ...
    'InitialLearnRate', 0.01, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.2, ...
    'LearnRateDropPeriod', 50, ...
    'Verbose', 0, ...
    'Plots', 'training-progress');

% Paso 6: Entrenar la red
net = trainNetwork(XTrain, YTrain, layers, options);

% Paso 7: Predecir varios pasos a futuro
YPred = predict(net, XTrain);

% Convertir a formato vectorial para graficar
YPred = cell2mat(YPred);

% Paso 8: Graficar la señal real contra la señal predicha
figure;
plot(t(1:numTrain - nStepsAhead), signal_real(1:numTrain - nStepsAhead), 'b', 'LineWidth', 1.5); hold on;
plot(t(1:numTrain - nStepsAhead), YPred, 'r--', 'LineWidth', 1.5);
legend('Señal real', 'Señal predicha');
xlabel('Tiempo');
ylabel('Amplitud');
title(['Comparación de la Señal Real vs Señal Predicha (', num2str(nStepsAhead), ' pasos a futuro)']);
grid on;
