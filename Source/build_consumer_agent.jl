function build_consumer_agent!(mod::Model,market_design::AbstractString)
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

    # Create variables
    g = mod.ext[:variables][:g] = @variable(mod, [jh=JH], base_name="generation")  # positive if consumer feeds power to the rest of the system, negative when taking power from the grid
    D_ELA = mod.ext[:variables][:D_ELA] = @variable(mod, [jh=JH], lower_bound=0, base_name="elastic demand")
    SOC = mod.ext[:variables][:SOC] = @variable(mod, [jh=JH], lower_bound=0, upper_bound = cap_smax, base_name="SOC") # state of charge battery
    charge = mod.ext[:variables][:charge] = @variable(mod, [jh=JH], lower_bound=0, upper_bound= winj, base_name="charge")
    discharge = mod.ext[:variables][:discharge] = @variable(mod, [jh=JH], lower_bound=0, upper_bound = wwith, base_name="discharge")

    # Create affine expressions
    utility_term = mod.ext[:expressions][:utility_term] = @expression(mod, [jh in JH], WTP * D_ELA[jh] - (WTP / (2 * D_ELA_max[jh])) * D_ELA[jh]^2)
    
    # Build objective function
    objective_consumer =            
        - sum(λ_EOM[jh]*g[jh] for jh in JH)
        + sum(ρ_EOM/2*(g[jh] - g_bar[jh])^2 for jh in JH)
        - sum(utility_term[jh] for jh in JH)

    if market_design == "CfD"
        
        # CfD variables
        Q_cfd_con = mod.ext[:variables][:Q_cfd_con] = @variable(mod, lower_bound=0, base_name="CfD_contracted_capacity") # CfD contracted capacity [MW]

        # CfD parameters
        λ_cfd = mod.ext[:parameters][:λ_cfd]  # €/MWh (strike price)
        ζ_cfd = mod.ext[:parameters][:ζ_cfd]  # €/MWh (CfD contract premium)
        g_cfd_total = mod.ext[:parameters][:g_cfd_total] # Total generation of all generators under CfD
        Q_cfd_bar = mod.ext[:parameters][:Q_cfd_bar] # Average CfD contracted capacity across all agents [MW]
        ρ_CfD = mod.ext[:parameters][:ρ_cfd] # rho-value in ADMM related to CfD auctions
        Q_cfd_con_tot = mod.ext[:parameters][:Q_cfd_con_tot] # Total CfD contracted capacity of all consumers

        # CfD expressions
        share_cfd_con =  mod.ext[:expressions][:share_cfd_con] = @expression(mod, Q_cfd_con / Q_cfd_con_tot)
        cfd_payout = mod.ext[:expressions][:cfd_payout] = @expression(mod, [jh in JH], share_cfd_con * (λ_EOM[jh] - λ_cfd) * g_cfd_total[jh])
        cfd_premium = mod.ext[:expressions][:cfd_premium] = @expression(mod, ζ_cfd * Q_cfd_con)
        cfd_penalty_con = mod.ext[:expressions][:cfd_penalty_con] = @expression(mod, ρ_CfD/2 * (Q_cfd_con - Q_cfd_bar)^2)
        
        # CfD objective adjustments
        objective_consumer -= sum(cfd_payout[jh] for jh in JH)
        objective_consumer += cfd_premium
        objective_consumer += cfd_penalty_con

    end
    
    mod.ext[:objective] = @objective(mod, Min, objective_consumer)
    
    # Energy balance
    mod.ext[:constraints][:energy_balance] = @constraint(mod, [jh in JH],
    g[jh] == - D_fixed[jh] - D_ELA[jh] + PV[jh] - charge[jh] + discharge[jh]
    )
    mod.ext[:constraints][:D_fixed] = @constraint(mod, [jh in JH],
    D_fixed[jh] >= 0 # Fixed demand cannot be negative
    )
    mod.ext[:constraints][:D_ELA] = @constraint(mod, [jh in JH],
    D_ELA[jh] <= D_ELA_max[jh] # Fixed demand cannot be negative
    )
    # Battery model 
    mod.ext[:constraints][:state_of_charge] = @constraint(mod, [t in 2:length(JH)],
    SOC[JH[t]] == SOC[JH[t-1]] * Decay + charge[JH[t-1]] * EC - discharge[JH[t-1]] / ED
    )
    mod.ext[:constraints][:initial_SOC] = @constraint(mod, SOC[JH[1]] == 0
    )
    mod.ext[:constraints][:discharge] = @constraint(mod, [jh in JH],
        discharge[jh] <= SOC[jh] # Discharge cannot exceed state of charge adjusted for efficiency
    )

    #mod.ext[:constraints][:PV_battery_charge] = @constraint(mod, [jh in JH], charge[jh] <= PV[jh]) # Battery can only charge from PV production 

    # find peak 
    # peak greater than g[jh]
    # peak greather than 0

    return mod
end