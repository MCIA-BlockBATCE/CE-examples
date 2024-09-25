clear all
close all

%% Autoregressive integrated moving average prediction
% Load US equity indices dataset
load Data_EquityIdx

% Create model with 1 nonseasonal autoregressive polynomial degree, 1
% nonseasonal integration degree and 1 nonseasonal moving average
% polynomial degree
Mdl = arima(1,1,1);

% Fit model to data
idxpre = 1:Mdl.P;
idxest = (Mdl.P + 1):1500;
EstMdl = estimate(Mdl,DataTable.NASDAQ(idxest),...
    'Y0',DataTable.NASDAQ(idxpre));


% Forecast closing values into 500-day horizon using estimated model.
% Last two observations in estimation data are specified as presample.
yf0 = DataTable.NASDAQ(idxest(end - 1:end));
yf = forecast(EstMdl,500,yf0);

dates = datetime(dates,'ConvertFrom',"datenum",...
    'Format',"yyyy-MM-dd");

% Plot of 2000 first observations and forecast
figure(1)
h1 = plot(dates(1:2000),DataTable.NASDAQ(1:2000));
hold on
h2 = plot(dates(1501:2000),yf,'r');
legend([h1 h2],"Observed","Forecasted",...
	     'Location',"NorthWest")
title("NASDAQ Composite Index: 1990-01-02 – 1997-11-25")
xlabel("Time (days)")
ylabel("Closing Price")
hold off
