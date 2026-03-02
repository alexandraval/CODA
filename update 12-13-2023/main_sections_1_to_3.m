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
    write_check_tiff = false; % large 5x stacks can exceed classic TIFF size limits
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

%% Section 5A - Original 3D color stack (white background removed)
% Allow this section to run independently.
if ~exist('run_section5a_original_3d','var'); run_section5a_original_3d = true; end
if ~exist('pth','var') || isempty(pth)
    pth = '/Users/alexandravaldepenas/Desktop/CODA/processed_serials';
end

if run_section5a_original_3d
    fprintf('\n=== Section 5A: original 3D color stack ===\n');
    matfile = fullfile(pth,'registeredE','vol_rgb_5x.mat');
    assert(exist(matfile,'file')==2, 'Volume MAT not found: %s', matfile);
    S = load(matfile,'vol_rgb');
    V = permute(S.vol_rgb,[1 2 4 3]); % [H W Z 3]

    % Side views for context
    xy_um = 2; z_um = 10;
    z_scale = (z_um/xy_um)*5;
    y0 = round(size(V,2)/2);
    xz = squeeze(V(:,y0,:,:));
    xz_show = imresize(xz,[size(xz,1), max(1,round(size(xz,2)*z_scale))],'nearest');
    figure; imshow(xz_show); title('XZ side view (original)');

    x0 = round(size(V,1)/2);
    yz = squeeze(V(x0,:,:,:));
    yz_show = imresize(yz,[size(yz,1), max(1,round(size(yz,2)*z_scale))],'nearest');
    figure; imshow(yz_show); title('YZ side view (original)');

    render_3d_stack_with_slider(V, false);
end

%% Section 5B - Hematoxylin-thresholded 3D stack
% Allow this section to run independently.
if ~exist('run_section5b_hematoxylin_3d','var'); run_section5b_hematoxylin_3d = true; end
if ~exist('pth','var') || isempty(pth)
    pth = '/Users/alexandravaldepenas/Desktop/CODA/processed_serials';
end

if run_section5b_hematoxylin_3d
    fprintf('\n=== Section 5B: hematoxylin-thresholded 3D stack ===\n');
    matfile = fullfile(pth,'registeredE','vol_rgb_5x.mat');
    assert(exist(matfile,'file')==2, 'Volume MAT not found: %s', matfile);
    S = load(matfile,'vol_rgb');
    V = permute(S.vol_rgb,[1 2 4 3]); % [H W Z 3]
    render_3d_stack_with_slider(V, true);
end

%% Section 6 - Nuclei density heatmap (hematoxylin-like signal)
% Allow this section to run independently.
if ~exist('run_section6_nuclei_density_heatmap','var'); run_section6_nuclei_density_heatmap = true; end
if ~exist('pth','var') || isempty(pth)
    pth = '/Users/alexandravaldepenas/Desktop/CODA/processed_serials';
end

if run_section6_nuclei_density_heatmap
    fprintf('\n=== Section 6: nuclei density heatmap ===\n');

    matfile = fullfile(pth,'registeredE','vol_rgb_5x.mat');
    assert(exist(matfile,'file')==2, 'Volume MAT not found: %s', matfile);
    S = load(matfile,'vol_rgb');
    V = permute(S.vol_rgb,[1 2 4 3]); % [H W Z 3]

    % Lighter computation on downsampled XY grid.
    xy_downsample_for_heatmap = 8;
    rows = 1:xy_downsample_for_heatmap:size(V,1);
    cols = 1:xy_downsample_for_heatmap:size(V,2);
    zN = size(V,3);

    % Hematoxylin-like threshold settings (same style as Section 5).
    he_blue_over_green = 8;
    he_blue_over_red   = 5;
    he_sat_thr         = 20;
    he_max_brightness  = 210;

    density_xy = zeros(numel(rows), numel(cols), 'single');
    nuclei_per_slice = zeros(zN,1,'single');

    for zz = 1:zN
        img = squeeze(V(rows, cols, zz, :)); % [h w 3]
        sat = max(img,[],3) - min(img,[],3);
        he_mask = ...
            (img(:,:,3) > img(:,:,2) + he_blue_over_green) & ...
            (img(:,:,3) > img(:,:,1) + he_blue_over_red) & ...
            (sat > he_sat_thr) & ...
            (mean(img,3) < he_max_brightness);

        density_xy = density_xy + single(he_mask);
        nuclei_per_slice(zz) = sum(he_mask(:));
    end

    % Smooth and normalize for display.
    density_xy_s = imgaussfilt(density_xy, 2);
    dmin = min(density_xy_s(:));
    dmax = max(density_xy_s(:));
    if dmax > dmin
        density_xy_n = (density_xy_s - dmin) / (dmax - dmin);
    else
        density_xy_n = zeros(size(density_xy_s), 'single');
    end

    % Heatmap view.
    figure('Color','w','Name','Nuclei Density Heatmap');
    imagesc(density_xy_n);
    axis image off;
    colormap(turbo);
    cb = colorbar;
    cb.Label.String = 'Relative nuclei density';
    title(sprintf('Hematoxylin-derived nuclei density (XY ds=%d)', xy_downsample_for_heatmap));

    % Mark top hotspot points.
    [~,ord] = sort(density_xy_n(:), 'descend');
    n_hotspots = min(25, numel(ord));
    [hy,hx] = ind2sub(size(density_xy_n), ord(1:n_hotspots));
    hold on;
    plot(hx,hy,'wo','MarkerSize',6,'LineWidth',1.2);
    hold off;

    % Per-slice nuclei trend.
    figure('Color','w','Name','Nuclei per Slice');
    plot(1:zN, nuclei_per_slice, '-k', 'LineWidth', 1.5);
    xlabel('Slice index (Z)');
    ylabel('Hematoxylin mask pixel count');
    title('Approximate nuclei signal per slice');
    grid on;

    % 3D density surface view
    figure('Color','w','Name','Nuclei Density 3D Surface');
    surf(density_xy_n, 'EdgeColor', 'none');
    colormap(turbo);
    colorbar;
    view(35,55);
    axis tight;
    xlabel('X (downsampled)');
    ylabel('Y (downsampled)');
    zlabel('Relative density');
    title('3D nuclei-density surface');
end

%% Section 7 - 3D hotspot volumes (top 20% nuclei density)
% Show only the densest nuclei regions in 3D.
if ~exist('run_section7_top_density_3d','var'); run_section7_top_density_3d = true; end
if ~exist('pth','var') || isempty(pth)
    pth = '/Users/alexandravaldepenas/Desktop/CODA/processed_serials';
end

if run_section7_top_density_3d
    fprintf('\n=== Section 7: 3D hotspot volumes (top 20%% density) ===\n');

    matfile = fullfile(pth,'registeredE','vol_rgb_5x.mat');
    assert(exist(matfile,'file')==2, 'Volume MAT not found: %s', matfile);
    S = load(matfile,'vol_rgb');
    V = permute(S.vol_rgb,[1 2 4 3]); % [H W Z 3]

    % Downsample for speed/stability.
    xy_ds = 12;
    z_ds = 1;
    Vd = V(1:xy_ds:end,1:xy_ds:end,1:z_ds:end,:);

    % Hematoxylin-like voxel mask.
    he_blue_over_green = 8;
    he_blue_over_red   = 5;
    he_sat_thr         = 20;
    he_max_brightness  = 210;
    sat = max(Vd,[],4) - min(Vd,[],4);
    H = (Vd(:,:,:,3) > Vd(:,:,:,2) + he_blue_over_green) & ...
        (Vd(:,:,:,3) > Vd(:,:,:,1) + he_blue_over_red) & ...
        (sat > he_sat_thr) & ...
        (mean(Vd,4) < he_max_brightness);

    % 3D local density field and top-20% threshold.
    D = imgaussfilt3(single(H), [2 2 1]);
    vals = D(H);
    if isempty(vals)
        warning('No hematoxylin-like voxels found with current thresholds.');
    else
        thr = prctile(vals, 80); % top 20%
        hot = D >= thr;
        hot = bwareaopen(hot, 20);

        % Build 3D surface for hotspot regions.
        [f,v] = isosurface(hot, 0.5);
        if isempty(f)
            warning('No hotspot surface found. Try lower threshold or less downsampling.');
        else
            % Exaggerate Z spacing for display (same idea as Section 5).
            z_scale = 5;
            v(:,3) = v(:,3) * z_scale;

            figure('Color','k','Name','Top 20% nuclei-density hotspots (3D)');
            p = patch('Faces',f,'Vertices',v);
            p.FaceColor = [1.0 0.45 0.10];
            p.EdgeColor = 'none';
            p.FaceAlpha = 0.85;
            camlight headlight;
            lighting gouraud;
            material dull;
            axis tight vis3d;
            daspect([1 1 1]);
            view(35,25);
            set(gca,'Color','k','XColor','w','YColor','w','ZColor','w');
            xlabel('X'); ylabel('Y'); zlabel('Z (scaled)');
            title('Top 20% nuclei-density hotspot volumes','Color','w');
            rotate3d on;
            disp('3D hotspot volume opened. Click-drag to rotate.');
        end
    end
end

function render_3d_stack_with_slider(V, show_hematoxylin_only)
% V: [H W Z 3]
xy_downsample_for_3d = 32;
repeat_per_slice = 5;
rows = 1:xy_downsample_for_3d:size(V,1);
cols = 1:xy_downsample_for_3d:size(V,2);
Vd = V(rows, cols, :, :);
Vrep = repelem(Vd, 1, 1, repeat_per_slice, 1);
[h3,w3,z3,~] = size(Vrep);
[X,Y] = meshgrid(1:w3,1:h3);

fig = figure('Color','k', 'Name', 'Interactive 3D color stack');
ax = axes(fig); hold(ax,'on');
hs = gobjects(z3,1);
white_thr = 220;
sat_thr = 28;
he_blue_over_green = 8;
he_blue_over_red   = 5;
he_sat_thr         = 20;
he_max_brightness  = 210;

for zz = 1:z3
    img = squeeze(Vrep(:,:,zz,:));
    sat = max(img,[],3) - min(img,[],3);
    is_white_bg = all(img > white_thr, 3) & sat < sat_thr;
    if show_hematoxylin_only
        he_mask = ...
            (img(:,:,3) > img(:,:,2) + he_blue_over_green) & ...
            (img(:,:,3) > img(:,:,1) + he_blue_over_red) & ...
            (sat > he_sat_thr) & ...
            (mean(img,3) < he_max_brightness);
        alpha_mask = single(~is_white_bg & he_mask);
    else
        alpha_mask = single(~is_white_bg);
    end
    hs(zz) = surface(ax, X, Y, zz*ones(h3,w3), im2double(img), ...
        'FaceColor','texturemap', 'EdgeColor','none', ...
        'FaceAlpha','texturemap', 'AlphaData', alpha_mask, 'AlphaDataMapping','none');
end
hold(ax,'off');
axis(ax,'tight');
daspect(ax,[1 1 1]);
view(ax, 35, 25);
camproj(ax,'perspective');
set(ax,'YDir','reverse','Color','k');
xlabel(ax,'X'); ylabel(ax,'Y'); zlabel(ax,'Z (slice index)');
if show_hematoxylin_only
    title(ax,sprintf('3D stack (hematoxylin-only; XY ds=%d, repeat=%d)', ...
        xy_downsample_for_3d, repeat_per_slice), 'Color','w');
else
    title(ax,sprintf('3D stack (original colors; XY ds=%d, repeat=%d)', ...
        xy_downsample_for_3d, repeat_per_slice), 'Color','w');
end
rotate3d(ax,'on');
z0 = z3;
hTxt = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.40 0.02 0.20 0.05], ...
    'String', sprintf('Visible Z: %d / %d', z0, z3), ...
    'BackgroundColor', 'k', 'ForegroundColor', 'w');
hSl = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
    'Position', [0.08 0.08 0.84 0.04], ...
    'Min', 1, 'Max', z3, 'Value', z0, ...
    'SliderStep', [1/max(1,z3-1), min(10/max(1,z3-1),1)]);
set(hSl, 'Callback', @(src,~) update_3d_z_slider(src,hs,hTxt,z3));
disp('3D stack opened. Drag to rotate; use slider to move through Z.');
end

function update_3d_z_slider(src,hs,hTxt,zN)
k = round(src.Value);
k = max(1,min(zN,k));
set(src,'Value',k);
for ii = 1:zN
    if ii <= k
        set(hs(ii), 'Visible', 'on');
    else
        set(hs(ii), 'Visible', 'off');
    end
end
set(hTxt, 'String', sprintf('Visible Z: %d / %d', k, zN));
drawnow limitrate;
end
