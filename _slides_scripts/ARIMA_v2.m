close all
clear all

load ConsProfileExample.mat

t1 = datetime(2023,5,1,0,0,0);
t2 = datetime(2023,5,31,0,0,0);
t_dates = t1:minutes(15):t2;
t_dates = t_dates';

% Create model with 1 nonseasonal autoregressive polynomial degree, 1
% nonseasonal integration degree and 1 nonseasonal moving average
% polynomial degree
poly = 5;
Mdl = arima(poly,1,1);

% Fit model to data
end_training_split = 400;
idxpre = 1:Mdl.P;
idxest = (Mdl.P + 1):end_training_split;
EstMdl = estimate(Mdl,ConsProfileExample(idxest),...
    'Y0',ConsProfileExample(idxpre));


% Forecast closing values into 500-day horizon using estimated model.
% Last two observations in estimation data are specified as presample.
yf0 = ConsProfileExample(idxest(end - (poly+1):end));
horizon = 100;
yf = forecast(EstMdl,horizon,yf0);

% dates = datetime(dates,'ConvertFrom',"datenum",...
%     'Format',"yyyy-MM-dd");

% Plot of 2000 first observations and forecast
figure(1)
h1 = plot(t_dates(1:length(ConsProfileExample)), ConsProfileExample(1:end));
hold on
h2 = plot(t_dates(end_training_split:end_training_split+horizon-1), yf,'r');

err = rms(yf - ConsProfileExample(end_training_split:end_training_split+length(yf)-1));