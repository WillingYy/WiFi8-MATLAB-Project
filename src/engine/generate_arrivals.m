function arrivalTrace = generate_arrivals(cfg)
% GENERATE_ARRIVALS  Independent Poisson arrivals per AP.
% Base MATLAB only; no toolbox required.
% Same trace is reused by all policies.

sArr = RandStream('mt19937ar', 'Seed', cfg.seedArrival);

arrivalTrace = struct();
arrivalTrace.times = cell(1, cfg.numAPs);
arrivalTrace.bits  = cell(1, cfg.numAPs);

for ap = 1:cfg.numAPs
    rate = cfg.lambda(ap);
    if rate <= 0
        arrivalTrace.times{ap} = [];
        arrivalTrace.bits{ap}  = [];
        continue;
    end

   
    t = 0;
    times = [];
    while true
        
        u = rand(sArr);
       
        inter_arrival = -log(1 - u) / rate; 
        t = t + inter_arrival;
        
        if t > cfg.Tsim
            break;
        end
        times = [times; t];
    end

    arrivalTrace.times{ap} = times;
    arrivalTrace.bits{ap}  = cfg.packetBits * ones(numel(times), 1);
end
end