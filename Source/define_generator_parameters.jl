function define_generator_parameters!(mod::Model, data::Dict,ts::Dict, market_design::AbstractString)
    nT = data["nTimesteps"]
    nR = data["nReprDays"]
    nY = data["nYears"]
    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year
    
    # Parameters 
    mod.ext[:parameters][:A] = data["a"]
    mod.ext[:parameters][:B] = data["b"]
    mod.ext[:parameters][:C] = data["C"]
    
    # Availability factors
    if haskey(data,"AF")
        availability_factor = [ts[jy][!,Symbol(data["AF"])][idx(jy,jd,jh)] for jh=1:nT, jd=1:nR, jy=1:nY]
        # e.g., ts[!, "WIND_ONSHORE"]
        mod.ext[:timeseries][:AF] = availability_factor
        mod.ext[:timeseries][:AC] = data["C"].*availability_factor
    else
        mod.ext[:timeseries][:AF] = ones(nT*nR*nY)  # Full availability (100%)
        mod.ext[:timeseries][:AC] = data["C"]*ones(nT*nR*nY) # C in config.yaml (data) is the capacity of the generator
    end
    
    #CfD parameters
    if market_design == "CfD"
        mod.ext[:parameters][:λ_cfd] = data["lambda_cfd"] # €/MWh (strike price)
        #mod.ext[:parameters][:Q_cfd_gen_tot] = Q_cfd_gen_tot
    end

    return mod
end