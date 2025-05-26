function solve_generator_agent!(mod::Model)
    # Extract sets
    JH = mod.ext[:sets][:JH]

    # Extract parameters
    A = mod.ext[:parameters][:A] 
    B = mod.ext[:parameters][:B]  
    λ_EOM = mod.ext[:parameters][:λ_EOM] # EOM prices
    g_bar = mod.ext[:parameters][:g_bar] # element in ADMM penalty term related to EOM
    ρ_EOM = mod.ext[:parameters][:ρ_EOM] # rho-value in ADMM related to EOM auctions
 
    # Create variables
    g = mod.ext[:variables][:g]  

    # Objective 
    mod.ext[:objective] = @objective(mod, Min,
        + sum(A/2*g[jh]^2 for jh in JH)
        + sum(B*g[jh] for jh in JH)
        - sum(λ_EOM[jh]*g[jh] for jh in JH) 
        + sum(ρ_EOM/2*(g[jh] - g_bar[jh])^2 for jh in JH)
    )


    optimize!(mod);
 #   JH = mod.ext[:sets][:JH]
 #   total_revenue = mod.ext[:expressions][:total_revenue]
 #   revenue_total = sum(value.(total_revenue[jh]) for jh in JH)

   # println("📊 Total generator revenue (with CfD correction): €", round(revenue_total, digits=2))
   # total_effective_revenue = cfd_strike * sum(value(g[jh]) for jh in JH)

    return mod
end