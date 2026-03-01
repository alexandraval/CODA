function apply_image_registration(pthim,pthdata,scale,padnum,cropim,redo)
% Applies registration transforms (computed at low-res) to another image set.
% REQUIRED INPUTS:
% 1. pthim: path to images you want to register
% 2. pthdata: path to save_warps folder from calculate_image_registration
% 3. scale: ratio between pthim resolution and registration resolution
%    Example: registration at 1x, applying to 5x -> scale=5
% OPTIONAL INPUTS:
% 1. padnum: fill pixel value for empty space after warp
% 2. cropim: 1 to interactively rotate/crop output, 0 default
% 3. redo: 1 overwrite existing registered outputs, 0 default

if ~exist('redo','var'); redo = 0; end
if ~exist('padnum','var'); pd = 1; padnum = []; else; pd = 0; end
if isempty(padnum); pd = 1; end
if ~exist('cropim','var'); cropim = 0; end

addpath('image registration base functions');

pthim = normalize_path(pthim);
pthdata = normalize_path(pthdata);

imlist = dir(fullfile(pthim,'*.tif')); fl = 'tif';
if isempty(imlist); imlist = dir(fullfile(pthim,'*.tiff')); fl = 'tiff'; end
if isempty(imlist); imlist = dir(fullfile(pthim,'*.jp2')); fl = 'jp2'; end
if isempty(imlist); imlist = dir(fullfile(pthim,'*.jpg')); fl = 'jpg'; end
assert(~isempty(imlist), 'No input images found in pthim: %s', pthim);

outpth = fullfile(pthim,'registeredE');
if ~isfolder(outpth); mkdir(outpth); end

matlist = dir(fullfile(pthdata,'D','*.mat'));
assert(~isempty(matlist), 'No warp .mat files found in: %s', fullfile(pthdata,'D'));

% read geometry info from any save_warps mat
try
    datafileE = fullfile(pthdata,matlist(1).name);
    load(datafileE,'szz','padall');
catch
    datafileE = fullfile(pthdata,matlist(end).name);
    load(datafileE,'szz','padall');
end

padall = ceil(padall*scale);
refsize = ceil(szz*scale);

% optional interactive crop region
if cropim~=0
    crop_data_file = fullfile(outpth,'crop_data.mat');
    if exist(crop_data_file,'file')
        load(crop_data_file,'rot','rr');
    else
        if length(cropim)==1
            [rot,rr] = get_cropim(pthdata,scale);
        else
            rot = cropim(1); rr = cropim(2:end);
        end
        save(crop_data_file,'rot','rr');
    end
end

count = 1;
for kz = 1:length(matlist)
    imnm = [matlist(kz).name(1:end-3),fl];
    outnm = imnm;
    disp(['registering image ',num2str(kz),' of ',num2str(length(matlist)),': ',imnm])

    if exist(fullfile(outpth,outnm),'file') && ~redo
        disp('  already registered');
        continue;
    end

    if ~exist(fullfile(pthim,imnm),'file'); continue; end
    datafileE = fullfile(pthdata,[imnm(1:end-3),'mat']);
    datafileD = fullfile(pthdata,'D',[imnm(1:end-3),'mat']);
    if ~exist(datafileD,'file'); continue; end

    IM = imread(fullfile(pthim,imnm));
    szim = size(IM(:,:,1));
    if pd; padnum = squeeze(mode(mode(IM,2),1))'; end
    if szim(1)>refsize(1) || szim(2)>refsize(2)
        a = min([szim; refsize]);
        IM = IM(1:a(1),1:a(2),:);
    end
    IM = pad_im_both2(IM,refsize,padall,padnum);

    try
        load(datafileE,'tform','cent','f');
        if f==1; IM = IM(end:-1:1,:,:); end
        IMG = register_IM(IM,tform,scale,cent,padnum);

        load(datafileD,'D');
        D2 = imresize(D,size(IM(:,:,1)));
        D2 = D2.*scale;
        IME = imwarp(IMG,D2,'nearest','FillValues',padnum);
    catch
        IME = IM;
    end

    if count==1
        pth1 = fileparts(pthdata); % elastic_registration folder
        try
            im = imread(fullfile(pth1,[matlist(kz).name(1:end-3),'jpg']));
        catch
            im = imread(fullfile(pth1,[matlist(kz).name(1:end-3),'tif']));
        end
        im2 = imresize(IME,size(im(:,:,1)),'nearest');
        figure; imshowpair(im,im2); pause(2);
    end

    if cropim
        IME = imrotate(IME,rot,'nearest');
        IME = imcrop(IME,rr);
    end
    imwrite(IME,fullfile(outpth,outnm));

    count = count + 1;
    disp('  done');
    clearvars tform cent D f
end
end

function p = normalize_path(p)
p = char(p);
p = strtrim(p);
if filesep == '/'
    p = strrep(p,'\','/');
else
    p = strrep(p,'/','\');
end
while numel(p) > 1 && (p(end) == '/' || p(end) == '\')
    p(end) = [];
end
end

function IM=register_IM(IM,tform,scale,cent,abc)
cent = cent*scale;
tform.T(3,1:2) = tform.T(3,1:2)*scale;
Rin = imref2d(size(IM));
Rin.XWorldLimits = Rin.XWorldLimits-cent(1);
Rin.YWorldLimits = Rin.YWorldLimits-cent(2);
IM = imwarp(IM,Rin,tform,'nearest','outputview',Rin,'fillvalues',abc);
end

function [rot,rr]=get_cropim(pthdata,scale)
pth1 = fileparts(normalize_path(pthdata)); % elastic_registration folder
imlist = dir(fullfile(pth1,'*.tif'));
if isempty(imlist); imlist = dir(fullfile(pth1,'*.jpg')); end
assert(~isempty(imlist), 'No images found for crop UI in %s', pth1);
im1 = rgb2gray(imread(fullfile(pth1,imlist(1).name)));
im2 = rgb2gray(imread(fullfile(pth1,imlist(round(length(imlist)/2)).name)));
im3 = rgb2gray(imread(fullfile(pth1,imlist(end).name)));
im = cat(3,im1,im2,im3);
h=figure; imshow(im); isgood=0;
while isgood~=1
    rot=input('angle?\n');
    imshow(imrotate(im,rot));
    isgood=input('is good?\n');
end
im=imrotate(im,rot,'nearest');
[~,rr]=imcrop(im);
rr=round(rr)*scale;
close(h)
end
