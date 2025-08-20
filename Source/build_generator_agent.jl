function build_generator_agent!(mod::Model, market_design::AbstractString)
    # Extract sets
    JH = mod.ext[:sets][:JH]

    # Extract time series data
    AC = mod.ext[:timeseries][:AC] # Available capacity of the generator (MW)
    AF = mod.ext[:timeseries][:AF] # Availability factor for generation

    # Extract parameters
    A = mod.ext[:parameters][:A] 
    B = mod.ext[:parameters][:B]
    C = mod.ext[:parameters][:C] # Installed capacity of generator [MW]
    λ_EOM = mod.ext[:parameters][:λ_EOM] # EOM prices
    g_bar = mod.ext[:parameters][:g_bar] # average/consensus signal from EOM at timestep jh
    ρ_EOM = mod.ext[:parameters][:ρ_EOM] # rho-value in ADMM related to EOM auctions

    # Create variables
    g = mod.ext[:variables][:g] = @variable(mod, [jh=JH], lower_bound=0, base_name="generation")
    
    # Build objective expression
    objective_generator = mod.ext[:expressions][:objective_generator] = @expression(mod,
        + sum(A/2*g[jh]^2 for jh in JH)
        + sum(B*g[jh] for jh in JH)
        - sum(λ_EOM[jh]*g[jh] for jh in JH) # minimizing total cost of energy generation
        + sum(ρ_EOM/2*(g[jh] - g_bar[jh])^2 for jh in JH)
    )

    if market_design == "CfD"

        # CfD parameters
        λ_cfd = mod.ext[:parameters][:λ_cfd] # CfD strike price [€/MWh]
        ζ_cfd = mod.ext[:parameters][:ζ_cfd] # CfD contract premium price [€/MW]
        Q_cfd_bar = mod.ext[:parameters][:Q_cfd_bar] # Average CfD contracted capacity across all agents [MW]
        ρ_CfD = mod.ext[:parameters][:ρ_cfd] # rho-value in ADMM related to CfD auctions

        # CfD variables
        Q_cfd_gen = mod.ext[:variables][:Q_cfd_gen] = @variable(mod, lower_bound=0, base_name="CfD_contracted_capacity") # CfD contracted capacity [MW]
        g_cfd = mod.ext[:variables][:g_cfd] = @variable(mod, [jh=JH], lower_bound=0, base_name="CfD_generation") # individual generator's generation under CfD [MWh]

        # CfD expressions
        cfd_payout_gen = mod.ext[:expressions][:cfd_payout_gen] = @expression(mod, [jh in JH], (λ_cfd - λ_EOM[jh]) * g_cfd[jh])
        cfd_premium_gen = mod.ext[:expressions][:cfd_premium_gen] = @expression(mod, ζ_cfd * Q_cfd_gen)
        cfd_penalty_gen = mod.ext[:expressions][:cfd_penalty_gen] = @expression(mod, ρ_CfD/2 * (Q_cfd_gen - Q_cfd_bar)^2) # delta between generator's contracted capacity and the market average NB: not time dependent
        #cfd_penalty_gen = mod.ext[:expressions][:cfd_penalty_gen] = @expression(mod, ρ_CfD/2 * ((Q_cfd_gen - Q_cfd_bar)/(Q_cfd_bar + 0.0001))^2)

        # CfD objective
        objective_generator = mod.ext[:expressions][:objective_generator] = @expression(mod,
        + sum(A/2*g[jh]^2 for jh in JH)
        + sum(B*g[jh] for jh in JH)
        - sum(λ_EOM[jh]*g[jh] for jh in JH) # minimizing total cost of energy generation
        + sum(ρ_EOM/2*(g[jh] - g_bar[jh])^2 for jh in JH)
        - sum(cfd_payout_gen[jh] for jh in JH)
        - cfd_premium_gen
        + cfd_penalty_gen
        )
        
        # CfD related constraints
        mod.ext[:constraints][:g_cfd] = @constraint(mod, [jh in JH], g_cfd[jh] <= AF[jh] * Q_cfd_gen)
        mod.ext[:constraints][:gen_cfd] = @constraint(mod, [jh in JH], g_cfd[jh] <= g[jh])
        mod.ext[:constraints][:cfd_installed_cap] = @constraint(mod, Q_cfd_gen <= C) # CfD contracted capacity cannot exceed installed capacity

    end    
    
    mod.ext[:objective] = @objective(mod, Min, objective_generator)
    
    mod.ext[:constraints][:cap_limit] = @constraint(mod, [jh=JH],
        g[jh] <=  AC[jh]
        )
    return mod
end