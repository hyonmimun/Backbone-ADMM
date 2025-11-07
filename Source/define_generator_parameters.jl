function define_generator_parameters!(mod::Model, data::Dict,ts::Dict, market_design::AbstractString)
    nT = data["nTimesteps"]
    nR = data["nReprDays"]
    nY = data["nYears"]

    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year
    
    # Parameters 
    #mod.ext[:parameters][:A] = data["a"] # high gas prices vector for years
    #if m == "GasTurbine"
    #mod.ext[:parameters][:B] = Dict(jg => data["b"][jg] for jg in JG) # two gas price scenarios
    #else 
    mod.ext[:parameters][:B] = data["b"]
    #end
    mod.ext[:parameters][:C] = data["C"] # capacity in GW
    
    # Availability factors
    if haskey(data,"AF")
        availability_factor = [ts[jy][!,Symbol(data["AF"])][idx(jy,jd,jh)] for jh=1:nT, jd=1:nR, jy=1:nY]
        # e.g., ts[!, "WIND_ONSHORE"]
        mod.ext[:timeseries][:AF] = availability_factor
        mod.ext[:timeseries][:AC] = data["C"].* availability_factor
    else
        mod.ext[:timeseries][:AF] = ones(nT,nR,nY)  # Full availability (100%)
        mod.ext[:timeseries][:AC] = data["C"] * ones(nT,nR,nY) # C in config.yaml (data) is the capacity of the generator
    end
    return mod
end