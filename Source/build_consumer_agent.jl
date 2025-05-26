function build_consumer_agent!(mod::Model)
    # Extract sets
    JH = mod.ext[:sets][:JH]

    # Extract time series data
    D = mod.ext[:timeseries][:D] 
    PV = mod.ext[:timeseries][:PV] 

    # Extract parameters
    λ_EOM = mod.ext[:parameters][:λ_EOM] # EOM prices
    g_bar = mod.ext[:parameters][:g_bar] # element in ADMM penalty term related to EOM
    ρ_EOM = mod.ext[:parameters][:ρ_EOM] # rho-value in ADMM related to EOM auctions
    D_fixed = mod.ext[:parameters][:D_fixed]  # Fixed demand (80%)
    WTP = mod.ext[:parameters][:WTP]  # Willingness to pay
    D_ELA_max = mod.ext[:parameters][:D_ELA_max]  # Max elastic demand

    # Battery parameters
    cap_smax = mod.ext[:parameters][:cap_smax] # Battery capacity
    EC = mod.ext[:parameters][:EC] # Charging efficiency
    ED = mod.ext[:parameters][:ED] # Discharging efficiency
    Decay = mod.ext[:parameters][:Decay] # Hourly decay
    winj = mod.ext[:parameters][:winj] # Max charging power
    wwith = mod.ext[:parameters][:wwith] # Max discharging power

    # CfD parameters
    cfd_share = mod.ext[:parameters][:cfd_share] # 60% of total demand hedged
    cfd_strike_price = mod.ext[:parameters][:cfd_strike_price]  # €/MWh (strike price)

    # Create variables
    g = mod.ext[:variables][:g] = @variable(mod, [jh=JH], base_name="generation")  # positive if consumer feeds power to the rest of the system
    D_ELA = mod.ext[:variables][:D_ELA] = @variable(mod, [jh=JH], base_name="elastic demand")
    SOC = mod.ext[:variables][:SOC] = @variable(mod, [jh=JH], base_name="SOC") # state of charge
    charge = mod.ext[:variables][:charge] = @variable(mod, [jh=JH], base_name="charge") # charge
    discharge = mod.ext[:variables][:discharge] = @variable(mod, [jh=JH], base_name="discharge") # discharge
    #peak = mod.ext[:variables][:peak] = @variable(mod, base_name="peak_demand", lower_bound = 0 )  # peak demand

    # Create affine expressions 
    utility_term = mod.ext[:expressions][:utility_term] = @expression(mod, [jh in JH], WTP * D_ELA[jh] - (WTP / (2 * D_ELA_max[jh])) * D_ELA[jh]^2) #standard concave quadratic form
    D_CfD = mod.ext[:expressions][:D_CfD] = @expression(mod, [jh in JH], cfd_share * (D_fixed[jh] + D_ELA[jh])) # Share of demand hedged by CfD
    cfd_saving = mod.ext[:expressions][:cfd_saving] = @expression(mod, [jh in JH], (λ_EOM[jh] - cfd_strike_price) * D_CfD[jh]) # saved revenue by CfD

    # Objective 
    mod.ext[:objective] = @objective(mod, Min,
        - sum(λ_EOM[jh]*g[jh] for jh in JH) # minimizing total cost of energy from the grid
        + sum(ρ_EOM/2*(g[jh] - g_bar[jh])^2 for jh in JH)
        - sum(utility_term[jh] for jh in JH) # maximize consumer utility from elastic demand
        # + price_peak * peak 
    )

    # Energy balance
    mod.ext[:constraints][:energy_balance] = @constraint(mod, [jh in JH],
    g[jh] == -(D_fixed[jh] + D_ELA[jh] - PV[jh]) - charge[jh] + discharge[jh] # Grid-connected consumer energy balance, grid exchange exactly reflects necessary generation to meet total demand accounting for pv and battery
    ) 
    mod.ext[:constraints][:elastic_demand] = @constraint(mod, [jh in JH],
        D_ELA[jh] <= D_ELA_max[jh]
    )
    # Battery model 
    mod.ext[:constraints][:state_of_charge] = @constraint(mod, [t in 2:length(JH)],
    SOC[JH[t]] == SOC[JH[t-1]] * Decay + charge[JH[t-1]] * EC - discharge[JH[t-1]] / ED
    )
    mod.ext[:constraints][:PV_battery_charge] = @constraint(mod, [jh in JH], 
        charge[jh] <= PV[jh]) # Battery can only charge from PV production 
    mod.ext[:constraints][:min_SOC] = @constraint(mod, SOC[JH[1]] >= 0) # minimum state-of-charge; otherwise battery can store negative energy
    mod.ext[:constraints][:initial_SOC] = @constraint(mod, SOC[JH[1]] == 0.5 * cap_smax)
    mod.ext[:constraints][:max_SOC] = @constraint(mod, [jh in JH], SOC[jh] <= cap_smax) # Max state of charge
    mod.ext[:constraints][:max_charge] = @constraint(mod, [jh in JH], charge[jh] <= winj)  # Max charging power
    mod.ext[:constraints][:max_discharge] = @constraint(mod, [jh in JH], discharge[jh] <= wwith)  # Max discharging power 

    # find peak 
    # peak greater than g[jh]
    # peak greather than 0

    return mod
end