function review_tissue_masks_manual(pth, default_style, target, end_idx)
% Manual QC for TA masks, one image at a time.
% Usage:
%   review_tissue_masks_manual('/path/to/tifs',1)
%   review_tissue_masks_manual('/path/to/tifs',1,'case_017.tif')
%   review_tissue_masks_manual('/path/to/tifs',1,12)        % start at index 12
%   review_tissue_masks_manual('/path/to/tifs',1,12,15)     % indices 12..15
%
% Controls at prompt:
%   Enter = accept current mask, next image
%   1     = recompute mask with style 1
%   2     = recompute mask with style 2
%   q     = quit review

if ~exist('default_style','var') || isempty(default_style)
    default_style = 1;
end
if ~exist('target','var')
    target = [];
end
if ~exist('end_idx','var')
    end_idx = [];
end

pth = char(pth);
pth = strtrim(pth);
if filesep == '/'
    pth = strrep(pth,'\','/');
else
    pth = strrep(pth,'/','\');
end
while numel(pth) > 1 && (pth(end) == '/' || pth(end) == '\')
    pth(end) = [];
end

imlist = dir(fullfile(pth,'*.tif'));
if isempty(imlist); imlist = dir(fullfile(pth,'*.tiff')); end
assert(~isempty(imlist), 'No tif/tiff images found in: %s', pth);

outpth = fullfile(pth,'TA');
if ~isfolder(outpth); mkdir(outpth); end

% optional filtering / range selection
if ~isempty(target)
    if ischar(target) || (isstring(target) && isscalar(target))
        tname = char(target);
        idx = find(strcmp({imlist.name}, tname), 1, 'first');
        assert(~isempty(idx), 'Target file not found: %s', tname);
        imlist = imlist(idx);
    elseif isnumeric(target) && isscalar(target)
        sidx = max(1, round(target));
        if isempty(end_idx)
            eidx = numel(imlist);
        else
            eidx = min(numel(imlist), round(end_idx));
        end
        assert(sidx <= eidx, 'Invalid index range.');
        imlist = imlist(sidx:eidx);
    else
        error('target must be a filename string or numeric start index.');
    end
end

for k = 1:numel(imlist)
    nm = imlist(k).name;
    im = imread(fullfile(pth,nm));
    if size(im,3)==1; im = repmat(im,[1 1 3]); end
    ta_path = fullfile(outpth,nm);

    % create default mask if missing
    if ~exist(ta_path,'file')
        TA = local_make_ta(im,default_style);
        imwrite(TA,ta_path);
    end

    done = false;
    while ~done
        TA = imread(ta_path) > 0;
        figure(100); clf;
        subplot(1,2,1); imshow(im); title(sprintf('%d/%d  %s',k,numel(imlist),nm),'Interpreter','none');
        subplot(1,2,2); imshow(im); hold on;
        h = imshow(cat(3,ones(size(TA)),zeros(size(TA)),zeros(size(TA))));
        set(h,'AlphaData',0.25*double(TA));
        title('Red overlay = tissue mask');
        drawnow;

        cmd = input('Enter=accept, 1=style1, 2=style2, q=quit: ','s');
        if isempty(cmd)
            done = true;
        elseif strcmp(cmd,'1')
            TA = local_make_ta(im,1);
            imwrite(TA,ta_path);
        elseif strcmp(cmd,'2')
            TA = local_make_ta(im,2);
            imwrite(TA,ta_path);
        elseif strcmpi(cmd,'q')
            close(100);
            return;
        end
    end
end

close(100);
disp('Finished manual TA review.');
end

function TA = local_make_ta(im0,calc_style)
im = double(im0);

if calc_style == 1
    img = rgb2gray(im0);
    img = img==255 | img==0;
    im(cat(3,img,img,img)) = NaN;
    fillval = squeeze(mode(mode(im,2),1))';
    ima = im(:,:,1); imb = im(:,:,2); imc = im(:,:,3);
    ima(img)=fillval(1); imb(img)=fillval(2); imc(img)=fillval(3);
    im = cat(3,ima,imb,imc);

    TA = im - permute(fillval,[1 3 2]);
    TA = mean(abs(TA),3) > 10;
    black_line = imclose(std(im,[],3)<5 & rgb2gray(im0)<160,strel('disk',2));
    TA = TA & ~black_line;
    TA = imclose(TA,strel('disk',4));
else
    TA = im(:,:,2) < 210;
    TA = imclose(TA,strel('disk',4));
    TA = bwareaopen(TA,10);
end

TA = imfill(TA,'holes');
TA = bwlabel(TA);
N = histcounts(TA(:),max(TA(:))+1);
N(1)=0;
N(N<(max(N)/20))=0;
N(N>0)=1;
TA = N(TA+1) > 0;
end
