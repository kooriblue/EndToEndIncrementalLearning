imdbs_dir = '/home/GAIT_local/SSD/cifar100_incremental/'; % Edit me!
nets_dir = '/home/GAIT/experimentsInria/cifar100/'; % Edit me!

batchs = 20; % Number of classes per incremental step. Accepts array of sizes. Edit me!
nIters = 1; % Number of iterations with different class order. Edit me!

if ~exist('gpuId', 'var')
    gpuId = 2; % Gpu to execute the training. Edit me!
end

% Define opts.
opts.distillation_temp = 2; % Distillation temperature. Always 2.

% for training details
expDir = '/home/GAIT/experimentsInria/cifar100/' ; % Out path. Edit me!
opts.train.batchSize = 128;
opts.train.numSubBatches = 1 ;
opts.train.continue = true ;
opts.train.gpus = gpuId ;
opts.train.prefetch = false ;

opts.train.learningRate = [0.1*ones(1,10) 0.01*ones(1,10) 0.001*ones(1,10) 0.0001*ones(1,10)] ;
opts.train.numEpochs = length(opts.train.learningRate);

% Number of exemplars per class.
opts.nExemplarsClass = 0;
% Kind of selection: 0 random.
opts.kindSelection = 7;
% Max number of exemplars. It ignores opts.nExemplarsClass.
opts.maxExemplars = 2000; % Value of ICARL.
% For the output name.
fix = sprintf('Herding-%03d-%03d', opts.nExemplarsClass, opts.maxExemplars);

for nbatch_idx=1:length(batchs)
    nblocks = 100 / batchs(nbatch_idx);
    for niter_idx=1:nIters
        for nblock_idx=2:nblocks
            outpath = fullfile(expDir, sprintf('cifar-resnet-32-batch%02d-block%02d-iter%02d-%s', batchs(nbatch_idx), nblock_idx, niter_idx, fix), 'net-final.mat');
            if ~exist(outpath, 'file')
                if nblock_idx == 2
                    % Load initial network.
                    net_pattern = sprintf('cifar-resnet-32-batch%02d-block01-iter%02d', batchs(nbatch_idx), niter_idx);
                    net_name = 'net-epoch-100.mat';
                    imdb_pattern = sprintf('cifar-100-%02d-%02d-%02d.mat', batchs(nbatch_idx), nblock_idx-1, niter_idx);
                    
                    % Load imdb.
                    imdbPath = fullfile(imdbs_dir, imdb_pattern);
                    exemplars = load(imdbPath);
                    exemplars = exemplars.imdb;
                    
                    if ~isfield(exemplars.images, 'labels')
                        exemplars.images.labels = exemplars.images.classes;
                    end
                    
                    % Load net.
                    netPath = fullfile(nets_dir, net_pattern, net_name);
                    load(netPath);
                    net = dagnn.DagNN.loadobj(net);
                    
                    opts.net = net;
                    
                    % Build new exemplars set.
                    opts.totalClasses = batchs(nbatch_idx);
                    exemplars = build_exemplars_set([], exemplars, opts);
                else
                    net_pattern = sprintf('cifar-resnet-32-batch%02d-block%02d-iter%02d-%s', batchs(nbatch_idx), nblock_idx-1, niter_idx, fix);
                    net_name = 'net-final.mat';
                end
                imdb_pattern = sprintf('cifar-100-%02d-%02d-%02d.mat', batchs(nbatch_idx), nblock_idx, niter_idx);
                
                opts.newtaskdim = batchs(nbatch_idx);
                
                % Load net.
                netPath = fullfile(nets_dir, net_pattern, net_name);
                load(netPath);
                net = dagnn.DagNN.loadobj(net);
                
                % Load imdb.
                imdbPath = fullfile(imdbs_dir, imdb_pattern);
                load(imdbPath);
                
                % Train.
                if ~exist(fullfile(expDir, sprintf('cifar-resnet-32-batch%02d-block%02d-iter%02d-%s', batchs(nbatch_idx), nblock_idx, niter_idx, fix)), 'dir')
                    mkdir(fullfile(expDir, sprintf('cifar-resnet-32-batch%02d-block%02d-iter%02d-%s', batchs(nbatch_idx), nblock_idx, niter_idx, fix)));
                end
                opts.train.expDir = fullfile(expDir, sprintf('cifar-resnet-32-batch%02d-block%02d-iter%02d-%s', batchs(nbatch_idx), nblock_idx, niter_idx, fix));
                exemplars_ = exemplars;
                [net, info, meta, exemplars] = incremental_training(net, imdb, exemplars, opts);
                
                % Save model.
                disp('Saving model...');
                outpath = fullfile(expDir, sprintf('cifar-resnet-32-batch%02d-block%02d-iter%02d-%s', batchs(nbatch_idx), nblock_idx, niter_idx, fix), 'net-final.mat');
                save(outpath, 'net', 'info', 'meta', 'exemplars');      
            else
                fprintf('%s already exists. \n', outpath)
            end
        end
    end
end
