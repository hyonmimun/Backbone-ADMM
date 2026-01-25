function build_consumer_agent!(mod::Model,market_design::AbstractString)
    # Extract sets
    JY = mod.ext[:sets][:JY]
    JD = mod.ext[:sets][:JD]
    JH = mod.ext[:sets][:JH]

    nY = length(JY)
    nR = length(JD)
    nT = length(JH)

    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year

    # Extract time series data
    D = mod.ext[:timeseries][:D]
    PV = haskey(mod.ext[:timeseries],:PV) ? mod.ext[:timeseries][:PV] : zeros(nT, nR, nY)

    # Extract parameters
    λ_EOM = mod.ext[:parameters][:λ_EOM] #10^6€/GWh
    g_bar = mod.ext[:parameters][:g_bar] # consensus variable #GWh
    ρ_EOM = mod.ext[:parameters][:ρ_EOM] # penalty term voor primal and dual residuals
    D_fixed = mod.ext[:parameters][:D_fixed]  # Fixed demand (80%)
    WTP = mod.ext[:parameters][:WTP]
    D_ELA_max = mod.ext[:parameters][:D_ELA_max] # GWh
    W = mod.ext[:parameters][:W] # weight of representative day
    P = mod.ext[:parameters][:P] # Probability of scenario
    β = mod.ext[:parameters][:β] # tail mass: 0.05 = worst 0.05 of profits, the smaller, the focus is on the more extreme smaller outcomes
    γ = mod.ext[:parameters][:γ] # weight between maximizing for profit and maximizing for increasing the downside risk (1 = solely mazimize mean profits (risk-neutral), 0 = purely maximize on worst years)

    # Battery parameters
    has_battery = mod.ext[:parameters][:has_battery]
    if has_battery
        cap_smax = mod.ext[:parameters][:cap_smax] # Battery capacity in GWh (kWh)
        EC = mod.ext[:parameters][:EC] # Charging efficiency
        ED = mod.ext[:parameters][:ED] # Discharging efficiency
        Decay = mod.ext[:parameters][:Decay] # Hourly decay rate
        winj = mod.ext[:parameters][:winj] # Max charging power (GWh)
        wwith = mod.ext[:parameters][:wwith] # Max discharging power (GWh)
    # Battery variables
        SOC = mod.ext[:variables][:SOC] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, upper_bound = cap_smax, base_name="SOC") # GWh
        charge = mod.ext[:variables][:charge] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, upper_bound= winj, base_name="charge") #GWh
        discharge = mod.ext[:variables][:discharge] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, upper_bound = wwith, base_name="discharge") #GWh
    else
    # Create placeholder variables fixed to zero
        SOC = mod.ext[:variables][:SOC] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, base_name="SOC")
        charge = mod.ext[:variables][:charge] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, base_name="charge")
        discharge = mod.ext[:variables][:discharge] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, base_name="discharge")
        for jy in JY, jd in JD, jh in JH
            fix(SOC[jh,jd,jy], 0.0; force=true)
            fix(charge[jh,jd,jy], 0.0; force=true)
            fix(discharge[jh,jd,jy], 0.0; force=true)
        end
    end

    # Create variables
    g = mod.ext[:variables][:g] = @variable(mod, [jh=JH, jd=JD, jy=JY], base_name="generation")  # positive if consumer feeds power to the rest of the system, negative when taking power from the grid #GWh
    D_ELA = mod.ext[:variables][:D_ELA] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, base_name="elastic demand") #GWh
    

    # CVAR
    α = mod.ext[:variables][:α] = @variable(mod, base_name = "VaR") # 10^6 € Profit value at Risk (boundary value)
    u = mod.ext[:variables][:u] = @variable(mod, [jy = JY], lower_bound = 0, base_name = "mean tail risk")  # profit difference of worst-case tail scenarios with respect to the VaR # 10^6 €

    # Create affine expressions (per year)
    utility_term = mod.ext[:expressions][:utility_term] = @expression(mod, [jh=JH, jd=JD, jy=JY], WTP * D_ELA[jh,jd,jy] - (WTP / (2 * D_ELA_max[jh,jd,jy])) * D_ELA[jh,jd,jy]^2) # 10^6€
    consumer_settlement = mod.ext[:expressions][:consumer_settlement] = @expression(mod,[jh=JH, jd=JD, jy=JY], λ_EOM[jh, jd, jy] * g[jh, jd, jy]) # 10^6 €
    consumer_profit = mod.ext[:expressions][:consumer_profit] = @expression(mod, [jy = JY], sum( W[jd, jy] * (utility_term[jh, jd, jy] + consumer_settlement[jh,jd,jy]) for jh in JH, jd in JD)) # at consumption g < 0 = already negative = costs, otherwise added to profit
    consumer_penalty = mod.ext[:expressions][:consumer_penalty] = @expression(mod,[jy=JY], sum(ρ_EOM/2 * W[jd,jy]*(g[jh,jd,jy] - g_bar[jh,jd,jy])^2 for jh in JH, jd in JD)) # 10^6 €
    
    # Risk aversion
    CVAR = mod.ext[:expressions][:CVAR] = @expression(mod, α - ((1/β) * sum(P[jy] * u[jy] for jy in JY))) # 10^6 € = the mean profit in the worst tail of all scenarios 

    if market_design == "EOM"
    # Build objective function (over all years) # 10^6 €
    objective_consumer = mod.ext[:expressions][:objective_consumer] = @expression(mod,          
        - γ * sum(P[jy] * consumer_profit[jy] for jy in JY) # profit is negative = cost revenue 
        - (1 - γ) * CVAR # maximize the mean profit in the worst tail; optimizing downside-risk 
        + sum(P[jy] * consumer_penalty[jy] for jy in JY))

        if γ < 1
        # CVAR constraint
        mod.ext[:constraints][:VAR_threshold] = @constraint(mod, [jy = JY],
        α - consumer_profit[jy] <= u[jy])
        end

    else market_design == "cfd"
        # cfd variables
        Q_cfd = mod.ext[:variables][:Q_cfd] = @variable(mod, upper_bound=0, base_name="Q_cfd") # cfd contracted capacity [GW]

        # cfd parameters
        λ_cfd = mod.ext[:parameters][:λ_cfd]  # 10^6 €/GWh (strike price)
        ζ_cfd = mod.ext[:parameters][:ζ_cfd]  # 10^6 €/GW/year (cfd contract premium)
        g_cfd_total = mod.ext[:parameters][:g_cfd_total] # GWh
        Q_cfd_bar = mod.ext[:parameters][:Q_cfd_bar] # GW
        ρ_cfd = mod.ext[:parameters][:ρ_cfd] # 10^6 €/GW^2
        Q_cfd_con_tot = mod.ext[:parameters][:Q_cfd_con_tot] # Total cfd contracted capacity of all consumers, perhaps not working bc of the different iteration steps, consider using Q_cfd_gen_tot instead

        # cfd expressions
        if Q_cfd_con_tot == 0
        share_cfd_con =  mod.ext[:expressions][:share_cfd_con] = @expression(mod, (0)) # or seed on small value
        else
        share_cfd_con =  mod.ext[:expressions][:share_cfd_con] = @expression(mod, (-Q_cfd/Q_cfd_con_tot))
        end
        
        cfd_payout = mod.ext[:expressions][:cfd_payout] = @expression(mod,[jy=JY], sum(W[jd,jy] * share_cfd_con * (λ_EOM[jh,jd,jy] - λ_cfd) * g_cfd_total[jh,jd,jy] for jh in JH, jd in JD)) # 10^6€
        cfd_premium = mod.ext[:expressions][:cfd_premium] = @expression(mod, ζ_cfd * Q_cfd) #10^6€
        cfd_penalty_con = mod.ext[:expressions][:cfd_penalty_con] = @expression(mod, ρ_cfd/2 * (Q_cfd - Q_cfd_bar)^2) # GW
        cfd_consumer_profit = mod.ext[:expressions][:cfd_consumer_profit] = @expression(mod, [jy=JY], consumer_profit[jy] + cfd_payout[jy]+ cfd_premium)

        # Redefine objective for cfd scenario
        objective_consumer = mod.ext[:expressions][:objective_consumer] = @expression(mod,            
            - γ * (sum(P[jy] * cfd_consumer_profit[jy] for jy in JY))
            - γ * cfd_premium # since Q_cfd is negative for consumers, premium is a cost and is added with a minus sign to the objective
            - (1 - γ) * CVAR
            + sum(P[jy] * consumer_penalty[jy] for jy in JY)
            + cfd_penalty_con
        )

        if γ < 1
            # CVAR constraint
            mod.ext[:constraints][:VAR_threshold] = @constraint(mod, [jy = JY],
            α - (cfd_consumer_profit[jy] + cfd_premium) <= u[jy]) # only look at downside risk
        end
        
        #mod.ext[:constraints][:cfd_demand_constraint] = @constraint(mod, [jy in JY, jd in JD, jh in JH], Q_cfd >= - sum(D_fixed[jh,jd,jy] + D_ELA_max[jh,jd,jy] for jh in JH, jd in JD))
        
        #mod.ext[:constraints][:share_cap] = @constraint(mod, 0 <= share_cfd_con <= 1)
        #mod.ext[:constraints][:share_cap_upper] = @constraint(mod, share_cfd_con <= 1)
        #mod.ext[:constraints][:share_cap_lower] = @constraint(mod, share_cfd_con >= 0)
    end
    
    mod.ext[:objective] = @objective(mod, Min, objective_consumer)
    
    # Energy balance
    mod.ext[:constraints][:energy_balance] = @constraint(mod, [jh=JH, jd=JD, jy=JY],
    g[jh,jd,jy] == - D_fixed[jh,jd,jy] - D_ELA[jh,jd,jy] + PV[jh,jd,jy] - charge[jh,jd,jy] + discharge[jh,jd,jy] #GWh
    )
    mod.ext[:constraints][:D_ELA] = @constraint(mod, [jh=JH, jd=JD, jy=JY],
    D_ELA[jh,jd,jy] <= D_ELA_max[jh,jd,jy] #GWh
    )
    
if has_battery
# Battery model

# upper bounds are in variable definitions: charge <= wwith, discharge <= winj, SOC <= cap_smax
# no end SOC constraint: , no constraint on charge and discharge at the same time

# SOC dynamics: t-1 → t
mod.ext[:constraints][:state_of_charge] = @constraint(mod, [jy=JY, jd=JD, jh in JH[2:end]],
    SOC[jh,jd,jy] == SOC[jh-1,jd,jy] * Decay + EC * charge[jh-1,jd,jy] - discharge[jh-1,jd,jy]/ED)

# Battery can only charge from PV production = no arbitrage from low prices: use PV or store PV
#mod.ext[:constraints][:PV_battery_charge] = @constraint(mod, [jy=JY, jd=JD, jh=JH], 
#    charge[jh,jd,jy] <= PV[jh,jd,jy])

# Initial SOC
mod.ext[:constraints][:initial_SOC] = @constraint(mod, [jy=JY, jd=JD], SOC[first(JH), jd, jy] == 0)
# SOC end: only intraday optimization for battery
#mod.ext[:constraints][:SOC_end] = @constraint(mod, [jd=JD, jy=JY], SOC[last(JH), jd, jy] == SOC[first(JH), jd, jy])

# Discharge limit vs previous SOC
mod.ext[:constraints][:start_discharge] = @constraint(mod, [jd=JD, jy=JY], discharge[first(JH), jd, jy] <= ED * Decay * SOC[first(JH), jd, jy])
mod.ext[:constraints][:discharge] = @constraint(mod, [jh in JH[2:end], jd=JD, jy=JY], discharge[jh, jd, jy] <= ED * Decay * SOC[jh-1, jd, jy]) # Discharge cannot exceed state of charge adjusted for efficiency
end

    return mod
end