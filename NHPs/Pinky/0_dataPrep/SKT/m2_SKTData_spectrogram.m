function m2_SKTData_spectrogram()
%  extract lfp data respect to reachonset
% 
%  return:
%        lfptrials: nchns * ntemp * ntrials


%% folders generate
% the full path and the name of code file without suffix
codefilepath = mfilename('fullpath');

% find the codefolder
idx = strfind(codefilepath, 'code');
codefolder = codefilepath(1:idx + length('code')-1);
clear idx

% add util path
addpath(genpath(fullfile(codefolder,'util')));


% codecorresfolder, codecorresParentfolder
[codecorresfolder, codecorresParentfolder] = code_corresfolder(codefilepath, true, false);

%% global variables
% animal
[fi, j] = regexp(codecorresfolder, 'NHPs/[A-Za-z]*');
animal = codecorresfolder(fi + length('NHPs/'):j);


%%  input setup

% input folder: extracted raw rest data with grayMatter 
inputfolder = fullfile(codecorresParentfolder, 'm1_SKTData_avgArea');

%% save setup
savefolder = codecorresfolder;

%% starting: narrow filter the lfp data of all the files
files_normal = dir(fullfile(inputfolder, '*_normal_*.mat'));
files_mild = dir(fullfile(inputfolder, '*_mild_*.mat'));
files_moderate = dir(fullfile(inputfolder, '*_moderate_*.mat'));


t_minmax_reach_normal = [0.5, 1];
t_minmax_return_normal = [0.5, 1];
t_minmax_reach_mild = [0.5 1];
t_minmax_return_mild = [0.5 1];



align2 = Event.ReachOnset;
tdur_trial_normal = [-0.6 0.6];
tdur_trial_mild = [-0.6 0.6];


cond = 'normal';
files = files_normal;
tdur_trial = tdur_trial_normal;
t_minmax_reach = t_minmax_reach_normal;
t_minmax_return = t_minmax_return_normal;
[lfptrials, fs, T_chnsarea] = lfp_align2(files, align2, tdur_trial, t_minmax_reach, t_minmax_return);
plot_spectrogram_allfiles(lfptrials, T_chnsarea, fs, savefolder, animal, cond, align2, tdur_trial)
clear cond files tdur_trial t_minmax_reach t_minmax_return
clear lfptrials fs T_chnsarea



cond = 'mild';
files = files_mild;
tdur_trial = tdur_trial_mild;
t_minmax_reach = t_minmax_reach_mild;
t_minmax_return = t_minmax_return_mild;
[lfptrials, fs, T_chnsarea] = lfp_align2(files, align2, tdur_trial, t_minmax_reach, t_minmax_return);
plot_spectrogram_allfiles(lfptrials, T_chnsarea, fs, savefolder, animal, cond, align2, tdur_trial)
clear cond files tdur_trial t_minmax_reach t_minmax_return
clear lfptrials fs T_chnsarea




close all


function plot_spectrogram_allfiles(lfptrials, T_chnsarea, fs, savefolder, animal, pdcond, align2, tdur_trial)
%%

% global parameters
twin = 0.2;
toverlap = 0.15;
f_AOI = [8 50];


nwin = round(twin * fs);
noverlap = round(toverlap * fs);
nfft = noverlap;

idxSTN = find(strcmp(T_chnsarea.brainarea, 'STN'));
for i = 1 : length(idxSTN)
    T_chnsarea.brainarea{idxSTN(i)} = ['stn' num2str(i-1) '-' num2str(i)];
    
end

idxGP = find(strcmp(T_chnsarea.brainarea, 'GP'));
for i = 1 : length(idxGP)
    T_chnsarea.brainarea{idxGP(i)} = ['gp' num2str(i-1) '-' num2str(i)];
    
end

% plot for each brain area
for areai = 1 : height(T_chnsarea)
    
    brainarea = T_chnsarea.brainarea{areai};
    chnMask =  strcmp(T_chnsarea.brainarea, brainarea);
    
    
    % calculate psds: nf * nt * ntrials
    psds = [];
    for triali = 1: size(lfptrials, 3)
        x = lfptrials(chnMask, : , triali);
        
        [~, f, t, ps] = spectrogram(x, nwin, noverlap,[],fs); % ps: nf * nt
        
        psds = cat(3, psds, ps);
        
        clear x ps
    end
    psd = mean(psds, 3);
    
    idx_f = (f>=f_AOI(1) &  f<=f_AOI(2));
    f_selected =  f(idx_f);
    psd_selected = psd(idx_f, :);
    t_selected = t + tdur_trial(1);
    
    
    psd_selected = 10 * log10(psd_selected);
    psd_selected = imgaussfilt(psd_selected,'FilterSize',5);
    
    figure
    set(gcf, 'PaperUnits', 'points',  'Position', [675, 550, 700 450], 'PaperPosition', [18, 180, 710, 460]);
    
    % spectrogram subplot
    subplot('Position', [0.1 0.1 0.7 0.8])
    imagesc(t_selected, f_selected, psd_selected);
    colorbar
    set(gca,'YDir','normal')
    ylim1 = ylim;
    
    xlabel('time/s')
    ylabel('psd')
    xticks([-0.5 0 0.5])
    xticklabels({-0.5, char(align2), 0.5})
    
    title([animal ' ' pdcond ': ' brainarea])
    
    % psd subplot
    idx_t = (t_selected <0);
    psd_base = mean(psd_selected(:, idx_t), 2);
    psd_phase = mean(psd_selected(:, ~idx_t), 2);
    psd_rel = (psd_phase - psd_base) ./ abs(psd_base);
    subplot('Position', [0.85 0.1 0.1 0.8])
    plot(psd_rel, f_selected);
    ylim(ylim1)
    xlabel('psd diff')
    clear idx_t psd_base psd_phase psd_rel ylim1
    
    
    savefile = fullfile(savefolder, [animal '_' char(align2) '_' pdcond '_'   strrep(brainarea, '/', '')]);
    saveas(gcf, savefile, 'png');
   
    
    clear brainarea chnMask psds f t idx_f *_selected 
    clear savefile
end



function [lfptrials, fs, T_chnsarea] = lfp_align2(files, align2, tdur_trial, t_minmax_reach, t_minmax_return)
% extract lfp data respect to targetonset, reachonset, reach and returnonset separately

% 
%         Args:
%             align2: the event to be aligned (e.g Event.REACHONSET or uint 1-5)
% 
%             tdur_trial: the duration of extracted trials respected to event(e.g. [-0.5 0.6])
%             
%             t_minmax_reach, t_minmax_return : min and max reach/return (s) for selecting trials (e.g [0.5 1])
% 
%         return:
%             lfptrials: nchns * ntemp * ntrials
% 
%             chnAreas:
% 
%             fs:


if nargin < 5
    t_minmax_return = [0 inf];
end
if nargin < 4
    t_minmax_reach = [0 inf];
end


coli_align2 = uint32(align2);



coli_reachonset = uint32(Event.ReachOnset);
coli_reach = uint32(Event.Reach);
coli_returnonset = uint32(Event.ReturnOnset);
coli_mouth = uint32(Event.Mouth);

load(fullfile(files(1).folder, files(1).name),  'fs', 'T_chnsarea');

nfiles = length(files);
lfptrials = [];
for filei = 1 : nfiles
    
    % load data, lfpdata: [nchns, ntemps, ntrials]
    filename = files(filei).name;
    load(fullfile(files(filei).folder, filename), 'lfpdata', 'T_idxevent');
    
    if(height(T_idxevent) == 1)
        disp([filename ' has only 1 trial, skip!']);
        continue;
    end
    
    
    
    ntrials = size(lfpdata, 3);
    for tri = 1: ntrials
        
        % select trials based on reach and return duration
        t_reach = (T_idxevent{tri, coli_reach} - T_idxevent{tri, coli_reachonset}) / fs;
        t_return = (T_idxevent{tri, coli_mouth} - T_idxevent{tri, coli_returnonset}) / fs;
        if t_reach < t_minmax_reach(1) || t_reach > t_minmax_reach(2)
            clear t_reach
            continue
        end
        if t_return < t_minmax_return(1) || t_reach > t_minmax_return(2)
            clear t_return
            continue
        end
        
        
        % extract trial with t_dur
        idxdur = round(tdur_trial * fs) + T_idxevent{tri, coli_align2};
        lfp_phase_1trial = lfpdata(:, idxdur(1):idxdur(2), tri);
           
        lfptrials = cat(3, lfptrials, lfp_phase_1trial);
        
        clear t_reach t_return idxdur lfp_phase_1trial
    end
end


function combined_imgs(folder, animal)

% --- M1 ---%
brainarea = 'M1';

img_normal = imread(fullfile(folder,[animal '_normal_' brainarea '.tif']));
img_mild = imread(fullfile(folder,[animal '_mild_' brainarea '.tif']));
img_moderate = imread(fullfile(folder,[animal '_moderate_' brainarea '.tif']));
imgs_M1 = cat(1, img_normal, img_mild, img_moderate);
imwrite(imgs_M1,  fullfile(folder, ['combined_' animal brainarea '.png']));
clear img_normal img_mild img_moderate



% --- STN ---%
brainarea = 'stn';
for i = 1: 7
    
    img_normal = imread(fullfile(folder,[animal '_normal_' brainarea num2str(i-1) '-' num2str(i) '.tif']));
    img_mild = imread(fullfile(folder,[animal '_mild_' brainarea num2str(i-1) '-' num2str(i) '.tif']));
    img_moderate = imread(fullfile(folder,[animal '_moderate_' brainarea num2str(i-1) '-' num2str(i) '.tif']));
    imgs_3 = cat(1, img_normal, img_mild, img_moderate);
    
    if mod(i, 2) == 1
        imgs = imgs_3;

    else
        imgs = cat(2, imgs, imgs_3);
        
        imwrite(imgs,  fullfile(folder, ['combined_' animal upper(brainarea)  num2str(i/2) '.png']));
    end
    
    if i == 7
        
        imwrite(imgs,  fullfile(folder, ['combined_' animal upper(brainarea)  num2str(i/2 + 1) '.png']));
    end
    
    clear img_normal img_mild img_moderate
end



% --- GP ---%
brainarea = 'gp';
for i = 1: 7
    
    img_normal = imread(fullfile(folder,[animal '_normal_' brainarea num2str(i-1) '-' num2str(i) '.tif']));
    img_mild = imread(fullfile(folder,[animal '_mild_' brainarea num2str(i-1) '-' num2str(i) '.tif']));
    img_moderate = imread(fullfile(folder,[animal '_moderate_' brainarea num2str(i-1) '-' num2str(i) '.tif']));
    imgs_3 = cat(1, img_normal, img_mild, img_moderate);
    
    if mod(i, 2) == 1
        imgs = imgs_3;

    else
        imgs = cat(2, imgs, imgs_3);
        
        imwrite(imgs,  fullfile(folder, ['combined_' animal upper(brainarea)  num2str(i/2) '.png']));
    end
    
    if i == 7
        
        imwrite(imgs,  fullfile(folder, ['combined_' animal upper(brainarea)  num2str(i/2 + 1) '.png']));
    end
    
    clear img_normal img_mild img_moderate
end
