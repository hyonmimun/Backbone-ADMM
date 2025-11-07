function build_generator_agent!(mod::Model, market_design::AbstractString)
    # Extract sets
    JY = mod.ext[:sets][:JY]
    JD = mod.ext[:sets][:JD]
    JH = mod.ext[:sets][:JH]
    #JG = mod.ext[:sets][:JG]

    nY = data["General"]["nYears"]
    nR = data["General"]["nReprDays"]
    nT = data["General"]["nTimesteps"]
    #nG = data["General"]["nGasPrice"]

    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year

    # Extract time series data
    AC = mod.ext[:timeseries][:AC] # GW Available capacity of the generator 
    AF = mod.ext[:timeseries][:AF] # Availability factor for generation

    # Extract parameters
    #A = mod.ext[:parameters][:A]
    B = mod.ext[:parameters][:B]
    C = mod.ext[:parameters][:C] # GW 
    λ_EOM = mod.ext[:parameters][:λ_EOM] # EOM prices
    g_bar = mod.ext[:parameters][:g_bar] # average/consensus 
    ρ_EOM = mod.ext[:parameters][:ρ_EOM] # 10^6 €, rho penalty
    W = mod.ext[:parameters][:W] # weight of representative day
    P = mod.ext[:parameters][:P]
    #P_g = mod.ext[:parameters][:P_g]
    β = mod.ext[:parameters][:β] #
    γ = mod.ext[:parameters][:γ] # weight of expected revenues and CVAR

    # Create variables
    g = mod.ext[:variables][:g] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, base_name="generation") #GWh
    α = mod.ext[:variables][:α] = @variable(mod, base_name = "VaR") # 10^6€
    u = mod.ext[:variables][:u] = @variable(mod, [jy = JY], lower_bound = 0, base_name = "mean tail risk") # 10^6 €

    # Expressions (per year)
    #if m == "GasTurbine"
        #generator_costs = mod.ext[:expressions][:generator_costs] = @expression(mod, [jy=JY, jg=JG], sum(W[jd,jy] * B[jg] * g[jh,jd,jy,jg] for jh in JH, jd in JD))
        #generator_revenue = mod.ext[:expressions][:generator_revenue] = @expression(mod, [jy=JY, jg=JG], sum(W[jd,jy] * λ_EOM[jh,jd,jy] * g[jh,jd,jy,jg] for jh in JH, jd in JD))
        #generator_profit = mod.ext[:expressions][:generator_profit] = @expression(mod,[jy=JY, jg=JG], generator_revenue[jy,jg] - generator_costs[jy,jg])
        #generator_penalty = mod.ext[:expressions][:generator_penalty] = @expression(mod, [jy=JY], sum(ρ_EOM/2* W[jd,jy] * (g[jh, jd, jy, jg] - g_bar[jh, jd, jy])^2 for jh in JH, jd in JD)) # 10^6€
    #else
        
    #generator_costs = mod.ext[:expressions][:generator_costs] = @expression(mod, [jy = JY], sum(W[jd,jy] * (A/2*g[jh, jd, jy]^2 + B*g[jh, jd, jy]) for jh in JH, jd in JD)) # 10^6€ # cost vectors for different gas prices 

    generator_costs = mod.ext[:expressions][:generator_costs] = @expression(mod, [jy = JY], sum(W[jd,jy] * B*g[jh, jd, jy] for jh in JH, jd in JD)) # linear cost function
    generator_revenue = mod.ext[:expressions][:generator_revenue] = @expression(mod, [jy = JY], sum(W[jd,jy] * λ_EOM[jh, jd, jy] * g[jh, jd, jy] for jh in JH, jd in JD)) # 10^6€
    generator_profit = mod.ext[:expressions][:generator_profit] = @expression(mod, [jy = JY], generator_revenue[jy] - generator_costs[jy]) # 10^6€
    generator_penalty = mod.ext[:expressions][:generator_penalty] = @expression(mod, [jy=JY], sum(ρ_EOM/2* W[jd,jy] * (g[jh, jd, jy] - g_bar[jh, jd, jy])^2 for jh in JH, jd in JD)) # 10^6€
    
    # Risk aversion
    CVAR = mod.ext[:expressions][:CVAR] = @expression(mod, α - ((1/β) * sum(P[jy] * u[jy] for jy in JY))) # 10^6€
    
    if market_design == "EOM"
        #=if m == "GasTurbine"
            objective_generator = mod.ext[:expressions][:objective_generator] = @expression(mod, 
            - γ * sum(P[jy]* P_g[jg] * generator_profit[jy,jg] for jy in JY, jg in JG) # minimizing total cost of energy generation
            - (1 - γ) * CVAR
            + sum(P[jy] * P_g[jg]* generator_penalty[jy,jg] for jy in JY, jg in JG)
            )
        else =#

        # Build objective expression (over all years) # 10^6€
        objective_generator = mod.ext[:expressions][:objective_generator] = @expression(mod,
            - γ * sum(P[jy]* generator_profit[jy] for jy in JY) # minimizing total cost of energy generation
            - (1 - γ) * CVAR
            + sum(P[jy] * generator_penalty[jy] for jy in JY)
        )

        # CVAR constraint
        if γ < 1
            mod.ext[:constraints][:VAR_threshold] = @constraint(mod, [jy = JY],
            α - generator_profit[jy] <= u[jy] )
        end
            mod.ext[:constraints][:cap_limit] = @constraint(mod, [jh=JH, jd=JD, jy=JY], g[jh,jd,jy] <=  AC[jh,jd,jy])

    else market_design == "cfd"
        # cfd parameters
        λ_cfd = mod.ext[:parameters][:λ_cfd] # 10^6€/GWh
        ζ_cfd = mod.ext[:parameters][:ζ_cfd] # 10^6€/GW???
        Q_cfd_bar = mod.ext[:parameters][:Q_cfd_bar] # GW
        ρ_cfd = mod.ext[:parameters][:ρ_cfd] # 10^6€/GW^2

        # cfd variables
        Q_cfd = mod.ext[:variables][:Q_cfd] = @variable(mod, lower_bound=0,base_name="CfD_contracted_capacity") # cfd contracted capacity [GW]
        g_cfd = mod.ext[:variables][:g_cfd] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, base_name="CfD_generation") # individual generator's generation under cfd [GWh]

        # cfd expressions (per year)
        cfd_payout_gen = mod.ext[:expressions][:cfd_payout_gen] = @expression(mod, [jy=JY], sum(W[jd,jy]* (λ_cfd - λ_EOM[jh,jd,jy]) * g_cfd[jh,jd,jy] for jh in JH, jd in JD)) # 10^6€
        #gen_cfd_costs = mod.ext[:expressions][:gen_cfd_costs] = @expression(mod, [jy = JY], sum(W[jd,jy] * (A/2*g_cfd[jh, jd, jy]^2 + B*g_cfd[jh, jd, jy]) for jh in JH, jd in JD)) # 10^6€
        cfd_premium_gen = mod.ext[:expressions][:cfd_premium_gen] = @expression(mod, ζ_cfd * Q_cfd) # 10^6€
        cfd_penalty_gen = mod.ext[:expressions][:cfd_penalty_gen] = @expression(mod, ρ_cfd/2 * (Q_cfd - Q_cfd_bar)^2) #GW delta between generator's contracted capacity and the market average NB: not time dependent
        cfd_generator_profit = mod.ext[:expressions][:cfd_generator_profit] = @expression(mod,[jy=JY], cfd_payout_gen[jy] + generator_profit[jy]) # 10^6€/year

        # cfd objective (over all years)
        objective_generator = mod.ext[:expressions][:objective_generator] = @expression(mod,
        - γ * (sum(P[jy] * cfd_generator_profit[jy] for jy in JY))
        - γ * cfd_premium_gen # premium is revenue for the generator, so negative on cost minimization
        - (1 - γ) * CVAR
        + sum(P[jy] * generator_penalty[jy] for jy in JY)
        + cfd_penalty_gen
        )

        # cfd related constraints
        mod.ext[:constraints][:cfd_installed_cap] = @constraint(mod, [jy=JY], Q_cfd <= C) # cfd contracted capacity cannot exceed installed capacity #GW
        mod.ext[:constraints][:g_cfd] = @constraint(mod, [jh=JH, jd=JD, jy=JY], g_cfd[jh,jd,jy] == AF[jh,jd,jy] * Q_cfd) # GWh
        mod.ext[:constraints][:cap_limit] = @constraint(mod, [jh=JH, jd=JD, jy=JY], g[jh,jd,jy]<=  AC[jh,jd,jy]) # GWh 

        # CVAR constraint
        if γ < 1
        mod.ext[:constraints][:VAR_threshold] = @constraint(mod, [jy = JY],
        α - cfd_generator_profit[jy] <= u[jy])
    end
    end
    
    mod.ext[:objective] = @objective(mod, Min, objective_generator)

    return mod
end