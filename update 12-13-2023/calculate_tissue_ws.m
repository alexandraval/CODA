function calculate_tissue_ws(pth,calc_style)
% calculates tissue masks used for nonlinear image registration
% INPUTS:
% 1. pth: folder containing tif images
% 2. calc_style: method to calculate TA (1 first, then 2 if needed)
% OUTPUT:
% saves logical tif images in subfolder pth/TA

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
if isempty(imlist)
    imlist = dir(fullfile(pth,'*.tiff'));
end

outpth = fullfile(pth,'TA');
if ~isfolder(outpth); mkdir(outpth); end
if ~exist('calc_style','var'); calc_style = 1; end

for k = 1:length(imlist)
    nm = imlist(k).name;
    disp(['calculating whitespace for image ',num2str(k),' of ',num2str(length(imlist)),': ',nm])
    if exist(fullfile(outpth,nm),'file'); disp('  already done'); continue; end
    im0 = imread(fullfile(pth,nm));

    im = double(im0);
    
    if calc_style == 1
        img = rgb2gray(im0);
        img = img==255 | img==0;
        im(cat(3,img,img,img)) = NaN;
        fillval = squeeze(mode(mode(im,2),1))';
        ima = im(:,:,1); imb = im(:,:,2); imc = im(:,:,3);
        ima(img)=fillval(1); imb(img)=fillval(2); imc(img)=fillval(3);
        im = cat(3,ima,imb,imc);

        disp('H&E image')
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
    TA = N(TA+1);
    
    imwrite(TA,fullfile(outpth,nm));
    disp('  done');
end
end
