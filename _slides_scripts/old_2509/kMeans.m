% Generate random data rng(1); % random sed
X = [randn(100,2)*0.75+ones(100,2); randn(100,2)*0.5-ones(100,2)];
% Apply k-means clustering with k=2 
k = 2;
[idx, centroids] = kmeans(X, k); %apply k-means clustering for two clusters

% Plot the results figure;
gscatter(X(:,1), X(:,2), idx, 'bgr', '.', 10); % plot scatter plot
hold on;
plot(centroids(:,1), centroids(:,2), 'kx', 'MarkerSize', 15, 'LineWidth', 3); 

legend('Cluster 1', 'Cluster 2', 'Centroids','Interpreter','latex');
title('K-Means Clustering results for synthetic data','Interpreter','latex');
xlabel('$X_1$','Interpreter','latex'); ylabel('$X_2$','Interpreter','latex');
