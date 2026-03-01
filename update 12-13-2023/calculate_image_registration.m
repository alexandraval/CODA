function calculate_image_registration(pth,IHC,zc,regE)
% Nonlinear registration of serial sections.
% Cross-platform update (macOS-safe path handling).
%
% REQUIRED INPUT:
%   pth: folder containing tif/tiff/jpg images to register.
% OPTIONAL INPUTS:
%   IHC: 1 for IHC, 0 for H&E (default 0)
%   zc:  reference image index (default center image)
%   regE: struct with fields szE, bfE, diE for elastic registration
%
% OUTPUTS:
%   pth/registered
%   pth/registered/elastic_registration
%   pth/registered/elastic_registration/check
%   pth/registered/elastic_registration/save_warps
%   pth/registered/elastic_registration/save_warps/D

if ~exist('regE','var') || isempty(regE)
    regE.szE = 251;
    regE.bfE = 200;
    regE.diE = 100;
end

addpath('image registration base functions');
warning('off','all');

if ~exist('IHC','var') || isempty(IHC)
    IHC = 0;
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

% keep outputs lossless for downstream RGB volume visualization
tpout = 'tif';

% find input images
imlist = dir(fullfile(pth,'*.tif'));
if isempty(imlist); imlist = dir(fullfile(pth,'*.tiff')); end
if isempty(imlist); imlist = dir(fullfile(pth,'*.jpg')); end
if isempty(imlist)
    disp('no images found');
    warning('on','all');
    return;
end
tp = imlist(1).name(end-2:end);

if ~exist('zc','var') || isempty(zc)
    zc = ceil(length(imlist)/2);
end

rf = [zc:-1:2 zc:length(imlist)-1 0];
mv = [zc-1:-1:1 zc+1:length(imlist)];

% max image size
szz = [0 0];
for kk = 1:length(imlist)
    inf = imfinfo(fullfile(pth,imlist(kk).name));
    szz = [max([szz(1),inf.Height]) max([szz(2),inf.Width])];
end

padall = 250;
if IHC == 1
    rsc = 2;
else
    rsc = 6;
end
iternum = 5;

% output folders
outpthG = fullfile(pth,'registered');
outpthE = fullfile(outpthG,'elastic_registration');
outpthE2 = fullfile(outpthE,'check');
matpth = fullfile(outpthE,'save_warps');
matpthD = fullfile(matpth,'D');

if ~isfolder(outpthG); mkdir(outpthG); end
if ~isfolder(outpthE); mkdir(outpthE); end
if ~isfolder(outpthE2); mkdir(outpthE2); end
if ~isfolder(matpth); mkdir(matpth); end
if ~isfolder(matpthD); mkdir(matpthD); end

% reference image
nm = imlist(zc).name(1:end-3);
[imzc,TAzc] = get_ims(pth,nm,tp,IHC);
[imzc,imzcg,TAzc] = preprocessing(imzc,TAzc,szz,padall,IHC);
disp(['Reference image: ',nm])

imwrite(imzc, fullfile(outpthG,[nm,tpout]));
imwrite(imzc, fullfile(outpthE,[nm,tpout]));
save(fullfile(matpth,[nm,'mat']),'zc');

img = imzcg; TA = TAzc;
img0 = imzcg; TA0 = TAzc; krf0 = zc;
img00 = imzcg; TA00 = TAzc; krf00 = zc;

for kk = 1:length(mv)
    t1 = tic;

    fprintf(['Image ',num2str(kk),' of ',num2str(length(imlist)-1),...
        '\n  reference image:  ',imlist(rf(kk)).name(1:end-4),...
        '\n  moving image:  ',imlist(mv(kk)).name(1:end-4),'\n']);

    nm = imlist(mv(kk)).name(1:end-3);
    [immv0,TAmv] = get_ims(pth,nm,tp,IHC);
    [immv,immvg,TAmv,fillval] = preprocessing(immv0,TAmv,szz,padall,IHC);

    if rf(kk)==zc
        imrfgA = img;  TArfA = TA;   krfA = zc;
        imrfgB = img0; TArfB = TA0;  krfB = krf0;
        imrfgC = img00;TArfC = TA00; krfC = krf00;
    end

    if exist(fullfile(matpthD,[nm,'mat']),'file')
        disp('   Registration already calculated');
        load(fullfile(matpth,[nm,'mat']),'tform','cent','f');
        immvGg = register_global_im(immvg,tform,cent,f,mode(immvg(:)));
        TAmvG  = register_global_im(TAmv,tform,cent,f,0);
    else
        RB = 0.4; RC = 0.4;
        if IHC==1; ct=0.8; else; ct=0.945; end

        [immvGg,tform,cent,f,R] = calculate_global_reg(imrfgA,immvg,rsc,iternum,IHC);
        if R<ct
            [immvGgB,tformB,centB,fB,RB] = calculate_global_reg(imrfgB,immvg,rsc,iternum,IHC);
        end
        if R<ct && RB<ct
            [immvGgC,tformC,centC,fC,RC] = calculate_global_reg(imrfgC,immvg,rsc,iternum,IHC);
        end

        RR = [R RB RC];
        [~,ii] = max(RR);
        if ii==1
            imrfg = imrfgA; TArf = TArfA; krf = krfA;
        elseif ii==2
            immvGg = immvGgB; tform = tformB; cent = centB; f = fB;
            imrfg = imrfgB; TArf = TArfB; krf = krfB;
        else
            immvGg = immvGgC; tform = tformC; cent = centC; f = fC;
            imrfg = imrfgC; TArf = TArfC; krf = krfC;
        end

        save(fullfile(matpth,[nm,'mat']),'tform','f','cent','szz','padall','krf');

        immvG = register_global_im(immv,tform,cent,f,fillval);
        TAmvG = register_global_im(TAmv,tform,cent,f,0);
        imwrite(immvG, fullfile(outpthG,[nm,tpout]));

        if exist(fullfile(matpthD,[nm,'mat']),'file')
            load(fullfile(matpthD,[nm,'mat']),'Dmv');
        else
            Dmv = calculate_elastic_registration(imrfg,immvGg,TArf,TAmvG,regE.szE,regE.bfE,regE.diE);
            if kk==1
                D=zeros(size(Dmv));
                save(fullfile(matpthD,[imlist(krf).name(1:end-3),'mat']),'D');
            end
        end

        load(fullfile(matpthD,[imlist(krf).name(1:end-3),'mat']),'D');
        D = D + Dmv;
        save(fullfile(matpthD,[nm,'mat']),'D','Dmv');

        D = imresize(D,size(immvG(:,:,1)));
        immvE = imwarp(immvG,D,'nearest','FillValues',fillval);

        imwrite(immvE, fullfile(outpthE,[nm,tpout]));
        imwrite(immvE(1:3:end,1:3:end,:), fullfile(outpthE2,[nm,tpout]));
    end

    % update reference chain
    imrfgC = imrfgB; TArfC = TArfB; krfC = krfB;
    imrfgB = imrfgA; TArfB = TArfA; krfB = krfA;
    imrfgA = immvGg; TArfA = TAmvG; krfA = mv(kk);
    if mv(kk)==mv(1); img0 = immvGg; TA0 = TAmvG; krf0 = mv(kk); end
    if length(mv) > 1 && mv(kk)==mv(2); img00 = immvGg; TA00 = TAmvG; krf00 = mv(kk); end

    toc(t1);
end

warning('on','all');
end
