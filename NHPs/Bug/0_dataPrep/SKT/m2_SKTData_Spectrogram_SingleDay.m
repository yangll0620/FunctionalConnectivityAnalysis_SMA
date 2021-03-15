function m2_SKTData_spectrogram_singleDay()
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

addpath(genpath(fullfile(codefolder,'NHPs')));


% codecorresfolder, codecorresParentfolder
[codecorresfolder, codecorresParentfolder] = code_corresfolder(codefilepath, true, false);

%% global variables

% animal
if ismac
    % Code to run on Mac platform
elseif isunix
    % Code to run on Linux platform
    
    [fi, j] = regexp(codecorresfolder, ['NHPs', '/', '[A-Za-z]*']);
elseif ispc
    % Code to run on Windows platform
    
    [fi, j] = regexp(codecorresfolder, ['NHPs', '\\', '[A-Za-z]*']);
else
    disp('Platform not supported')
end
animal = codecorresfolder(fi + length('NHPs') + 1:j);


%%  input setup

% input folder: extracted raw rest data with grayMatter
inputfolder = fullfile(codecorresParentfolder, 'm1_SKTData_avgArea');


t_minmax_reach_normal = [0.5, 1];
t_minmax_return_normal = [0.5, 1];
t_minmax_reach_mild = [0.5, 1];
t_minmax_return_mild = [0.5, 1];

align2 = SKTEvent.ReachOnset;
tdur_trial_normal = [-0.6 1];
tdur_trial_mild = [-0.6 1];

coli_reachonset = uint32(SKTEvent.ReachOnset);
coli_reach = uint32(SKTEvent.Reach);
coli_returnonset = uint32(SKTEvent.ReturnOnset);
coli_mouth = uint32(SKTEvent.Mouth);

coli_align2 = coli_reachonset;

%% save setup
savefolder = codecorresfolder;

%% starting
files = dir(fullfile(inputfolder, '*.mat'));
for filei = 1: length(files)
    
    % load data, lfpdata: [nchns, ntemps, ntrials]
    filename = files(filei).name;
    load(fullfile(files(filei).folder, filename), 'lfpdata', 'T_idxevent', 'fs', 'T_chnsarea');
    
    disp(filename)
    
    if contains(filename, 'normal')
        tdur_trial = tdur_trial_normal;
        t_minmax_reach = t_minmax_reach_normal;
        t_minmax_return = t_minmax_return_normal;
        pdcond = 'normal';
    else
        if contains(filename, 'mild')
            tdur_trial = tdur_trial_mild;
            t_minmax_reach = t_minmax_reach_mild;
            t_minmax_return = t_minmax_return_mild;
            pdcond = 'mild';
        end
    end
    
    ntrials = size(lfpdata, 3);
    lfp_phase_trials = [];
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
        lfp_phase_1trial = lfpdata(:, idxdur(1):idxdur(2), tri); % lfp_phase_1trial: nchns * ntemp
        
        lfp_phase_trials = cat(3, lfp_phase_trials, lfp_phase_1trial); % lfp_phase_trials: nchns * ntemp * ntrials
        
        clear lfp_phase_1trial
    end
    
    
    savename = fullfile(savefolder, filename(1:end-length('.mat')));
    plot_spectrogram(lfp_phase_trials, T_chnsarea, fs, animal, pdcond, align2, tdur_trial, savename)
    
    close all
end

end



function plot_spectrogram(lfptrials, T_chnsarea, fs, animal, pdcond, align2, tdur_trial, savename)
%%
%   Inputs:
%           lfptrials: nchns * ntemp * ntrials
%

close all

% global parameters
twin = 0.2;
toverlap = 0.15;
f_AOI = [5 40];


nwin = round(twin * fs);
noverlap = round(toverlap * fs);
nfft = noverlap;

mask_STN = contains(T_chnsarea.brainarea, 'stn');
mask_GP = contains(T_chnsarea.brainarea, 'gp');
mask_Others = ~(mask_STN | mask_GP);
idxGroups = [{find(mask_STN)}; {find(mask_GP)}; {find(mask_Others)}];

% plot for each brain area
for idxGi = 1 : length(idxGroups)
    idxs = idxGroups{idxGi};
    
    if idxGi == 1
        clim = [-120 -80];
        areaG = 'STN';
    end
    
    if idxGi == 2
        clim = [-120 -90];
        areaG = 'GP';
    end
    
    if idxGi == 3
        clim = [-100 -80];
        areaG = 'noTDBS';
    end
    
    
    figure;
    set(gcf, 'PaperUnits', 'points',  'Position', [0, 0, 1900 1080]);
    
    for idxi = 1 : length(idxs)
        areai = idxs(idxi);
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
        psd_selected = imgaussfilt(psd_selected,'FilterSize',[1,11]);
        
        

        
        % spectrogram subplot
        subplot(3,3, idxi)
        imagesc(t_selected, f_selected, psd_selected);
        colormap(jet)
        set(gca,'YDir','normal', 'CLim', clim)
        colorbar
        
        
        xlabel('time/s')
        ylabel('psd')
        xticks([-0.5 0 0.5])
        xticklabels({-0.5, char(align2), 0.5})
        
        title([animal ' ' pdcond ': ' brainarea])
        
    end
    
    savefile = [savename '_' areaG];
    saveas(gcf, savefile, 'png');
end

end








