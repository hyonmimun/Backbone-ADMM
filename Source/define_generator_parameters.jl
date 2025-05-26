function define_generator_parameters!(mod::Model, data::Dict,ts::DataFrame)
    # Parameters 
    mod.ext[:parameters][:A] = data["a"]
    mod.ext[:parameters][:B] = data["b"]
    mod.ext[:parameters][:C] = data["C"]
    
    # Availability factors
    if haskey(data,"AF")
        mod.ext[:timeseries][:AC] = data["C"]*ts[!,data["AF"]]  
    else
        mod.ext[:timeseries][:AC] = data["C"]*ones(data["nTimesteps"]) 
    end

    #CfD parameters
    #if haskey(data, "CfD")   
    mod.ext[:parameters][:cfd_strike] = data["CfD"]["CfD_strike"] # €/MWh (strike price)
    mod.ext[:parameters][:cfd_volume] = mod.ext[:timeseries][:AC] .* data["CfD"]["CfD_capacity"] #covered volume is equal to the CfD capacity factor times the available capacity
   # end

    return mod
end