function solve_consumer_agent!(mod::Model,market_design::AbstractString, m::String)
    # Extract sets
    JY = mod.ext[:sets][:JY]
    JD = mod.ext[:sets][:JD]
    JH = mod.ext[:sets][:JH]

    nT = length(JH)
    nR = length(JD)
    nY = length(JY)

    # Extract time series data
    D = mod.ext[:timeseries][:D]
    PV = haskey(mod.ext[:timeseries], :PV) ? mod.ext[:timeseries][:PV] : zeros(nT, nR, nY)

    # Extract parameters
    λ_EOM = mod.ext[:parameters][:λ_EOM]
    g_bar = mod.ext[:parameters][:g_bar] # consensus variable
    ρ_EOM = mod.ext[:parameters][:ρ_EOM] # penalty term voor primal and dual residuals
    D_fixed = mod.ext[:parameters][:D_fixed]  # Fixed demand (80%)
    WTP = mod.ext[:parameters][:WTP]
    D_ELA_max = mod.ext[:parameters][:D_ELA_max]  # GW
    W = mod.ext[:parameters][:W] # weight of representative day
    P = mod.ext[:parameters][:P] # Probability of scenario
    β = mod.ext[:parameters][:β]
    γ = mod.ext[:parameters][:γ] # weight between profit and risk-aversion

    # Battery parameters
    has_battery = mod.ext[:parameters][:has_battery]
    if has_battery
        cap_smax = mod.ext[:parameters][:cap_smax] # Battery capacity in GWh (kWh)
        EC = mod.ext[:parameters][:EC] # Charging efficiency
        ED = mod.ext[:parameters][:ED] # Discharging efficiency
        Decay = mod.ext[:parameters][:Decay] # Hourly decay rate
        winj = mod.ext[:parameters][:winj] # Max charging power (GWh)
        wwith = mod.ext[:parameters][:wwith] # Max discharging power (GWh)
    end

    # Create variables
    g = mod.ext[:variables][:g]
    D_ELA = mod.ext[:variables][:D_ELA]
    SOC = mod.ext[:variables][:SOC]
    charge = mod.ext[:variables][:charge]
    discharge = mod.ext[:variables][:discharge]

    # CVAR
    α = mod.ext[:variables][:α]
    u = mod.ext[:variables][:u]

    # Create affine expressions (per year)
    utility_term = mod.ext[:expressions][:utility_term] = @expression(mod, [jh=JH, jd=JD, jy=JY], WTP * D_ELA[jh,jd,jy] - (WTP / (2 * D_ELA_max[jh,jd,jy])) * D_ELA[jh,jd,jy]^2)
    consumer_settlement = mod.ext[:expressions][:consumer_settlement] = @expression(mod,[jh=JH, jd=JD, jy=JY], λ_EOM[jh, jd, jy] * g[jh, jd, jy]) # or profit when g is positive
    consumer_profit = mod.ext[:expressions][:consumer_profit] = @expression(mod, [jy = JY], sum( W[jd, jy] * (utility_term[jh, jd, jy] + consumer_settlement[jh,jd,jy]) for jh in JH, jd in JD)) # at consumption g < 0 = already negative = costs, otherwise added to profit
    consumer_penalty = mod.ext[:expressions][:consumer_penalty] = @expression(mod,[jy=JY], sum(ρ_EOM/2 * W[jd,jy]*(g[jh,jd,jy] - g_bar[jh,jd,jy])^2 for jh in JH, jd in JD))
    
    # Risk aversion
    CVAR = mod.ext[:expressions][:CVAR] = @expression(mod, α - ((1/β) * sum(P[jy] * u[jy] for jy in JY)))

    if market_design == "EOM"
    # Build objective function (over all years)
    objective_consumer = mod.ext[:expressions][:objective_consumer] = @expression(mod,          
        - γ * sum(P[jy] * consumer_profit[jy] for jy in JY) # profit is negative = cost revenue 
        - (1 - γ) * CVAR
        + sum(P[jy] * consumer_penalty[jy] for jy in JY))

        # Updating CVAR constraint
        if γ < 1
            for jy in JY
                delete(mod, mod.ext[:constraints][:VAR_threshold][jy])
            end
            mod.ext[:constraints][:VAR_threshold] = @constraint(mod, [jy = JY],
            α - consumer_profit[jy] <= u[jy] )
        end

    else market_design == "cfd"
        # cfd variables
        Q_cfd = mod.ext[:variables][:Q_cfd]

        # cfd parameters
        λ_cfd = mod.ext[:parameters][:λ_cfd]  # 10^6 €/GWh (strike price)
        ζ_cfd = mod.ext[:parameters][:ζ_cfd]  # 10^6 €/GW/year (cfd contract premium)
        g_cfd_total = mod.ext[:parameters][:g_cfd_total] # GW
        Q_cfd_bar = mod.ext[:parameters][:Q_cfd_bar] # GW
        ρ_cfd = mod.ext[:parameters][:ρ_cfd] # 10^6 €/GW
        Q_cfd_con_tot = mod.ext[:parameters][:Q_cfd_con_tot]

        # cfd expressions (per year)
        # Q_cfd is a scalar value: one decision made in the beginning for all scenarios
        if Q_cfd_con_tot == 0
        share_cfd_con =  mod.ext[:expressions][:share_cfd_con] = @expression(mod, (0))
        else
        share_cfd_con =  mod.ext[:expressions][:share_cfd_con] = @expression(mod, (-Q_cfd/Q_cfd_con_tot))
        end

        cfd_payout = mod.ext[:expressions][:cfd_payout] = @expression(mod,[jy=JY], sum(W[jd,jy] * share_cfd_con * (λ_EOM[jh,jd,jy] - λ_cfd) * g_cfd_total[jh,jd,jy] for jh in JH, jd in JD))
        cfd_premium = mod.ext[:expressions][:cfd_premium] = @expression(mod, ζ_cfd * Q_cfd) # if consumers consume more, then they have to pay a higher premium. 
        cfd_penalty_con = mod.ext[:expressions][:cfd_penalty_con] = @expression(mod, ρ_cfd/2 * (Q_cfd - Q_cfd_bar)^2)
        cfd_consumer_profit = mod.ext[:expressions][:cfd_consumer_profit] = @expression(mod, [jy=JY], consumer_profit[jy] + cfd_payout[jy])

        # Redefine objective for cfd scenario
        objective_consumer = mod.ext[:expressions][:objective_consumer] = @expression(mod,            
            - γ * sum(P[jy] * cfd_consumer_profit[jy] for jy in JY)
            - γ * cfd_premium
            - (1 - γ) * CVAR
            + sum(P[jy] * consumer_penalty[jy] for jy in JY)
            + cfd_penalty_con
            )

        if γ < 1
            for jy in JY
                delete(mod, mod.ext[:constraints][:VAR_threshold][jy])
            end
            mod.ext[:constraints][:VAR_threshold] = @constraint(mod, [jy = JY],
            α - cfd_consumer_profit[jy] <= u[jy] )
        end
    end
    
    mod.ext[:objective] = @objective(mod, Min, objective_consumer)

    if haskey(mod.ext[:constraints], :energy_balance) # Check whether constraint :energybalance exists in the model
        delete.(Ref(mod), collect(mod.ext[:constraints][:energy_balance])) # deletes the existing energy balance constraint
        delete!(mod.ext[:constraints], :energy_balance)  # Remove the reference/key :energy_balance from the constraints dictionary
    end
    # Redefine energy balance
    mod.ext[:constraints][:energy_balance] = @constraint(mod, [jh in JH, jd in JD, jy in JY],
    g[jh,jd,jy] == - D_fixed[jh,jd,jy] - D_ELA[jh,jd,jy] + PV[jh,jd,jy] - (charge[jh,jd,jy]) + (discharge[jh,jd,jy])
    )
    #println("Debug Consumer Agent:")
    #println("λ_cfd values: ", λ_cfd)
    #println("Q_cfd_bar values: ", Q_cfd_bar)
    #println("ρ_cfd value: ", ρ_cfd)

   optimize!(mod)

    #println("Consumer Termination status: ", MOI.get(mod, MOI.TerminationStatus()))
    #println("Consumer Primal status:      ", MOI.get(mod, MOI.PrimalStatus()))
    #println("Consumer Dual status:        ", MOI.get(mod, MOI.DualStatus()))
    
    #println("CfD payout for $m:", value.(cfd_payout))
    
    #@show value.(mod.ext[:variables][:Q_cfd])
    #@show value.(mod.ext[:parameters][:Q_cfd_con_tot])
    #@show value.(mod.ext[:parameters][:g_cfd_total])
    #@show value.(mod.ext[:parameters][:Q_cfd_bar])
    #@show value.(mod.ext[:expressions][:share_cfd_con])
    #@show value.(mod.ext[:expressions][:cfd_premium])
    #@show value.(mod.ext[:expressions][:cfd_penalty_con])


    #@show haskey(mod.ext[:constraints], :energy_balance)
    #@show length(mod.ext[:constraints][:energy_balance])
   return mod 
end
