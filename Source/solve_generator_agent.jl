function solve_generator_agent!(mod::Model, market_design::AbstractString, m::String)
# Solves the model during each ADMM iteration with updated parameters. Only add full constraints and expressions that include parameters that are updated with each iteration
    # Extract sets
    JY = mod.ext[:sets][:JY]
    JD = mod.ext[:sets][:JD]
    JH = mod.ext[:sets][:JH]

    nY = data["General"]["nYears"]
    nR = data["General"]["nReprDays"]
    nT = data["General"]["nTimesteps"]

    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year

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
    W = mod.ext[:parameters][:W] # weight of representative day
    P = mod.ext[:parameters][:P]
    β = mod.ext[:parameters][:β]

    # Create variables
    g = mod.ext[:variables][:g]

    # Expressions (per year)
    generator_costs = mod.ext[:expressions][:generator_costs] = @expression(mod, [jy = JY], sum(W[jd,jy] * (A/2*g[jh, jd, jy]^2 + B*g[jh, jd, jy]) for jh in JH, jd in JD))
    generator_revenue = mod.ext[:expressions][:generator_revenue] = @expression(mod, [jy = JY], sum(W[jd,jy] * λ_EOM[jh, jd, jy]*g[jh, jd, jy] for jh in JH, jd in JD))
    generator_profit = mod.ext[:expressions][:generator_profit] = @expression(mod, [jy = JY], generator_revenue[jy] - generator_costs[jy])
    generator_penalty = mod.ext[:expressions][:generator_penalty] = @expression(mod, [jy=JY], sum(ρ_EOM/2* W[jd,jy] * (g[jh, jd, jy] - g_bar[jh, jd, jy])^2 for jh in JH, jd in JD))
    
    # Risk aversion
    exp_gen_prof = mod.ext[:expressions][:exp_gen_prof] = @expression(mod, sum(P[jy]*generator_profit[jy] for jy in JY))
    generator_var = mod.ext[:expressions][:generator_var] = @expression(mod, sum(P[jy]* (generator_profit[jy] - exp_gen_prof)^2 for jy in JY))
    mv_generator = mod.ext[:expressions][:mv_generator] = @expression(mod, β * generator_var) 

    # Build objective expression (over all years)
    objective_generator = mod.ext[:expressions][:objective_generator] = @expression(mod,
        - sum(P[jy]*generator_profit[jy] for jy in JY) # minimizing total cost of energy generation
        + sum(P[jy]*generator_penalty[jy] for jy in JY)
        + mv_generator
    )

    if market_design == "cfd"

        # cfd parameters
        λ_cfd = mod.ext[:parameters][:λ_cfd] # cfd strike price [€/MWh]
        ζ_cfd = mod.ext[:parameters][:ζ_cfd] # cfd contract premium price [€/MW]
        Q_cfd_bar = mod.ext[:parameters][:Q_cfd_bar] # Average cfd contracted capacity across all agents [MW]
        ρ_cfd = mod.ext[:parameters][:ρ_cfd] # rho-value in ADMM related to cfd auctions

        # cfd variables
        Q_cfd_gen = mod.ext[:variables][:Q_cfd_gen]
        g_cfd = mod.ext[:variables][:g_cfd]

        # cfd expressions (per year)
        cfd_payout_gen = mod.ext[:expressions][:cfd_payout_gen] = @expression(mod, [jy=JY], sum(W[jd,jy]* (λ_cfd - λ_EOM[jh,jd,jy] * g_cfd[jh,jd,jy]) for jh in JH, jd in JD))
        cfd_premium_gen = mod.ext[:expressions][:cfd_premium_gen] = @expression(mod,[jy=JY], ζ_cfd[jy] * Q_cfd_gen[jy])
        cfd_penalty_gen = mod.ext[:expressions][:cfd_penalty_gen] = @expression(mod,[jy=JY], ρ_cfd/2 * (Q_cfd_gen[jy] - Q_cfd_bar[jy])^2) # delta between generator's contracted capacity and the market average NB: not time dependent
        #cfd_penalty_gen = mod.ext[:expressions][:cfd_penalty_gen] = @expression(mod, ρ_cfd/2 * ((Q_cfd_gen - Q_cfd_bar)/(Q_cfd_bar + 0.0001))^2)
        cfd_generator_profit = mod.ext[:expressions][:cfd_generator_profit] = @expression(mod,[jy=JY], cfd_payout_gen[jy] + generator_profit[jy] + cfd_premium_gen[jy])
        
        # Risk aversion
        exp_cfd_gen = mod.ext[:expressions][:exp_cfd_gen] = @expression(mod,sum(P[jy]*cfd_generator_profit[jy] for jy in JY))
        cfd_gen_var = mod.ext[:expressions][:cfd_gen_var] = @expression(mod, sum(P[jy]*(cfd_generator_profit[jy] - exp_cfd_gen)^2 for jy in JY))
        cfd_gen_mv = mod.ext[:expressions][:cfd_gen_mv] = @expression(mod, β * cfd_gen_var)

        # cfd objective (over all years)
        objective_generator = mod.ext[:expressions][:objective_generator] = @expression(mod,
        - sum(P[jy] * cfd_generator_profit[jy] for jy in JY)
        + sum(P[jy] * generator_penalty[jy] for jy in JY)
        + sum(P[jy] * cfd_penalty_gen[jy] for jy in JY)
        + cfd_gen_mv
        )
    end

    mod.ext[:objective] = @objective(mod, Min, objective_generator) #re-register the updated objective in the JuMP model before calling the optimizer

    optimize!(mod) # solves the optimization problem that is defined: sends model to the optimizer and attempts to compute the optimal. values of your decision variables
    return mod # reutrns JuMP model object from the function: end function and give back model that was built

end