function define_EOM_parameters!(EOM::Dict,data::Dict,ts::Dict,scenario_overview_row::DataFrameRow,market_design::AbstractString, repr_days::Dict)
    nT = data["General"]["nTimesteps"]
    nR = data["General"]["nReprDays"]
    nY = data["General"]["nYears"]
    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # function to get the absolute timestep in the full timeseries given year, repr day and hour in repr day
    
    EOM["D"] = Array{Float64}(undef, nT, nR, nY)
    EOM["elasticity"] = Array{Float64}(undef, nT, nR, nY)
    EOM["W"] = Dict()
    
# timeseries
    for jy in keys(years)
        # timeseries: take the demand load for all hours in the representative days of a specific year: Take the load timeseries of that specific year and take the values for the hourly timesteps for all repr days: look timesteps up as the absolute 'hour' in the yearly timeseries.
        EOM["D"][:,:,jy] = [ts[jy][!,:LOAD][idx(jy, jd, jh)]/10^5 for jh=1:nT, jd=1:nR] # 10^2 GWh
        
        EOM["elasticity"][:,:,jy] = [ts[jy][!,:ELASTICITY_EL][idx(jy, jd, jh)]/10^5 for jh=1:nT, jd=1:nR] # 10^2 GWh

        # weights of representative days
        EOM["W"][jy] = Dict(jd => repr_days[jy][!,:weights][jd] for jd=1:nR)
    end

    return EOM
end