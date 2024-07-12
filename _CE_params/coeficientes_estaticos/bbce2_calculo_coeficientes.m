close all
clear all
dades_factures=readmatrix("bbce2_Factures_ficticies.xlsx",'Range','B2:D79');
num_participantes = 6;
num_meses = 10;
coeficientes = zeros(num_participantes,3,num_meses);

%% Declaración de vectores para sumatorios y tabla para CoR
filaStart = 1;
filaEnd = 6;

for mes = 1:num_meses
    sumatorio_valle_total = sum(dades_factures(filaStart:filaEnd,1));
    sumatorio_llano_total = sum(dades_factures(filaStart:filaEnd,2));
    sumatorio_pico_total = sum(dades_factures(filaStart:filaEnd,3));
    k = 1;

    for j = filaStart:filaEnd
        % Valle
        coeficientes(k,1,mes) = dades_factures(j,1)/sumatorio_valle_total;
        % Llano
        coeficientes(k,2,mes) = dades_factures(j,2)/sumatorio_llano_total;
        % Pico
        coeficientes(k,3,mes) = dades_factures(j,3)/sumatorio_pico_total;
        k = k + 1;
    end
   
    filaStart = filaStart + 8;
    filaEnd = filaEnd + 8;
end


% sumatoris_individuals=zeros(num_participantes,3);
% sumatori_valle_total=sum(dades_factures(:,1));
% sumatori_llano_total=sum(dades_factures(:,2));
% sumatori_pico_total=sum(dades_factures(:,3));
% coeficients=zeros(num_participantes,3);
% 
% %%
% for i=1:num_participantes
%     for j=1:num_participantes
%         if i==mod(j,num_participantes)
%             sumatoris_individuals(i,1)=sumatoris_individuals(i,1)+dades_factures(j,1);
%             sumatoris_individuals(i,2)=sumatoris_individuals(i,2)+dades_factures(j,2);
%             sumatoris_individuals(i,3)=sumatoris_individuals(i,3)+dades_factures(j,3);
%         end
% 
%         if (i==num_participantes) && (mod(j,num_participantes)==0)
%             sumatoris_individuals(num_participantes,1)=sumatoris_individuals(num_participantes,1)+dades_factures(j,1);
%             sumatoris_individuals(num_participantes,2)=sumatoris_individuals(num_participantes,2)+dades_factures(j,2);
%             sumatoris_individuals(num_participantes,3)=sumatoris_individuals(num_participantes,3)+dades_factures(j,3);       
%         end
%     end
% 
%     coeficients(i,1)=sumatoris_individuals(i,1)/sumatori_valle_total;
%     coeficients(i,2)=sumatoris_individuals(i,2)/sumatori_llano_total;
%     coeficients(i,3)=sumatoris_individuals(i,3)/sumatori_pico_total;
% end

tabla_coeficientes_2d = coeficientes(:,:,1);
for k = 2:num_meses

    tabla_coeficientes_2d = [tabla_coeficientes_2d; coeficientes(:,:,k)];

end

% Para cada participante, 3 promedios
tabla_coeficientes_2d_promedios = zeros(num_participantes,3);
for j = 1:num_participantes
    
   % Hago el promedio de todos los meses
   acum = 0;
   for z = 1:num_meses
        acum = acum + coeficientes(j,:,z);
   end

   tabla_coeficientes_2d_promedios(j,:) = acum/num_meses;

end
writematrix(tabla_coeficientes_2d_promedios,'bbce2_Coeficients_Tramos.xlsx','Range','B2');