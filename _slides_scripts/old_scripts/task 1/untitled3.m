% Limpieza del espacio de trabajouig
clear; clc; close all;

% Paso 1: Generar una señal sintética (senoidal con ruido)
N = 1000; % Número de puntos
t = linspace(0, 10, N); % Vector de tiempo
signal_real = sin(2 * pi * 0.2 * t) + 0.1 * randn(1, N); % Señal con ruido

% Normalización de la señal
signal_real = (signal_real - mean(signal_real)) / std(signal_real);

% División en datos de entrenamiento y prueba
trainRatio = 0.8;
numTrain = floor(trainRatio * N);
XTrain = signal_real(1:numTrain);
YTrain = signal_real(2:numTrain+1); % Datos desplazados en el tiempo

% Paso 2: Definir la estructura de la red RNN
inputSize = 1;
numHiddenUnits = 100;
numResponses = 1;

layers = [ ...
    sequenceInputLayer(inputSize)
    lstmLayer(numHiddenUnits,'OutputMode','sequence')
    fullyConnectedLayer(numResponses)
    regressionLayer];

% Paso 3: Configurar las opciones de entrenamiento
options = trainingOptions('adam', ...
    'MaxEpochs', 200, ...
    'GradientThreshold', 1, ...
    'InitialLearnRate', 0.01, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.2, ...
    'LearnRateDropPeriod', 50, ...
    'Verbose', 0, ...
    'Plots', 'training-progress');

% Paso 4: Preparar los datos para la red
XTrain = num2cell(XTrain); % Convertir en formato cell para la RNN
YTrain = num2cell(YTrain);

% Entrenar la red
net = trainNetwork(XTrain, YTrain, layers, options);

% Paso 5: Predecir los valores futuros de la señal
YPred = predict(net, XTrain);

% Convertir a formato vectorial para graficar
YPred = cell2mat(YPred);

% Paso 6: Graficar la señal real contra la señal predicha
figure;
plot(t(1:numTrain), signal_real(1:numTrain), 'b', 'LineWidth', 1.5); hold on;
plot(t(1:numTrain), YPred, 'r--', 'LineWidth', 1.5);
legend('Señal real', 'Señal predicha');
xlabel('Tiempo');
ylabel('Amplitud');
title('Comparación de la Señal Real vs Señal Predicha');
grid on;
