function DE_demo()
    % Create main GUI window
    fig = uifigure('Name', 'Image Detail Enhancement Based on PIMO Projection Iterative Optimization', 'Position', [100 100 900 600]);

    % Create control buttons
    btnLoad = uibutton(fig, 'push', ...
        'Text', 'Load Single Image', ...
        'Position', [30 550 100 30], ...
        'ButtonPushedFcn', @(btn,event) loadImage());
    
    btnLoadDataset = uibutton(fig, 'push', ...
        'Text', 'Load Dataset', ...
        'Position', [150 550 100 30], ...
        'ButtonPushedFcn', @(btn,event) loadDataset());
    
    btnProcessDataset = uibutton(fig, 'push', ...
        'Text', 'Batch Enhancement', ...
        'Position', [270 550 120 30], ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(btn,event) processDataset());

    btnSave = uibutton(fig, 'push', ...
        'Text', 'Save Enhanced Image', ...
        'Position', [410 550 120 30], ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(btn,event) saveEnhancedImage());

    % Create image display areas
    axOriginal = uiimage(fig, 'Position', [30 200 400 280], 'ScaleMethod', 'fit');
    uilabel(fig, 'Text', 'Original Image', 'Position', [180 170 100 20], 'HorizontalAlignment', 'center');
    
    axEnhanced = uiimage(fig, 'Position', [470 200 400 280], 'ScaleMethod', 'fit');
    uilabel(fig, 'Text', 'PIMO Enhanced Image', 'Position', [620 170 100 20], 'HorizontalAlignment', 'center');

    % Create metric labels
    lblPSNR = uilabel(fig, 'Text', 'PSNR: --', 'Position', [470 140 300 20], 'FontWeight', 'bold');
    lblSSIM = uilabel(fig, 'Text', 'SSIM: --', 'Position', [470 110 300 20], 'FontWeight', 'bold');
    lblTime = uilabel(fig, 'Text', 'Time: --', 'Position', [470 80 300 20], 'FontWeight', 'bold');
    
    lblDatasetInfo = uilabel(fig, 'Text', 'Dataset: Not loaded', 'Position', [30 150 350 20], 'FontWeight', 'bold');
    lblDatasetStats = uilabel(fig, 'Text', 'Average Metrics: PSNR: -- dB, SSIM: --', ...
        'Position', [30 120 400 20], 'FontWeight', 'bold');
    lblDatasetTime = uilabel(fig, 'Text', 'Time: --', 'Position', [30 95 500 20], 'FontWeight', 'bold');
    
    lblAlgorithm = uilabel(fig, ...
        'Text', 'Algorithm: PIMO Projection Iterative Method', ...
        'Position', [30 80 250 20], ...
        'FontWeight', 'bold', ...
        'FontColor', [0.2 0.4 0.8]);

    uilabel(fig, ...
        'Text', 'Copyright@China University of Mining and Technology, Intelligent Detection and Pattern Recognition Institute', ...
        'FontSize', 10, ...
        'Position', [600 570 280 20], ...
        'HorizontalAlignment', 'right', ...
        'FontAngle', 'italic');

    % Shared state variables
    originalImage = [];
    enhancedImage = [];
    datasetPath = '';
    imageFiles = [];
    datasetResults = [];
    outputFolder = '';

    function loadImage()
        % Load and enhance a single image
        [file, path] = uigetfile({'*.jpg;*.png;*.bmp;*.tif','Image Files'});
        if isequal(file,0), return; end
        
        imgPath = fullfile(path, file);
        originalImage = imread(imgPath);
        
        if size(originalImage,3) == 1
            rgbImage = repmat(originalImage, [1 1 3]);
        else
            rgbImage = originalImage;
        end
        axOriginal.ImageSource = rgbImage;

        d = uiprogressdlg(fig, ...
            'Title', 'PIMO Algorithm Processing', ...
            'Message', 'Enhancing image details...');

        d.Value = 0.3;
        tOne = tic;
        enhancedImage = pimo_enhance_process(rgbImage);
        tOneSec = toc(tOne);
        
        d.Value = 0.8;
        axEnhanced.ImageSource = enhancedImage;

        psnrVal = calculatePSNR_Y(enhancedImage, rgbImage);
        ssimVal = calculateSSIM_Y(enhancedImage, rgbImage);
        
        lblPSNR.Text = sprintf('PSNR: %.2f dB', psnrVal);
        lblSSIM.Text = sprintf('SSIM: %.4f', ssimVal);
        lblTime.Text = sprintf('Time: %.3f s', tOneSec);
        
        btnSave.Enable = 'on';
        
        d.Value = 1.0;
        d.Message = 'PIMO Enhancement Completed';
        pause(0.5);
        close(d);
    end

    function loadDataset()
        % Load dataset folder and initialize result buffers
        datasetPath = uigetdir('', 'Select Dataset Folder');
        if isequal(datasetPath, 0), return; end
        
        imageFiles = dir(fullfile(datasetPath, '*.jpg'));
        imageFiles = [imageFiles; dir(fullfile(datasetPath, '*.png'))];
        imageFiles = [imageFiles; dir(fullfile(datasetPath, '*.bmp'))];
        imageFiles = [imageFiles; dir(fullfile(datasetPath, '*.tif'))];
        
        if isempty(imageFiles)
            uialert(fig, 'No image files found!', 'Error');
            return;
        end
        
        outputFolder = fullfile(datasetPath, 'EnhancedImages');
        if ~exist(outputFolder, 'dir')
            mkdir(outputFolder);
        end
        
        lblDatasetInfo.Text = sprintf('Dataset: %s (%d images)', datasetPath, length(imageFiles));
        btnProcessDataset.Enable = 'on';
        
        datasetResults = struct();
        datasetResults.psnr_values = zeros(length(imageFiles), 1);
        datasetResults.ssim_values = zeros(length(imageFiles), 1);
        datasetResults.processed_count = 0;
        datasetResults.time_values = zeros(length(imageFiles), 1);
        datasetResults.total_time = 0;
        
        uialert(fig, sprintf('Successfully loaded %d images', length(imageFiles)), 'Dataset Loaded');
    end

    function processDataset()
        % Process all images in the selected dataset
        if isempty(imageFiles)
            uialert(fig, 'Please load a dataset first!', 'Error');
            return;
        end
        
        progressDlg = uiprogressdlg(fig, 'Title', 'Batch Processing Dataset', ...
            'Message', 'Processing...');
        
        totalImages = length(imageFiles);
        tBatch = tic;
        
        for i = 1:totalImages
            try
                progressDlg.Message = sprintf('Processing image %d/%d: %s', i, totalImages, imageFiles(i).name);
                progressDlg.Value = i/totalImages;
                
                imgPath = fullfile(datasetPath, imageFiles(i).name);
                originalImg = imread(imgPath);
                
                if size(originalImg,3) == 1
                    rgbImg = repmat(originalImg, [1 1 3]);
                else
                    rgbImg = originalImg;
                end
                
                tImg = tic;
                enhancedImg = pimo_enhance_process(rgbImg);
                tImgSec = toc(tImg);
                datasetResults.time_values(i) = tImgSec;
                datasetResults.total_time = datasetResults.total_time + tImgSec;
                
                psnrVal = calculatePSNR_Y(enhancedImg, rgbImg);
                ssimVal = calculateSSIM_Y(enhancedImg, rgbImg);
                
                datasetResults.psnr_values(i) = psnrVal;
                datasetResults.ssim_values(i) = ssimVal;
                datasetResults.processed_count = datasetResults.processed_count + 1;
                
                [~, name, ext] = fileparts(imageFiles(i).name);
                outputPath = fullfile(outputFolder, [name '_enhanced' ext]);
                imwrite(enhancedImg, outputPath);
                
                if i == 1
                    originalImage = rgbImg;
                    enhancedImage = enhancedImg;
                    axOriginal.ImageSource = rgbImg;
                    axEnhanced.ImageSource = enhancedImg;
                    lblPSNR.Text = sprintf('PSNR: %.4f dB', psnrVal);
                    lblSSIM.Text = sprintf('SSIM: %.5f', ssimVal);
                end
                
            catch ME
                warning('Error processing image %s: %s', imageFiles(i).name, ME.message);
                datasetResults.psnr_values(i) = 0;
                datasetResults.ssim_values(i) = 0;
            end
        end
        
        totalTime = toc(tBatch);
        
        valid_psnr = datasetResults.psnr_values(datasetResults.psnr_values > 0);
        valid_ssim = datasetResults.ssim_values(datasetResults.psnr_values > 0);
        
        if ~isempty(valid_psnr)
            avg_psnr = mean(valid_psnr);
            avg_ssim = mean(valid_ssim);
            valid_time = datasetResults.time_values(datasetResults.psnr_values > 0);
            avg_time = mean(valid_time);
            
            lblDatasetStats.Text = sprintf('Average Metrics: PSNR: %.4f dB, SSIM: %.5f (Total: %d images)', ...
                avg_psnr, avg_ssim, length(valid_psnr));
            lblDatasetTime.Text = sprintf('Time: Total %.3f s (approx. %.2f min), Average %.3f s per image', ...
                totalTime, totalTime/60, avg_time);
            
            resultMsg = sprintf(['Batch processing completed!\n\nAverage PSNR: %.4f dB\nAverage SSIM: %.5f\n' ...
                'Average time: %.3f s/image\nTotal time: %.3f s (approx. %.2f min)\n\n' ...
                'Successfully processed: %d/%d images\nOutput folder: %s'], ...
                avg_psnr, avg_ssim, avg_time, totalTime, totalTime/60, ...
                length(valid_psnr), totalImages, outputFolder);
            
            uialert(fig, resultMsg, 'Processing Complete');
            saveResultsToFile(valid_psnr, valid_ssim, valid_time, totalTime, outputFolder);
        else
            uialert(fig, 'All images failed to process!', 'Error');
        end
        
        close(progressDlg);
        btnSave.Enable = 'on';
    end

    function saveResultsToFile(psnr_vals, ssim_vals, time_vals, total_time, folder)
        % Save evaluation results in txt/csv/mat formats
        resultsFile = fullfile(folder, 'enhancement_results.txt');
        fid = fopen(resultsFile, 'w');
        
        if fid == -1, return; end
        
        fprintf(fid, 'PIMO Image Enhancement Results Summary\n');
        fprintf(fid, '====================\n\n');
        fprintf(fid, 'Processing time: %s\n', datestr(now));
        fprintf(fid, 'Total images: %d\n', length(psnr_vals));
        fprintf(fid, 'Average PSNR: %.4f dB\n', mean(psnr_vals));
        fprintf(fid, 'Average SSIM: %.5f\n\n', mean(ssim_vals));
        
        fprintf(fid, 'Detailed results:\n');
        fprintf(fid, 'Index\tPSNR(dB)\tSSIM\t\tTime(s)\n');
        fprintf(fid, '----\t--------\t----\t\t-------\n');
        
        for i = 1:length(psnr_vals)
            fprintf(fid, '%d\t%.2f\t\t%.4f\t\t%.4f\n', i, psnr_vals(i), ssim_vals(i), time_vals(i));
        end
        
        fclose(fid);

        T = table((1:length(psnr_vals))', psnr_vals(:), ssim_vals(:), time_vals(:), ...
            'VariableNames', {'index','psnr_db','ssim','time_sec'});
        writetable(T, fullfile(folder, 'enhancement_results.csv'));

        results = struct();
        results.psnr_values = psnr_vals;
        results.ssim_values = ssim_vals;
        results.time_values = time_vals;
        results.total_time = total_time;
        results.timestamp = now;
        save(fullfile(folder, 'enhancement_results.mat'), 'results');
    end

    function saveEnhancedImage()
        % Save the current enhanced image
        if isempty(enhancedImage)
            uialert(fig, 'Please load and process an image first.', 'Hint');
            return;
        end
        [file, path] = uiputfile({'*.png','PNG Image'}, 'Save Enhanced Image');
        if isequal(file,0), return; end
        imwrite(enhancedImage, fullfile(path, file));
        uialert(fig, 'Image saved successfully!', 'Success');
    end

    function out = pimo_enhance_process(in)
        % Run channel-wise PIMO enhancement and fuse details back
        factor = 4;
        
        out1 = double(in(:,:,1));
        out2 = double(in(:,:,2));
        out3 = double(in(:,:,3));
        
        H1_outimg1 = PIMO_parfor(out1);             
        H1_outimg2 = PIMO_parfor(out2); 
        H1_outimg3 = PIMO_parfor(out3);
        
        Details = zeros(size(in,1), size(in,2), 3);
        Details(:,:,1) = imresize(H1_outimg1, [size(in,1), size(in,2)], 'bilinear');
        Details(:,:,2) = imresize(H1_outimg2, [size(in,1), size(in,2)], 'bilinear');
        Details(:,:,3) = imresize(H1_outimg3, [size(in,1), size(in,2)], 'bilinear');
        
        out1 = out1 + Details(:,:,1) * factor;
        out2 = out2 + Details(:,:,2) * factor;
        out3 = out3 + Details(:,:,3) * factor;
        
        out1 = max(min(out1, 255), 0);
        out2 = max(min(out2, 255), 0);
        out3 = max(min(out3, 255), 0);
        
        out = uint8(cat(3, out1, out2, out3));
    end

    function psnr_val = calculatePSNR_Y(test_img, ref_img)
        % Compute PSNR on the Y channel
        ref_ycbcr = rgb2ycbcr(ref_img);
        test_ycbcr = rgb2ycbcr(test_img);
        
        ref_y = ref_ycbcr(:, :, 1);
        test_y = test_ycbcr(:, :, 1);
        
        psnr_val = psnr(test_y, ref_y);
    end

    function ssim_val = calculateSSIM_Y(test_img, ref_img)
        % Compute SSIM on the Y channel
        ref_ycbcr = rgb2ycbcr(ref_img);
        test_ycbcr = rgb2ycbcr(test_img);
        
        ref_y = ref_ycbcr(:, :, 1);
        test_y = test_ycbcr(:, :, 1);
        
        ssim_val = ssim(test_y, ref_y);
    end
end