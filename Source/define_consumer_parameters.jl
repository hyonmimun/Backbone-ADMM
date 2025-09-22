function define_consumer_parameters!(mod::Model, data::Dict, ts::Dict, market_design::AbstractString, results::Dict)
       # Extract sets
    JY = mod.ext[:sets][:JY]
    JD = mod.ext[:sets][:JD]
    JH = mod.ext[:sets][:JH]

    nT = data["nTimesteps"]
    nR = data["nReprDays"]
    nY = data["nYears"]
    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year

    # Parameters - note consumers are rescaled (total number of consumers x share of this type of consumer)
    D_consumers = data["totConsumers"]*data["Share"].*
    [ts[jy][!,Symbol(data["D"])][idx(jy,jd,jh)] for jh=1:nT, jd=1:nR, jy=1:nY]/1000 # GW demand profile for segment

    D_PV = data["totConsumers"]*data["Share"]*data["PV_cap"].*
    [ts[jy][!,Symbol(data["PV_AF"])][idx(jy,jd,jh)]/1000 for jh=1:nT, jd=1:nR, jy=1:nY] # GWp

    mod.ext[:timeseries][:PV] = D_PV

    mod.ext[:timeseries][:D] = D_consumers # Store the total demand profile of segment

    mod.ext[:parameters][:D_fixed] = 0.8 .* D_consumers # Fixed demand (80%)
    mod.ext[:parameters][:D_ELA_max] = 0.2 .* D_consumers # Max elastic demand (20%)
    mod.ext[:parameters][:WTP] = data["WTP"] # 10^3 €/GW

    # Battery parameters
    mod.ext[:parameters][:cap_smax] = data["Battery"]["cap_smax"]  # Max battery capacity
    mod.ext[:parameters][:EC] = data["Battery"]["EC"]  # Charging efficiency
    mod.ext[:parameters][:ED] = data["Battery"]["ED"]  # Discharging efficiency
    mod.ext[:parameters][:Decay] = data["Battery"]["Decay"]  # Hourly decay
    mod.ext[:parameters][:winj] = data["Battery"]["winj"]  # Max charging power
    mod.ext[:parameters][:wwith] = data["Battery"]["wwith"]  # Max discharging power

    if market_design == "cfd"
        # cfd parameters
        mod.ext[:parameters][:λ_cfd] = data["lambda_cfd"] # 10^3 €/GWh (strike price)
        mod.ext[:parameters][:g_cfd_total] = zeros(nT,nR,nY) # total generation under cfd
        #mod.ext[:parameters][:Q_cfd_con_tot]
        
       #= if !haskey(mod.ext[:parameters], :Q_cfd_con_tot)
            mod.ext[:parameters][:Q_cfd_con_tot] =
                (haskey(results, "Q_cfd_con_tot") && !isempty(results["Q_cfd_con_tot"])) ?
                copy(last(results["Q_cfd_con_tot"])) : fill(1e-9, length(JY))
        end =#
    end
end
    return mod