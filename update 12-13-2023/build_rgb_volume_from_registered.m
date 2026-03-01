function [vol_rgb, names] = build_rgb_volume_from_registered(pth_registered, save_mat_path, write_check_tiff)
% Build a simple RGB volume from registered images for visualization only.
% INPUTS:
%   pth_registered: folder with registered tif/tiff/jpg images
%   save_mat_path: optional .mat output path for vol_rgb
%   write_check_tiff: optional logical, write z-stack tiff for ImageJ check
%
% OUTPUT:
%   vol_rgb: uint8 array [H x W x 3 x Z]
%   names:   image filename order used for Z

if ~exist('save_mat_path','var'); save_mat_path = ''; end
if ~exist('write_check_tiff','var') || isempty(write_check_tiff); write_check_tiff = false; end

pth_registered = char(pth_registered);
imlist = dir(fullfile(pth_registered,'*.tif'));
if isempty(imlist); imlist = dir(fullfile(pth_registered,'*.tiff')); end
if isempty(imlist); imlist = dir(fullfile(pth_registered,'*.jpg')); end
assert(~isempty(imlist), 'No registered images found in folder: %s', pth_registered);

% Alphabetical order should map to zero-padded section order.
[~,ix] = sort({imlist.name});
imlist = imlist(ix);
names = string({imlist.name});

im0 = imread(fullfile(pth_registered, imlist(1).name));
if size(im0,3) == 1
    im0 = repmat(im0, [1 1 3]);
end
[h,w,~] = size(im0);
z = numel(imlist);
vol_rgb = zeros(h,w,3,z,'uint8');
vol_rgb(:,:,:,1) = im0;

for k = 2:z
    imk = imread(fullfile(pth_registered, imlist(k).name));
    if size(imk,3) == 1
        imk = repmat(imk, [1 1 3]);
    end
    if size(imk,1) ~= h || size(imk,2) ~= w
        error('Image size mismatch at %s. Registered images must match.', imlist(k).name);
    end
    vol_rgb(:,:,:,k) = imk;
end

if ~isempty(save_mat_path)
    save(save_mat_path,'vol_rgb','names','-v7.3');
end

if write_check_tiff
    out_tif = fullfile(pth_registered,'registered_rgb_stack.tif');
    for k = 1:z
        rgb = vol_rgb(:,:,:,k);
        if k == 1
            imwrite(rgb,out_tif,'Compression','none');
        else
            imwrite(rgb,out_tif,'WriteMode','append','Compression','none');
        end
    end
end
end
