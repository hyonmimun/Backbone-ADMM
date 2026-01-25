function solve_generator_agent!(mod::Model, market_design::AbstractString, m::String)
# Solves the model during each ADMM iteration with updated parameters. Only add full constraints and expressions that include parameters that are updated with each iteration
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
    ρ_EOM = mod.ext[:parameters][:ρ_EOM] # 10^6 €/GW, rho penalty
    W = mod.ext[:parameters][:W] # weight of representative day
    P = mod.ext[:parameters][:P]
    β = mod.ext[:parameters][:β] # 10^6 €
    γ = mod.ext[:parameters][:γ] # weight of expected revenues and CVAR

    # Create variables
    g = mod.ext[:variables][:g]
    α = mod.ext[:variables][:α]
    u = mod.ext[:variables][:u]

    # Expressions (per year)

    #=if m == "GasTurbine"
        generator_costs = mod.ext[:expressions][:generator_costs] = @expression(mod, [jy=JY, jg=JG], sum(W[jd,jy] * B[jg] * g[jh,jd,jy,jg] for jh in JH, jd in JD))
        generator_revenue = mod.ext[:expressions][:generator_revenue] = @expression(mod, [jy=JY, jg=JG], sum(W[jd,jy] * λ_EOM[jh,jd,jy] * g[jh,jd,jy,jg] for jh in JH, jd in JD))
        generator_profit = mod.ext[:expressions][:generator_profit] = @expression(mod,[jy=JY, jg=JG], generator_revenue[jy,jg] - generator_costs[jy,jg])
        generator_penalty = mod.ext[:expressions][:generator_penalty] = @expression(mod, [jy=JY], sum(ρ_EOM/2* W[jd,jy] * (g[jh, jd, jy, jg] - g_bar[jh, jd, jy])^2 for jh in JH, jd in JD)) # 10^6€
    else =#
    #generator_costs = mod.ext[:expressions][:generator_costs] = @expression(mod, [jy = JY], sum(W[jd,jy] * (A/2*g[jh, jd, jy]^2 + B*g[jh, jd, jy]) for jh in JH, jd in JD))

    generator_costs = mod.ext[:expressions][:generator_costs] = @expression(mod, [jy = JY], sum(W[jd,jy] * B*g[jh, jd, jy] for jh in JH, jd in JD)) # linear cost function
    generator_revenue = mod.ext[:expressions][:generator_revenue] = @expression(mod, [jy = JY], sum(W[jd,jy] * λ_EOM[jh, jd, jy] * g[jh, jd, jy] for jh in JH, jd in JD))
    generator_profit = mod.ext[:expressions][:generator_profit] = @expression(mod, [jy = JY], generator_revenue[jy] - generator_costs[jy])
    generator_penalty = mod.ext[:expressions][:generator_penalty] = @expression(mod, [jy=JY], sum(ρ_EOM/2* W[jd,jy] * (g[jh, jd, jy] - g_bar[jh, jd, jy])^2 for jh in JH, jd in JD))

    # Risk aversion
    CVAR = mod.ext[:expressions][:CVAR] = @expression(mod, α - ((1/β) * sum(P[jy] * u[jy] for jy in JY)))
    
    if market_design == "EOM"
        #=if m == "GasTurbine"
            objective_generator = mod.ext[:expressions][:objective_generator] = @expression(mod, 
            - γ * sum(P[jy]* P_g[jg] * generator_profit[jy,jg] for jy in JY, jg in JG) # minimizing total cost of energy generation
            - (1 - γ) * CVAR
            + sum(P[jy] * P_g[jg]* generator_penalty[jy,jg] for jy in JY, jg in JG)
            )
        else =#

        # Build objective expression (over all years)
        objective_generator = mod.ext[:expressions][:objective_generator] = @expression(mod,
            - γ * sum(P[jy]* generator_profit[jy] for jy in JY) # minimizing total cost of energy generation
            - (1 - γ) * CVAR
            + sum(P[jy] * generator_penalty[jy] for jy in JY)
        )
        # Updating CVAR constraint
        if γ < 1
            for jy in JY
                delete(mod, mod.ext[:constraints][:VAR_threshold][jy])
            end
            mod.ext[:constraints][:VAR_threshold] = @constraint(mod, [jy = JY],
            α - generator_profit[jy] <= u[jy] )
        end

    else market_design == "cfd"

        # cfd parameters
        λ_cfd = mod.ext[:parameters][:λ_cfd]
        ζ_cfd = mod.ext[:parameters][:ζ_cfd]
        Q_cfd_bar = mod.ext[:parameters][:Q_cfd_bar]
        ρ_cfd = mod.ext[:parameters][:ρ_cfd]

        # cfd variables
        Q_cfd = mod.ext[:variables][:Q_cfd]
        g_cfd = mod.ext[:variables][:g_cfd]

        # cfd expressions (per year)
        cfd_payout_gen = mod.ext[:expressions][:cfd_payout_gen] = @expression(mod, [jy=JY], sum(W[jd,jy]* (λ_cfd - λ_EOM[jh,jd,jy]) * g_cfd[jh,jd,jy] for jh in JH, jd in JD))
        #gen_cfd_costs = mod.ext[:expressions][:gen_cfd_costs] = @expression(mod, [jy = JY], sum(W[jd,jy] * (A/2*g_cfd[jh, jd, jy]^2 + B*g_cfd[jh, jd, jy]) for jh in JH, jd in JD))
        cfd_premium_gen = mod.ext[:expressions][:cfd_premium_gen] = @expression(mod, ζ_cfd * Q_cfd)
        cfd_penalty_gen = mod.ext[:expressions][:cfd_penalty_gen] = @expression(mod, ρ_cfd/2 * (Q_cfd - Q_cfd_bar)^2) # delta between generator's contracted capacity and the market average NB: not time dependent
        cfd_generator_profit = mod.ext[:expressions][:cfd_generator_profit] = @expression(mod,[jy=JY], cfd_payout_gen[jy] + generator_profit[jy])

        # cfd objective (over all years)
        objective_generator = mod.ext[:expressions][:objective_generator] = @expression(mod,
        - γ * sum(P[jy] * cfd_generator_profit[jy] for jy in JY)
        - γ * cfd_premium_gen
        - (1 - γ) * CVAR
        + sum(P[jy] * generator_penalty[jy] for jy in JY)
        + cfd_penalty_gen
        )
    
        # Updating CVAR constraint
        if γ < 1
            for jy in JY
                delete(mod, mod.ext[:constraints][:VAR_threshold][jy])
            end
            mod.ext[:constraints][:VAR_threshold] = @constraint(mod, [jy = JY],
            α - (cfd_generator_profit[jy] + cfd_premium_gen) <= u[jy] )
        end
    end

    mod.ext[:objective] = @objective(mod, Min, objective_generator) #re-register the updated objective in the JuMP model before calling the optimizer

    #=
    println("Debug Q_cfd:")
    println("λ_cfd: ", value(λ_cfd))
    println("ζ_cfd: ", value(ζ_cfd))
    println("ρ_cfd: ", value(ρ_cfd))
    println("Q_cfd_bar: ", value(Q_cfd_bar))
    println("Bounds on Q_cfd:")
    println("Lower: ", has_lower_bound(Q_cfd) ? lower_bound(Q_cfd) : "none")
    println("Upper: ", has_upper_bound(Q_cfd) ? upper_bound(Q_cfd) : "none")
    =#

    optimize!(mod)

    #= Add after optimize!(mod)
    println("Solution status: ", termination_status(mod))
    println("Q_cfd value for $m: ", value(Q_cfd))
    println("Objective terms:")
    
    
=#
    #println("CfD payout for $m:", value(cfd_payout_gen))
    #println("CfD penalty for $m: ", value(cfd_penalty_gen))
    #println("cfd_premium_gen for $m: ", value(cfd_premium_gen))

    #@show value.(mod.ext[:variables][:Q_cfd])
    #@show value.(mod.ext[:variables][:g_cfd])
    #@show value.(mod.ext[:expressions][:cfd_payout_gen])
    #@show value.(mod.ext[:expressions][:cfd_premium_gen])

    #println("Generator Termination status: ", MOI.get(mod, MOI.TerminationStatus()))
    #println("Generator Primal status:      ", MOI.get(mod, MOI.PrimalStatus()))
    #println("Generator Dual status:        ", MOI.get(mod, MOI.DualStatus())) 
    
    return mod # reutrns JuMP model object from the function: end function and give back model that was built
end