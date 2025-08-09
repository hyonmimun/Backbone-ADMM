function define_generator_parameters!(mod::Model, data::Dict,ts::DataFrame, market_design::AbstractString)
    # Parameters 
    mod.ext[:parameters][:A] = data["a"]
    mod.ext[:parameters][:B] = data["b"]
    mod.ext[:parameters][:C] = data["C"]
    
    # Availability factors
    if haskey(data,"AF")
        mod.ext[:timeseries][:AF] = ts[!, data["AF"]]  # e.g., ts[!, "WIND_ONSHORE"]
        mod.ext[:timeseries][:AC] = data["C"]*ts[!,data["AF"]]  
    else
        mod.ext[:timeseries][:AF] = ones(data["nTimesteps"])  # Full availability (100%)
        mod.ext[:timeseries][:AC] = data["C"]*ones(data["nTimesteps"]) # C in config.yaml (data) is the capacity of the generator
    end
    
    #CfD parameters
    if market_design == "CfD"
        mod.ext[:parameters][:λ_cfd] = data["lambda_cfd"] # €/MWh (strike price)
        #mod.ext[:parameters][:Q_cfd_gen_tot] = Q_cfd_gen_tot
    end

    return mod
end