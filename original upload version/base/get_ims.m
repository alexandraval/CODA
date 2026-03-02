function [im, TA] = get_ims(pth, nm, tp, IHC, rdo)

if ~exist('rdo','var')
    rdo = 0;
end

pth = char(pth);

% --- Create TA folder safely ---
pthTA = fullfile(pth,'TA');
if ~exist(pthTA,'dir')
    mkdir(pthTA);
end

% --- Read main image ---
im = imread(fullfile(pth, [nm tp]));
if size(im,3)==1
    im = cat(3,im,im,im);
end

% --- TA file path ---
TAfile = fullfile(pthTA, [nm 'tif']);

if exist(TAfile,'file') && ~rdo
    TA = imread(TAfile);
else
    TA = find_tissue_area(im,nm);
    imwrite(TA, TAfile);
end

end
% figure,subplot(1,2,1),imshow(im);subplot(1,2,2),imshow(TA)
% TA=im(:,:,1);
% TA=TA>30;
% TA=imclose(TA,strel('disk',10));
% TA=bwareaopen(TA,5000);
% imshow(TA)