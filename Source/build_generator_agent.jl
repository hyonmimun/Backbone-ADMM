function build_generator_agent!(mod::Model)
    # Extract sets
    JH = mod.ext[:sets][:JH]

    # Extract time series data
    AC = mod.ext[:timeseries][:AC]

    # Extract parameters
    A = mod.ext[:parameters][:A] 
    B = mod.ext[:parameters][:B]  
    λ_EOM = mod.ext[:parameters][:λ_EOM] # EOM prices
    g_bar = mod.ext[:parameters][:g_bar] # element in ADMM penalty term related to EOM
    ρ_EOM = mod.ext[:parameters][:ρ_EOM] # rho-value in ADMM related to EOM auctions

    #cfd_capacity = mod.ext[:parameters][:cfd_capacity] # CfD capacity factor
    cfd_strike = mod.ext[:parameters][:cfd_strike]
    cfd_volume = mod.ext[:parameters][:cfd_volume] # CfD volume, if applicable

    # Create variables
    g = mod.ext[:variables][:g] = @variable(mod, [jh=JH], lower_bound=0, base_name="generation")

    #Expressions
    market_revenue = mod.ext[:expressions][:revenue] = @expression(mod, [jh in JH], λ_EOM[jh] * (g[jh]- cfd_volume[jh])) # Revenue from selling energy to the grid
    cfd_revenue = mod.ext[:expressions][:cfd_revenue] = @expression(mod, [jh in JH], ((cfd_strike - λ_EOM[jh]) * cfd_volume[jh]) : 0) # Revenue from CfD if applicable
    total_revenue = mod.ext[:expressions][:total_revenue] = @expression(mod, [jh in JH], market_revenue[jh] .+ cfd_revenue[jh]) # Total revenue
     

    # Objective 
    mod.ext[:objective] = @objective(mod, Min,
        + sum(A/2*g[jh]^2 for jh in JH)
        + sum(B*g[jh] for jh in JH)
        - sum(λ_EOM[jh]*g[jh] for jh in JH) #minimizing total cost of energy generation
        + sum(ρ_EOM/2*(g[jh] - g_bar[jh])^2 for jh in JH)
    )

    mod.ext[:constraints][:cap_limit] = @constraint(mod, [jh=JH],
        g[jh] <=  AC[jh]
    )

    return mod
end