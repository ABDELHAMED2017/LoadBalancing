clear all
close all
rand('seed',42); % meaning of life = 42


% This is the code to setup a simple layout for ITA 2014 load balancing
% simulations.

%In this code, we consider a square single macro cell with wrap around
%assumption.

% two-tiers
% single macro cell simulated with the only macro BS located in the center
% of the cell
% wrap around
% square region
% Tier 2 is the small cell BSs, they are located according to PPP. Density
% will be a parameter
% Users will be also located according to PPP, with another denstity
% parameter
% Tier distributions are independent
%
% Small cell ans MAcro cell locations and numbers are chosen once for the
% first frame and kept fixed.

% each frame corresponds to a new sample path for USER PPPs. ie. at each frame
% the number of points is chosen according to the Poisson distribution with
% parameter density*area, and then that many users are uniformly
% distributed in the area.

% parameters for layout----------------------------------------------------
cell_type = 'square9';
% Define the area
if(strcmp(cell_type,'square')) % uniform density of users as in ITA paper
    cell_side = 900; %in meters
    fprintf([num2str(cell_side) 'x' num2str(cell_side) ' square with Uniform UE density\n'])
elseif(strcmp(cell_type,'square9')) % hotspot in the middle as in journal submission
    cell_side = 900; %in meters
    MC_square_number = 1+1*sqrt(-1);
    hotspot_density_multiplier = 10;
    fprintf([num2str(cell_side) 'x' num2str(cell_side) ' square with hotspot (x' num2str(hotspot_density_multiplier)  ' relative UE density)\n']);
else
    missing_cell_type;
end

SC_relative_density = 20;% relative density wrt Macro (which is 1)
UE_relative_density = 2000;% relative density wrt Macro (which is 1) % ralted to the toal number of  users
% in Square scenario these many users will be uniformly distributed
% but in square9 scenario, hotspot_density_multiplier = h

% h/(9+h-1) of them will be uniformly distributed in the center small
% square.

% subgradient search parameters--------------------------------------------

%---------------------
% subgradient search parameters 
step_size_option = 1; % a_k = a/(b+k) % this step-size is bound to converge to optimal, though it might be slow
% for alpha = 1, a = 1, b = 0 and 10000 iterations seem to converge
% for alpha = 4, a = 1, b = 0 and 200000 iterations seem to converge

a = 1;
b = 0;
imax = 10000; %number of iterations

%step_size_option = 2 % Ozgun tried to implement the step-size suggested by Dilip for alpha = 4. 
%The specific values can be seen in the dual_subgradient_new.m code. This option does not converge. So there is a mismatch with how I understand and what Dilip wrote in the email/ inthe code etc.


% parameters for the randomized algorithm ---------------------------------

num_iter=1e4;     % maximum number of iterations for randomized switching algorithm
pi_selected = 0.1; % The selection should be using the results of choosing_pi.m curves. Pi selection depends on alpha, and probably number of users
pi_vec = pi_selected;
pi_label = cell(size(pi_vec,1),1);
for k=1:size(pi_vec(:,1)), pi_label{k} = ['\pi = ' num2str(pi_vec(k,1)) ]; end

%--------------------------------------------------------------------------

alpha = 4; % as in alpha fairness

%--------------------------------------------------------------------------

NumFrames = 1; % A frame corresponds to one layout.

%Power & Antenna & pathloss parameters-------------------------------------
MC_powerdBm = 46; %dBm
SC_powerdBm = 35; %dBm
Noise_powerdBm = -104; %dBM

MC_M = 100; % number of antennas at MC
SC_M = 10; % number of antennas at SC's

MC_S = 40; % beamforming setsize at MC
SC_S = 4;  % bemaforming setsize at SCs



fprintf(['Macro cell :  TXAs=' num2str(MC_M) ',  Users Served per RB=' num2str(MC_S) '\n']);
fprintf(['Small cells:  TXAs=' num2str(SC_M) ',  Users Served per RB=' num2str(SC_S) '\n']);
fprintf(['Densities:     Small Cells=' num2str(SC_relative_density) ',  UEs=' num2str(UE_relative_density) '\n']);
fprintf(['alpha-Fairness parameter: alpha=' num2str(alpha) '\n']);

PathlossModel = 'Simple';

if(strcmp(PathlossModel,'Caramannis'))
    MC_A = 34;
    MC_B = 40;
    SC_A = 37;
    SC_B = 30;
    shad_var = 8;%log normal shadowing deviation
    
    pm1 = MC_A;
    pm2 = MC_B;
    pm3 = SC_A;
    pm4 = SC_B;
    pm5 = shad_var;
elseif(strcmp(PathlossModel,'WINNER'))
    how_to_differentiate_tiers;
    
    pm1 = [];
    pm2 = [];
    pm3 = [];
    pm4 = [];
    pm5 = [];
elseif(strcmp(PathlossModel,'Simple'))
    MC_alpha = 3.5;
    MC_delta = 40;
    SC_alpha = 4;
    SC_delta = 40;
    
    pm1 = MC_alpha;
    pm2 = MC_delta;
    pm3 = SC_alpha;
    pm4 = SC_delta;
    pm5 = [];
else
    missing_pathloss_model;
end

%--------------------------------------------------------------------------

run_cvx = 0;
run_randomized = 1;
run_dual = 0;
run_max_PR = 1; %Max peak rate

%--------------------------------------------------------------------------

%%%%%%%%%%%%%% SET SIMULATION PARAMETERS BEFORE THIS LINE  %%%%%%%%%%%%%

MC_power = 10^(0.1*MC_powerdBm);
SC_power = 10^(0.1*SC_powerdBm);
Noise_power = 10^(0.1*Noise_powerdBm);

[cell_area,MC_location] = MC_related(cell_type,cell_side,MC_square_number);

SC_density = SC_relative_density/cell_area;
UE_density = UE_relative_density/cell_area;

%Small Cell Locations
%IMPORTANT: At each frame number of SC's might be different.
%SC_NumPoints(f) gives the number of SCs for the frame = f
if(strcmp(cell_type,'square'))
    frame_variant = 1;
    [SC_Locs, SC_NumPoints] =  PointPoissonProcess2D(cell_area,SC_density, frame_variant, cell_side, NumFrames);
elseif(strcmp(cell_type,'square9'))
    frame_variant = 0;
    [SC_Locs, SC_NumPoints] =  PointPoissonProcess2D(cell_area,SC_density, frame_variant, cell_side, NumFrames);
end

%pause
%UE Locations
%IMPORTANT: At each frame number of UE's might be different.
%UE_NumPoints(f) gives the number of UEs for the frame = f

if(strcmp(cell_type,'square'))
    frame_variant = 1;
    [UE_Locs, UE_NumPoints] =  PointPoissonProcess2D(cell_area,UE_density, frame_variant, cell_side, NumFrames);
elseif(strcmp(cell_type,'square9'))
    frame_variant = 1;
    [UE_Locs, UE_NumPoints] =  PointPoissonProcess2D(cell_area,UE_density, frame_variant, cell_side, NumFrames);
    %pause
    for frame = 1:NumFrames
        % frame = frame
        uni = round(8/(8+hotspot_density_multiplier)*UE_NumPoints(frame));
        hotspot = UE_NumPoints(frame)-uni;
        %update the locs of the initial hotspot many users to the center
        %square
        UE_Locs(frame, 1:hotspot) = cell_side/3+sqrt(-1)*cell_side/3+(rand(1,hotspot)+rand(1,hotspot)*sqrt(-1))*cell_side/3;
    end
end




% first BS is the MC
% the rest is the SC's
BS_Locs = [MC_location*ones(NumFrames,1) SC_Locs]; % eAch row corresponds to a frame. At ith frame, only the entries



DistanceM = BS_UE_Distance_Calculation(BS_Locs,UE_Locs, NumFrames,cell_side);


path_loss = Pathloss_Calculation(DistanceM,PathlossModel,pm1,pm2,pm3,pm4,pm5);


schedulable_rates_matrix = Massive_MIMO_rate_calculation(path_loss,MC_powerdBm, SC_powerdBm,Noise_powerdBm,SC_NumPoints,UE_NumPoints,DistanceM,NumFrames,MC_M,MC_S,SC_M,SC_S);
%schedulable_rates_matrix(DistanceM>80)=0;

cvx_elapsed_time = zeros(NumFrames,1);

activity_cvx = -52*ones(size(DistanceM)); % just initialization, -52 is just a random different than 0 or 1 to avoid possible bugs
activity_randomized = -52*ones(size(DistanceM)); % just initialization, -52 is just a random different than 0 or 1 to avoid possible bugs
activity_maxPR = -52*ones(size(DistanceM));

%this part takes too much memory, not necessary-------especially with large numbers-------------
% association_cvx = repmat(-52*ones(size(DistanceM)),[1 1 NumFrames]);



utility_cvx = zeros(NumFrames,1);
utility_randomized = zeros(NumFrames,1);
utility_dual = zeros(NumFrames,1);
utility_dual2 = zeros(NumFrames,1);
utility_maxPR = zeros(NumFrames,1);


rates_cvx = -63*ones(size(UE_Locs));  % just initialization, -63 is just a random different than 0 or 1 to avoid possible bugs
rates_randomized = -63*ones(size(UE_Locs));  % just initialization, -63 is just a random different than 0 or 1 to avoid possible bugs
rates_dual = -63*ones(size(UE_Locs));  % just initialization, -63 is just a random different than 0 or 1 to avoid possible bugs
rates_maxPR = -63*ones(size(UE_Locs));



howmany_frac_users_cvx = zeros(NumFrames,1);


threshold = 0.0001; % this is a threshold value used to ignore very small activity fractions found by any solver.
opt_rate_statistic=zeros(NumFrames,1);
rate_statistic_randomized= zeros(NumFrames,size(pi_vec,1));
rate_statistic_dual= zeros(NumFrames,1);

iterations_randomized= zeros(NumFrames,size(pi_vec,1));



for frame = 1:NumFrames
    tic
    fprintf(['Frame: ' num2str(frame) '/' num2str(NumFrames) '\n']);
    figure(1); clf,
    scatter(real(MC_location),imag(MC_location),'ks');
    hold all
    scatter(real(SC_Locs(frame,1:SC_NumPoints(frame))),imag(SC_Locs(frame,1:SC_NumPoints(frame))),'bo');
    scatter(real(UE_Locs(frame,1:UE_NumPoints(frame))),imag(UE_Locs(frame,1:UE_NumPoints(frame))),'r*');
    set(gca,'XLim',[0 cell_side]);
    set(gca,'YLim',[0 cell_side]);
    grid(gca);
    title(sprintf('Num. of SCs: %d  Num. of UEs: %d ',SC_NumPoints(frame),UE_NumPoints(frame)));
    schedulable_rates_matrix_frame = schedulable_rates_matrix(1:(SC_NumPoints(frame)+1),1:UE_NumPoints(frame),frame);
    DistanceM_frame = DistanceM(1:(SC_NumPoints(frame)+1),1:UE_NumPoints(frame),frame);
    %pause
    %close
    max_users_served = zeros(SC_NumPoints(frame)+1,1);
    max_users_served(1) = MC_S;
    max_users_served(2:SC_NumPoints(frame)+1) = SC_S;
    
    %==================================================================================================================
    if(run_cvx)
        %% ****CVX******
        
        [activity_cvx_frame,utility_cvx_frame, rates_cvx_frame, association_cvx_frame, frac_users_cvx_frame] = cvx_assoc_r(schedulable_rates_matrix_frame,SC_NumPoints(frame)+1,UE_NumPoints(frame),max_users_served,alpha, threshold);
        
        howmany_frac_users_cvx_frame = length(frac_users_cvx_frame);
        howmany_frac_users_cvx(frame) = howmany_frac_users_cvx_frame;
        rates_cvx(frame,1:UE_NumPoints(frame)) = rates_cvx_frame;
        activity_cvx(1:(SC_NumPoints(frame)+1),1:UE_NumPoints(frame),frame) = activity_cvx_frame;
        utility_cvx(frame) = utility_cvx_frame;
        %association_cvx(1:(SC_NumPoints(frame)+1),1:UE_NumPoints(frame),frame) = association_cvx_frame;
        opt_rate_statistic_frame = utility_value_to_rate_statistic(utility_cvx_frame, alpha, UE_NumPoints(frame));
        opt_rate_statistic(frame) =  opt_rate_statistic_frame;
    end
    %==================================================================================================================
    if(run_dual)
        % NEW Dual sub-gradient
        [L_term,utility_dual_frame,p_star, lambda_star,j_k_star] = dual_subgradient_new(schedulable_rates_matrix_frame,max_users_served,SC_NumPoints(frame)+1,UE_NumPoints(frame), a, b, imax,alpha,step_size_option);
        
        utility_dual(frame) = utility_dual_frame;
        %Solving for primal variables
        
        % user rate variables
        rates_dual_frame  = r_star(p_star, lambda_star, schedulable_rates_matrix_frame,SC_NumPoints(frame)+1,UE_NumPoints(frame),alpha);
        utility_dual2_frame = utility(rates_dual_frame,alpha);
        rates_dual(frame,1:UE_NumPoints(frame)) = rates_dual_frame;
        utility_dual2(frame) = utility_dual2_frame;
        
        rate_statistic_dual_frame = utility_value_to_rate_statistic(utility_dual_frame, alpha, UE_NumPoints(frame));
        rate_statistic_dual(frame) =  rate_statistic_dual_frame;
    end
    %==================================================================================================================
    if(run_randomized)
        utility_values_mat = NaN(size(pi_vec,1),num_iter);
        rate_statistic_mat=NaN(size(pi_vec,1),num_iter);
        
        figi=21; nmax=0;  figii=31;figiii=41; nterm_vec=zeros(size(pi_vec,1),1);
        
        uu = 1;
        fprintf(['Frame ' num2str(frame) '/' num2str(NumFrames) ': Randomized Algorithms with pi=' num2str(pi_vec(uu)) '\n']);
        
        [utility_values,activity_fractions_decent,long_term_rates,users_BS_assoc_indeces,switch_indicator,switching_users_flags] = user_centric_assoc(SC_NumPoints(frame)+1,UE_NumPoints(frame),schedulable_rates_matrix_frame,max_users_served,alpha,num_iter, pi_vec(uu));
        
        utility_values_mat(uu,1:length(utility_values)) = utility_values;
        rates_randomized(frame,1:UE_NumPoints(frame)) = long_term_rates(end,:);
        activity_randomized(1:(SC_NumPoints(frame)+1),1:UE_NumPoints(frame),frame) = activity_fractions_decent;
        utility_randomized(frame) = utility_values(end);
        
        rate_statistic_mat(uu,1:length(utility_values)) = utility_value_to_rate_statistic(utility_values, alpha, UE_NumPoints(frame));
        rate_statistic_randomized(frame,uu) = rate_statistic_mat(uu,length(utility_values));
        iterations_randomized(frame,uu) = length(utility_values);
       
        nterm_vec(uu)=length(utility_values);
        nmax = max(nmax, length(utility_values));
         
    end
    
    %=======================================================================     
    if(run_max_PR)
        bias_flag=0;
        [activity_maxPR_frame,User_Rates_maxPR_frame,utility_maxPR_frame, frac_users_maxPR_frame,association_maxPR_frame] = MAX_R_bias(bias_flag,SC_NumPoints(frame),UE_NumPoints(frame),schedulable_rates_matrix_frame,max_users_served,threshold,alpha);
        rates_maxPR(frame,1:UE_NumPoints(frame)) = User_Rates_maxPR_frame;
        activity_maxPR(1:(SC_NumPoints(frame)+1),1:UE_NumPoints(frame),frame) = activity_maxPR_frame;
        utility_maxPR(frame) = utility_maxPR_frame;
        
    end
    %close all
    
    %pause
    toc
    % pause
end

%filename depends on the pi value
filename = sprintf('NEW_alpha%d_celltype_%s_cellside%d_MCs%d+i%d_h%d_SC%d_UE%d_NF%d_MCP%d_SCP%d_NP%d_MCM%d_MCS%d_SCM%d_SCS%d_PLmodel_%s_pm1_%dpm2_%dpm3_%dpm4_%dpm5_%d_subgradient_a%d_b%d_imax%d_rand_pi%d.mat',alpha,cell_type,cell_side,real(MC_square_number),imag(MC_square_number),hotspot_density_multiplier,SC_relative_density,UE_relative_density,NumFrames,MC_powerdBm,SC_powerdBm,Noise_powerdBm,MC_M,MC_S,SC_M,SC_S,PathlossModel,pm1,pm2,pm3,pm4,pm5,a,b,imax,pi_vec(uu));
save(filename)


%
%

%
%
%

