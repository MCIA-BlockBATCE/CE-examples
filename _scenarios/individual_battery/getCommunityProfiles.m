function [Profiles] = getCommunityProfiles(selection)
% This function returns consumption profiles for 3 predefined communities
% depending on the ratio between consumption and generation (Surplus
% community, deficit community or balanced community)

%% Key for consumption profiles
% ADM = Administration building
% CAP = Medical building
% EDU = Academic building
% RES = Residential building
% RV = EV Recharging Point

% (1) ADM1, (2) ADM2, (3) ADM3, (4) CAP1, (5) CAP2, (6) CAP3,
% (7) EDU1, (8) EDU2, (9) EDU3, (10) RES1, (11) RES2, (12) RES3, (13) RV4

% CAP1, EDU1, EDU2, RES1, RES3, RV4
SurplusCommunity = [4 7 8 10 12 13];

% ADM1, ADM3, CAP1, CAP2, EDU1, RES1
DeficitCommunity = [1 3 4 5 7 10];

% ADM2, ADM3, EDU1, EDU2, RES3, RV4
BalancedCommunity = [2 3 7 8 12 13];

%% Case selection

if ( selection == 0)
    Profiles = SurplusCommunity;
elseif ( selection == 1)
    Profiles = DeficitCommunity;
elseif ( selection == 2)
    Profiles = BalancedCommunity;
end

end

