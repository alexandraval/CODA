%% CODA Main Runner (Sections 1-3, pre-segmentation)
% Run from MATLAB. This script covers:
%   Section 1: filename checks
%   Section 2: downsampled tif creation
%   Section 3: tissue mask + image registration

%% Setup
clear; clc;

% Keep MATLAB path rooted in this CODA update folder.
% mfilename('fullpath') can point to a temporary private folder when
% running only a section; use active editor filename when available.
active_file = matlab.desktop.editor.getActiveFilename;
if ~isempty(active_file)
    script_dir = fileparts(active_file);
else
    script_dir = fileparts(mfilename('fullpath'));
end
% Do NOT change Current Folder; only add code folder to path.
if ~contains(path, script_dir)
    addpath(script_dir);
end

% ===== USER INPUT =====
% If you already exported preprocessed TIFFs at a common scale (your case),
% set use_preexported_tiffs = true and pth to that TIFF folder.
use_preexported_tiffs = true;

% Input folder:
% - use_preexported_tiffs=true: folder with ordered .tif/.tiff images
% - use_preexported_tiffs=false: folder with .ndpi/.svs/.scn slides
pth = '/Users/alexandravaldepenas/Desktop/CODA/processed_serials';

% Downsample targets from the instructions.
ds = [1 2 10];
subfolders = ["10x" "5x" "1x"];

% Optional extra downsample for pre-exported TIFF registration speed.
% Example: if pth has TIFFs, make pth/1x by resizing each image to 1/5.
use_extra_downsample_for_registration = true;
extra_ds_factor = 5;
extra_ds_foldername = '1x';
overwrite_extra_ds = false;

% Registration/tissue-mask settings.
calc_style = 1;     % First try 1. If TA masks are bad, set to 2 and rerun section 3A.
IHC = 0;            % 0 for H&E, 1 for IHC.
zc = [];            % Leave [] to use the center image as reference.
regE = [];          % Leave [] to use defaults in calculate_image_registration.

% Section toggles
run_section1 = true;
run_section2 = false;
run_section2B_make_1x_from_tiffs = true;
run_section3A_tissue_masks = true;
run_section3B_registration = true;
run_section4_apply_to_5x_and_build_volume = false;

assert(isfolder(pth), 'Set "pth" to a valid folder before running.');

% Resolve registration input folder once so any section can run independently.
if use_preexported_tiffs
    if use_extra_downsample_for_registration
        pth1x = fullfile(pth, extra_ds_foldername);
    else
        pth1x = pth;
    end
else
    pth1x = fullfile(pth, '1x');
end

%% Section 1 - Filename checks (zero-padding)
if run_section1
    fprintf('\n=== Section 1: filename checks ===\n');

    if use_preexported_tiffs
        slides = dir(fullfile(pth, '*.tif'));
        if isempty(slides), slides = dir(fullfile(pth, '*.tiff')); end
        assert(~isempty(slides), 'No .tif/.tiff files found in pth.');
    else
        slides = dir(fullfile(pth, '*.ndpi'));
        if isempty(slides), slides = dir(fullfile(pth, '*.svs')); end
        if isempty(slides), slides = dir(fullfile(pth, '*.scn')); end
        assert(~isempty(slides), 'No .ndpi/.svs/.scn files found in pth.');
    end

    names = string({slides.name});
    fprintf('Found %d slide files.\n', numel(names));

    % Heuristic check: filenames should include zero-padded numeric indices.
    % Example good: lungs_001.ndpi
    non_padded = false;
    for k = 1:numel(names)
        nm = char(names(k));
        token = regexp(nm, '(\d+)(?=\.[^.]+$)', 'tokens', 'once');
        if ~isempty(token)
            if numel(token{1}) < 3
                non_padded = true;
                fprintf('  Potential non-padded filename: %s\n', nm);
            end
        end
    end

    if non_padded
        warning('Some filenames appear non-padded. Rename before Section 2.');
    else
        fprintf('Filename check complete: no obvious non-padded indices found.\n');
    end
end

%% Section 2 - Create downsampled copies of high-resolution images
if run_section2 && ~use_preexported_tiffs
    fprintf('\n=== Section 2: create downsampled tifs ===\n');
    create_downsampled_tif_images(pth, ds, subfolders);
end

%% Section 2B - Extra downsample for pre-exported TIFFs (speed mode)
% Allow this section to run independently.
if ~exist('run_section2B_make_1x_from_tiffs','var'); run_section2B_make_1x_from_tiffs = true; end
if ~exist('use_preexported_tiffs','var'); use_preexported_tiffs = true; end
if ~exist('use_extra_downsample_for_registration','var'); use_extra_downsample_for_registration = true; end
if ~exist('extra_ds_factor','var') || isempty(extra_ds_factor); extra_ds_factor = 5; end
if ~exist('extra_ds_foldername','var') || isempty(extra_ds_foldername); extra_ds_foldername = '1x'; end
if ~exist('overwrite_extra_ds','var'); overwrite_extra_ds = false; end
if ~exist('pth','var') || isempty(pth)
    error('Define pth before running Section 2B. Example: pth=''/Users/.../processed_serials'';');
end

if run_section2B_make_1x_from_tiffs && use_preexported_tiffs && use_extra_downsample_for_registration
    fprintf('\n=== Section 2B: create extra-downsampled 1x TIFF folder ===\n');
    assert(extra_ds_factor > 1, 'extra_ds_factor must be > 1');

    src_list = dir(fullfile(pth, '*.tif'));
    if isempty(src_list), src_list = dir(fullfile(pth, '*.tiff')); end
    assert(~isempty(src_list), 'No .tif/.tiff files found in pth: %s', pth);

    out1x = fullfile(pth, extra_ds_foldername);
    if ~isfolder(out1x), mkdir(out1x); end

    for k = 1:numel(src_list)
        nm = src_list(k).name;
        src = fullfile(pth, nm);
        dst = fullfile(out1x, nm);
        if exist(dst, 'file') && ~overwrite_extra_ds
            continue;
        end

        im = imread(src);
        new_sz = max(floor(size(im(:,:,1)) / extra_ds_factor), [1 1]);
        im_ds = imresize(im, new_sz, 'nearest');
        imwrite(im_ds, dst);

        if mod(k,5)==0 || k==numel(src_list)
            fprintf('  downsampled %d/%d\n', k, numel(src_list));
        end
    end

    fprintf('Created/updated folder: %s\n', out1x);
end

%% Section 3A - Calculate tissue masks on low-resolution images (1x)
if ~isfolder(pth1x)
    error('Expected folder not found: %s. If using raw slides, run Section 2 first.', pth1x);
end

if run_section3A_tissue_masks
    fprintf('\n=== Section 3A: calculate tissue masks (TA) ===\n');
    calculate_tissue_ws(pth1x, calc_style);
    fprintf('Review masks in: %s\n', fullfile(pth1x, 'TA'));
    fprintf('If masks look wrong: delete TA files, set calc_style=2, rerun Section 3A.\n');
end

%% Section 3B - Calculate image registration on low-resolution images
% Allow this section to run independently.
if ~exist('run_section3B_registration','var'); run_section3B_registration = true; end
if ~exist('IHC','var') || isempty(IHC); IHC = 0; end
if ~exist('zc','var'); zc = []; end
if ~exist('regE','var'); regE = []; end

% Make sure function paths are available even when running only this section.
if ~exist('script_dir','var') || isempty(script_dir)
    active_file = matlab.desktop.editor.getActiveFilename;
    if ~isempty(active_file)
        script_dir = fileparts(active_file);
    else
        script_dir = pwd;
    end
end
if ~contains(path, script_dir)
    addpath(script_dir);
end
base_reg_dir = fullfile(script_dir, 'image registration base functions');
if isfolder(base_reg_dir) && ~contains(path, base_reg_dir)
    addpath(base_reg_dir);
end

if ~exist('pth1x','var') || isempty(pth1x)
    if exist('pth','var') && ~isempty(pth)
        if exist('use_preexported_tiffs','var') && use_preexported_tiffs
            if exist('use_extra_downsample_for_registration','var') && use_extra_downsample_for_registration
                if ~exist('extra_ds_foldername','var') || isempty(extra_ds_foldername)
                    extra_ds_foldername = '1x';
                end
                pth1x = fullfile(pth, extra_ds_foldername);
            else
                pth1x = pth;
            end
        else
            pth1x = fullfile(pth,'1x');
        end
    else
        % User-local fallback candidates for running this section directly.
        cands = { ...
            '/Users/alexandravaldepenas/Desktop/CODA/processed_serials/1x', ...
            '/Users/alexandravaldepenas/Desktop/CODA/processed_serials' ...
        };
        found = '';
        for ii = 1:numel(cands)
            if isfolder(cands{ii})
                found = cands{ii};
                break;
            end
        end
        if ~isempty(found)
            pth1x = found;
        else
            error(['Define pth1x (or pth) before running only Section 3B. ', ...
                   'Example: pth1x=''/Users/.../your_tiff_folder'';']);
        end
    end
end
if ~isfolder(pth1x)
    error('Registration input folder does not exist: %s', pth1x);
end

if run_section3B_registration
    fprintf('\n=== Section 3B: calculate image registration ===\n');
    if isempty(regE)
        if isempty(zc)
            calculate_image_registration(pth1x, IHC);
        else
            calculate_image_registration(pth1x, IHC, zc);
        end
    else
        if isempty(zc)
            calculate_image_registration(pth1x, IHC, [], regE);
        else
            calculate_image_registration(pth1x, IHC, zc, regE);
        end
    end

    fprintf('Registration outputs:\n');
    fprintf('  Global:   %s\n', fullfile(pth1x, 'registered'));
    fprintf('  Elastic:  %s\n', fullfile(pth1x, 'registered', 'elastic_registration'));
    fprintf('  Warps:    %s\n', fullfile(pth1x, 'registered', 'elastic_registration', 'save_warps'));
    fprintf('  QC stack: %s\n', fullfile(pth1x, 'registered', 'elastic_registration', 'check'));
end

fprintf('\nDone. Sections 1-3 completed (based on toggles).\n');

%% Section 4 - Apply 1x warps to 5x images, build RGB volume, visualize
% Allow this section to run independently.
if ~exist('run_section4_apply_to_5x_and_build_volume','var'); run_section4_apply_to_5x_and_build_volume = true; end
if ~exist('pth','var') || isempty(pth)
    pth = '/Users/alexandravaldepenas/Desktop/CODA/processed_serials';
end
if ~exist('extra_ds_factor','var') || isempty(extra_ds_factor); extra_ds_factor = 5; end
if ~exist('extra_ds_foldername','var') || isempty(extra_ds_foldername); extra_ds_foldername = '1x'; end

if run_section4_apply_to_5x_and_build_volume
    fprintf('\n=== Section 4: apply registration to 5x + build RGB volume ===\n');

    pth5x = pth;
    pth1x = fullfile(pth, extra_ds_foldername);
    pthdata = fullfile(pth1x, 'registered', 'elastic_registration', 'save_warps');
    apply_scale = extra_ds_factor; % 1x was created by resizing pth by this factor

    % 0=skip existing files, 1=overwrite existing registeredE files
    redo_apply = 0;
    apply_image_registration(pth5x, pthdata, apply_scale, [], 0, redo_apply);

    pth_reg5x = fullfile(pth5x, 'registeredE');
    save_mat = fullfile(pth_reg5x, 'vol_rgb_5x.mat');
    write_check_tiff = true;
    [vol_rgb, names] = build_rgb_volume_from_registered(pth_reg5x, save_mat, write_check_tiff); %#ok<NASGU,ASGLU>

    fprintf('Volume saved: %s\n', save_mat);
    fprintf('Registered 5x folder: %s\n', pth_reg5x);

    % quick preview
    k = round(size(vol_rgb,4)/2);
    figure; imshow(vol_rgb(:,:,:,k)); title(sprintf('vol\\_rgb middle slice %d', k));
    if exist('sliceViewer','file')
        sliceViewer(vol_rgb);
    end
end
