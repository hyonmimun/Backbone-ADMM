function define_consumer_parameters!(mod::Model, data::Dict, ts::Dict, market_design::AbstractString, results::Dict)
    
    nT = data["nTimesteps"]
    nR = data["nReprDays"]
    nY = data["nYears"]
    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year

    # Parameters - note consumers are rescaled (total number of consumers x share of this type of consumer)
    D_profile = data["totConsumers"]*data["Share"].*
    [ts[jy][!,Symbol(data["D"])][idx(jy,jd,jh)] for jh=1:nT, jd=1:nR, jy=1:nY] # demand profile for segment

    D_PV = data["totConsumers"]*data["Share"]*data["PV_cap"].*
    [ts[jy][!,Symbol(data["PV_AF"])][idx(jy,jd,jh)] for jh=1:nT, jd=1:nR, jy=1:nY]
    
    D_system = [ts[jy][!,:LOAD][idx(jy,jd,jh)] for jh=1:nT, jd=1:nR, jy=1:nY]
    
    base_demand = D_profile .* D_system # total demand of the consumer segment based on system load
    
    mod.ext[:timeseries][:D_profile] = D_profile
    mod.ext[:timeseries][:PV] = D_PV
    mod.ext[:timeseries][:D_system] = D_system

    mod.ext[:timeseries][:D] = base_demand # Store the total demand profile of segment
    @assert length(mod.ext[:timeseries][:D]) == nT*nR*nY

    mod.ext[:parameters][:D_fixed] = 0.8 .* base_demand # Fixed demand (80%)
    mod.ext[:parameters][:D_ELA_max] = 0.2 .* base_demand # Elastic demand (20%)
    mod.ext[:parameters][:WTP] = data["WTP"]  # Willingness to pay

    # Battery parameters
    mod.ext[:parameters][:cap_smax] = data["Battery"]["cap_smax"]  # Battery capacity
    mod.ext[:parameters][:EC] = data["Battery"]["EC"]  # Charging efficiency
    mod.ext[:parameters][:ED] = data["Battery"]["ED"]  # Discharging efficiency
    mod.ext[:parameters][:Decay] = data["Battery"]["Decay"]  # Hourly decay
    mod.ext[:parameters][:winj] = data["Battery"]["winj"]  # Max charging power
    mod.ext[:parameters][:wwith] = data["Battery"]["wwith"]  # Max discharging power

    if market_design == "CfD"
        # CfD parameters
        mod.ext[:parameters][:λ_cfd] = data["lambda_cfd"] # €/MWh (strike price)
        mod.ext[:parameters][:g_cfd] = zeros(data["nTimesteps"]) # generation under CfD
        mod.ext[:parameters][:g_cfd_total] = zeros(data["nTimesteps"]) # total generation under CfD
        if haskey(results, "Q_cfd_con_tot") && length(results["Q_cfd_con_tot"]) > 0
                mod.ext[:parameters][:Q_cfd_con_tot] = results["Q_cfd_con_tot"][end]
        else
            mod.ext[:parameters][:Q_cfd_con_tot] = 1
        end
    end
    return mod
end