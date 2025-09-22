function solve_consumer_agent!(mod::Model,market_design::AbstractString, m::String)
   # Extract sets
   JY = mod.ext[:sets][:JY]
   JD = mod.ext[:sets][:JD] 
   JH = mod.ext[:sets][:JH]

   nY = data["General"]["nYears"]
   nR = data["General"]["nReprDays"]
   nT = data["General"]["nTimesteps"]

   idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year
   
   PV = mod.ext[:timeseries][:PV]
   D = mod.ext[:timeseries][:D]

    # Extract parameters
    λ_EOM = mod.ext[:parameters][:λ_EOM]
    g_bar = mod.ext[:parameters][:g_bar]
    ρ_EOM = mod.ext[:parameters][:ρ_EOM]
    D_fixed = mod.ext[:parameters][:D_fixed]
    WTP = mod.ext[:parameters][:WTP]
    D_ELA_max = mod.ext[:parameters][:D_ELA_max]
    W = mod.ext[:parameters][:W]
    P = mod.ext[:parameters][:P]
    β = mod.ext[:parameters][:β]

    # Battery parameters
    cap_smax = mod.ext[:parameters][:cap_smax]
    EC = mod.ext[:parameters][:EC]
    ED = mod.ext[:parameters][:ED]
    Decay = mod.ext[:parameters][:Decay]
    winj = mod.ext[:parameters][:winj]
    wwith = mod.ext[:parameters][:wwith]

    # Create variables
    g = mod.ext[:variables][:g]
    D_ELA = mod.ext[:variables][:D_ELA]
    SOC = mod.ext[:variables][:SOC]
    charge = mod.ext[:variables][:charge]
    discharge = mod.ext[:variables][:discharge]
    
    # Create affine expressions (per year)
    utility_term = mod.ext[:expressions][:utility_term] = @expression(mod, [jh=JH, jd=JD, jy=JY], WTP * D_ELA[jh,jd,jy] - (WTP / (2 * D_ELA_max[jh,jd,jy])) * D_ELA[jh,jd,jy]^2)
    consumer_costs = mod.ext[:expressions][:consumer_costs] = @expression(mod,[jh=JH, jd=JD, jy=JY], λ_EOM[jh, jd, jy] * g[jh, jd, jy]) # import = -g
    
    consumer_profit = mod.ext[:expressions][:consumer_profit] = @expression(mod, [jy = JY], sum( W[jd, jy] * (utility_term[jh, jd, jy] - consumer_costs[jh,jd,jy]) for jh in JH, jd in JD))
    consumer_penalty = mod.ext[:expressions][:consumer_penalty] = @expression(mod,[jy=JY], sum(ρ_EOM/2 * W[jd,jy]*(g[jh,jd,jy] - g_bar[jh,jd,jy])^2 for jh in JH, jd in JD))
    
    # Risk aversion
    exp_cons_prof = mod.ext[:expressions][:expected_consumer_profit] = @expression(mod, sum(P[jy]*consumer_profit[jy] for jy in JY))
    consumer_var = mod.ext[:expressions][:consumer_var] = @expression(mod, sum(P[jy] *(consumer_profit[jy] - exp_cons_prof)^2 for jy in JY))
    consumer_mv = mod.ext[:expressions][:consumer_mv] = @expression(mod, β * consumer_var)

    # Build objective function (over all years)
    objective_consumer = mod.ext[:expressions][:objective_consumer] = @expression(mod,          
        - sum(P[jy] * consumer_profit[jy] for jy in JY)
        + sum(P[jy] * consumer_penalty[jy] for jy in JY)
        + consumer_mv
        )

    if market_design == "cfd"
        # cfd variables
        Q_cfd_con = mod.ext[:variables][:Q_cfd_con]

        # cfd parameters
        λ_cfd = mod.ext[:parameters][:λ_cfd]
        ζ_cfd = mod.ext[:parameters][:ζ_cfd]
        g_cfd_total = mod.ext[:parameters][:g_cfd_total]
        Q_cfd_bar = mod.ext[:parameters][:Q_cfd_bar]
        ρ_cfd = mod.ext[:parameters][:ρ_cfd]
        #Q_cfd_con_tot = mod.ext[:parameters][:Q_cfd_con_tot] # Total cfd contracted capacity of all consumers, perhaps not working bc of the different iteration steps, consider using Q_cfd_gen_tot instead

        # cfd expressions (per year)
        #share_cfd_con =  mod.ext[:expressions][:share_cfd_con] = @expression(mod,[jy=JY], Q_cfd_con[jy] / (Q_cfd_con_tot[jy]+1e-9)) # Adding a small value to avoid dividing by zero
        #cfd_payout = mod.ext[:expressions][:cfd_payout] = @expression(mod,[jy=JY], sum(W[jd,jy] * share_cfd_con[jy] * (λ_EOM[jh,jd,jy] - λ_cfd) * g_cfd_total[jh,jd,jy] for jh in JH, jd in JD))
        cfd_payout = mod.ext[:expressions][:cfd_payout] = @expression(mod,[jy=JY], sum(W[jd,jy] * (λ_EOM[jh,jd,jy] - λ_cfd) * Q_cfd_con[jy] for jh in JH, jd in JD))
        cfd_premium = mod.ext[:expressions][:cfd_premium] = @expression(mod, [jy=JY], ζ_cfd[jy] * Q_cfd_con[jy])
        cfd_penalty_con = mod.ext[:expressions][:cfd_penalty_con] = @expression(mod,[jy=JY], ρ_cfd/2 * (Q_cfd_con[jy] - Q_cfd_bar[jy])^2)
        cfd_consumer_profit = mod.ext[:expressions][:cfd_consumer_profit] = @expression(mod, [jy=JY], consumer_profit[jy] + cfd_payout[jy] - cfd_premium[jy])
        
        # Risk aversion
        exp_cfd_con = mod.ext[:expressions][:exp_cfd_con] = @expression(mod, sum(P[jy]*cfd_consumer_profit[jy] for jy in JY))
        cfd_con_var = mod.ext[:expressions][:cfd_con_var] = @expression(mod, sum(P[jy]*(cfd_consumer_profit[jy] - exp_cfd_con)^2 for jy in JY))
        cfd_con_mv = mod.ext[:expressions][:cfd_con_mv] = @expression(mod, β * cfd_con_var)

        # Redefine objective for cfd scenario
        objective_consumer = mod.ext[:expressions][:objective_consumer] = @expression(mod,            
            - sum(P[jy]*cfd_consumer_profit[jy] for jy in JY)
            + sum(P[jy]*consumer_penalty[jy] for jy in JY)
            + sum(P[jy]*cfd_penalty_con[jy] for jy in JY)
            + cfd_con_mv
            )
    end
    
    mod.ext[:objective] = @objective(mod, Min, objective_consumer)

    if haskey(mod.ext[:constraints], :energy_balance) # Check whether constraint :energybalance exists in the model
        delete.(Ref(mod), collect(mod.ext[:constraints][:energy_balance])) # Makes DenseAxisArray into vector, deletes the existing energy balance constraint if it exists
        delete!(mod.ext[:constraints], :energy_balance)  # Remove the reference/key :energy_balance from the constraints dictionary
    end

    # Redefine energy balance
    mod.ext[:constraints][:energy_balance] = @constraint(mod, [jh in JH, jd in JD, jy in JY],
    g[jh,jd,jy] == - D_fixed[jh,jd,jy] - D_ELA[jh,jd,jy] + PV[jh,jd,jy] - (charge[jh,jd,jy]) + (discharge[jh,jd,jy])
    )

   optimize!(mod)

    #= println("Termination status: ", MOI.get(mod, MOI.TerminationStatus()))
    println("Primal status:      ", MOI.get(mod, MOI.PrimalStatus()))
    println("Dual status:        ", MOI.get(mod, MOI.DualStatus())) =#
   return mod 
end
