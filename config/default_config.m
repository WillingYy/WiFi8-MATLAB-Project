function cfg = default_config()
% DEFAULT_CONFIG  Unified configuration for WiFi8-MATLAB-Project.
% Base MATLAB only; no paid toolbox required.

cfg.numAPs        = 3;
cfg.seedArrival   = 101;
cfg.seedAccess    = 202;

cfg.Tsim          = 1000;   % total simulation time
cfg.Twarmup       = 100;    % warm-up (excluded from delay/goodput stats)
cfg.Tdata         = 1.0;    % fixed packet transmission time
cfg.Tctrl         = 0.1;    % fixed coordination control time
cfg.Tslot         = 1.0;    % slot length for random-access baseline
cfg.packetBits    = 12000;  % fixed payload bits per packet

cfg.lambda        = [0.25 0.25 0.25]; % per-AP Poisson arrival rate
cfg.policy        = 'random';         % 'random' | 'rr' | 'queue'

cfg.graphEdges    = [1 2; 2 3];       % undirected conflict edges
cfg.maxConcurrentAPs = 2;             % cap on simultaneous APs in one decision
cfg.snapshotTime  = 'before_ctrl';    % 'before_ctrl' | 'after_ctrl'
cfg.delayEndpoint = 'enqueue_to_completion';
cfg.measureMode   = 'windowCompletion'; % reserved for future extension
cfg.quantileMethod = 'linear';

% Simplified random-access baseline
cfg.attemptProb   = 0.50;   % Bernoulli attempt probability per slot
cfg.backoffMax    = 5;      % max random backoff in slots after failure
end