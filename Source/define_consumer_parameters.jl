function define_consumer_parameters!(mod::Model, data::Dict,ts::DataFrame)
    # Parameters - note consumers are rescaled (total number of consumers x share of this type of consumer)
    mod.ext[:timeseries][:D] = data["totConsumers"]*data["Share"]*ts[!,data["D"]] # demand profile 
    mod.ext[:timeseries][:PV] = data["totConsumers"]*data["Share"]*data["PV_cap"]*ts[!,data["PV_AF"]] # pv profile 
    
    base_demand = data["totConsumers"] * data["Share"] * ts[!, data["D"]]  # Base demand profile
    mod.ext[:timeseries][:D] = base_demand  # Store the total demand profile
    
    # price elasticity parameters
    mod.ext[:parameters][:D_fixed] = 0.8 * base_demand # Fixed demand (80%)
    mod.ext[:parameters][:D_ELA_max] = 0.2 * base_demand # Elastic demand (20%)
    mod.ext[:parameters][:WTP] = data["WTP"]  # Willingness to pay

    # CfD parameters
    mod.ext[:parameters][:cfd_share] = data["cfd_share"]  # 60% of total demand hedged
    mod.ext[:parameters][:cfd_strike_price] = data["cfd_strike_price"]  # €/MWh (strike price)
    
    # Battery parameters
    mod.ext[:parameters][:cap_smax] = data["Battery"]["cap_smax"]  # Battery capacity
    mod.ext[:parameters][:EC] = data["Battery"]["EC"]  # Charging efficiency
    mod.ext[:parameters][:ED] = data["Battery"]["ED"]  # Discharging efficiency
    mod.ext[:parameters][:Decay] = data["Battery"]["Decay"]  # Hourly decay
    mod.ext[:parameters][:winj] = data["Battery"]["winj"]  # Max charging power
    mod.ext[:parameters][:wwith] = data["Battery"]["wwith"]  # Max discharging power
    return mod
end