function [outputArg1,outputArg2] = Conversion_trc_MA4OS(path_input,path_output,liste_marqueur_interet,downsample,lp,mm2m,info_fillgaps)
%Conversion_trc_MA4OS Cette fonction permet de convertir un .trc généré
%automatiquement par le système Motion Analysis afin de le rendre
%compatible avec Opensim. Ce script permet de supprimer les colonnes
%inutiles, de modifier l'orientation du repère, de fillgaper/filtrer les
%données, et de rééchantilloné le fichier (divisant la fréquence
%d'échantillonage par 2)

%       path_input : chemin vers le .trc a modifier

%       path_output : chemin pour enregistrer le nouveau .trc

%       liste_marqueur_interet : indique les marqueurs a conserver

%       downsample : 0/1, si 1 la fréquence d'échantillonage est divisée
%       par 2

%       lp : indique la fréquence de coupure de filtre passe-bas

%       mm2m : si 1 permet de convertir les données de mm vers m

%       info_filgap permet de savoir si le marqueur à été filgapé


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%on importe le header et les datas
HEADER_TRC = ImportHeaderTRC(path_input);
DATA_TRC = ImportDataTRC(path_input);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%on récupère l'index des colonnes des marqueurs que l'on souhaite garder
colonnes_a_conserver = [1 2]; %déja on récupère la colonne temps et frame

%on va chercher l'index de chaque variable d'interet
for i = 1:length(liste_marqueur_interet)
    % Récupération de l'index de la colonne qui correspond à la variable d'intérêt
    idx = find(strcmp(DATA_TRC.Properties.VariableNames, liste_marqueur_interet(i)));

    % Ajout de l'index à la liste des index
    colonnes_a_conserver = [colonnes_a_conserver idx idx+1 idx+2];
end
%on conserve les colonnes d'interet
DATA_TRC = DATA_TRC(:,colonnes_a_conserver);

%on réduit la largeur du header pour
HEADER_TRC(:,width(DATA_TRC)+1:end) = [];

%dans le header on actualise le nombre de marqueurs
HEADER_TRC(3,4) = length(liste_marqueur_interet);

%Renommer marqueurs dans le header
for i = 1 : length(liste_marqueur_interet);
    idx_mkr = i*3;
    HEADER_TRC(4,idx_mkr)=liste_marqueur_interet(i);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%on rotationne les colonnes pour avoir la meme orientation que dans opensim
for i = 1 : length(liste_marqueur_interet);
    x = i*3; %index colonne X
    y = x+1; %index colonne Y
    z = y+1; %index colonne Z

    %on récupère les colonnes x y z actuelle
    colonne_x_init = DATA_TRC(:,x);
    colonne_y_init = DATA_TRC(:,y);
    colonne_z_init = DATA_TRC(:,z);

    %on réarrange les colonnes pour correspondre à opensim (rotation de -90
    %autour de l'axe X)
    DATA_TRC(:,x) = colonne_x_init;
    DATA_TRC(:,y) = colonne_z_init;
    DATA_TRC{:,z} = colonne_y_init{:,:}*-1;

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if downsample == 1;
    %permet de divise la fréquence par 2 on passe de 200 à 100hz

    % Sous-échantillonnage prendre une ligne/2
    DATA_TRC_half_fs = DATA_TRC(1:2:end, :);

    %on recréer le vecteur avec l'idx des frames
    colonne_frame = (1:height(DATA_TRC_half_fs))';
    DATA_TRC_half_fs{:,1} = colonne_frame;

    %on sauvegarde la version downsample /2
    clear DATA_TRC
    DATA_TRC = DATA_TRC_half_fs;
    clear DATA_TRC_half_fs

    %on actualise dans le header la fréquence
    HEADER_TRC(3,1) = num2str(str2num(HEADER_TRC(3,1))/2); %DataRate
    HEADER_TRC(3,2) = num2str(str2num(HEADER_TRC(3,2))/2); %CameraRate
    HEADER_TRC(3,6) = num2str(str2num(HEADER_TRC(3,6))/2); %OriginDataRate

    %on actualise dans le header nombre de frame
    HEADER_TRC(3,3) = num2str(height(DATA_TRC)); %NumFrames
    HEADER_TRC(3,8) = num2str(str2num(HEADER_TRC(3,8))/2); %OrigNumFrames
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%fillgap des données
fs = str2double(HEADER_TRC(3,1));
DATA_TRC_fillgap = zeros([height(DATA_TRC) width(DATA_TRC)]);

for i=1: width(DATA_TRC);
    DATA_TRC_fillgap(:,i) = fillgaps(DATA_TRC{:,i},fs,5);
end

if info_fillgaps == 1;
    fichier_info_fillgaps = zeros([height(DATA_TRC) length(liste_marqueur_interet)]);

    idx_colonne_marqueur_X = 3;
    for i = (1:length(liste_marqueur_interet)); %pour tous les marqueurs
        
        fichier_info_fillgaps(:,i) = isnan(DATA_TRC{:,idx_colonne_marqueur_X});
        idx_colonne_marqueur_X = idx_colonne_marqueur_X +3;
    end

    info_fillgap_file = array2table(fichier_info_fillgaps);
    info_fillgap_file.Properties.VariableNames = liste_marqueur_interet;


    path_output_without_trc = extractBefore(path_output, strlength(path_output) - 3);
    path_output_info_fillgaps = path_output_without_trc + "_info_fillgap" + ".txt";

    writetable(info_fillgap_file,path_output_info_fillgaps);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%filtrer les données
fs = str2num(HEADER_TRC(3,1));

Wn = lp/(fs/2); % fequency expressed in % of Fnyqvuit
[B,A]=butter(2,Wn,"low");

DATA_TRC_filtered = zeros([height(DATA_TRC_fillgap) width(DATA_TRC_fillgap)]);

DATA_TRC_filtered(:,1) = DATA_TRC_fillgap(:,1);
DATA_TRC_filtered(:,2) = DATA_TRC_fillgap(:,2);

for i=3: width(DATA_TRC_fillgap);
    DATA_TRC_filtered(:,i) = filtfilt(B,A,DATA_TRC_fillgap(:,i));
end

%on convertit en table pas grave si on a pas le meme nom de variable
DATA_TRC_filtered = array2table(DATA_TRC_filtered);

%on sauvegarde la version downsample /2
clear DATA_TRC
DATA_TRC = DATA_TRC_filtered;
clear DATA_TRC_filtered

%permet de convertir les mm en m
if mm2m == 1;
    DATA_TRC{:,3:end} = DATA_TRC{:,3:end}/1000;


    %on actualise dans le header unite
    HEADER_TRC(3,5) = "m"; %unite
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%On sauegarde
TRC_EXPORT = vertcat(HEADER_TRC, table2array(DATA_TRC));

writematrix(TRC_EXPORT,path_output,'Delimiter','tab','FileType','text');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end

