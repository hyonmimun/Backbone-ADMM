function build_consumer_agent!(mod::Model,market_design::AbstractString)
    # Extract sets
    JY = mod.ext[:sets][:JY]
    JD = mod.ext[:sets][:JD]
    JH = mod.ext[:sets][:JH]

    nY = data["General"]["nYears"]
    nR = data["General"]["nReprDays"]
    nT = data["General"]["nTimesteps"]

    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year

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
    W = mod.ext[:parameters][:W] # weight of representative day
    P = mod.ext[:parameters][:P]
    β = mod.ext[:parameters][:β] # risk aversion parameter

    # Battery parameters
    cap_smax = mod.ext[:parameters][:cap_smax] # Battery capacity
    EC = mod.ext[:parameters][:EC] # Charging efficiency
    ED = mod.ext[:parameters][:ED] # Discharging efficiency
    Decay = mod.ext[:parameters][:Decay] # Hourly decay
    winj = mod.ext[:parameters][:winj] # Max charging power
    wwith = mod.ext[:parameters][:wwith] # Max discharging power
    #SOC_init = mod.ext[:parameters][:SOC_init] # initial SOC

    # Create variables
    g = mod.ext[:variables][:g] = @variable(mod, [jh=JH, jd=JD, jy=JY], base_name="generation")  # positive if consumer feeds power to the rest of the system, negative when taking power from the grid
    D_ELA = mod.ext[:variables][:D_ELA] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, base_name="elastic demand")
    SOC = mod.ext[:variables][:SOC] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, upper_bound = cap_smax, base_name="SOC") # state of charge battery
    charge = mod.ext[:variables][:charge] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, upper_bound= winj, base_name="charge")
    discharge = mod.ext[:variables][:discharge] = @variable(mod, [jh=JH, jd=JD, jy=JY], lower_bound=0, upper_bound = wwith, base_name="discharge")

    # Create affine expressions (per year)
    utility_term = mod.ext[:expressions][:utility_term] = @expression(mod, [jh=JH, jd=JD, jy=JY], WTP * D_ELA[jh,jd,jy] - (WTP / (2 * D_ELA_max[jh,jd,jy])) * D_ELA[jh,jd,jy]^2)
    consumer_costs = mod.ext[:expressions][:consumer_costs] = @expression(mod,[jh=JH, jd=JD, jy=JY], λ_EOM[jh, jd, jy] * - g[jh, jd, jy]) # import = -g
    
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
        Q_cfd_con = mod.ext[:variables][:Q_cfd_con] = @variable(mod,[jy=JY], lower_bound=0, base_name="CfD_contracted_capacity") # cfd contracted capacity [MW]

        # cfd parameters
        λ_cfd = mod.ext[:parameters][:λ_cfd]  # €/MWh (strike price)
        ζ_cfd = mod.ext[:parameters][:ζ_cfd]  # €/MWh (cfd contract premium)
        g_cfd_total = mod.ext[:parameters][:g_cfd_total] # Total generation of all generators under cfd
        Q_cfd_bar = mod.ext[:parameters][:Q_cfd_bar] # Average cfd contracted capacity across all agents [MW]
        ρ_cfd = mod.ext[:parameters][:ρ_cfd] # rho-value in ADMM related to cfd auctions
        Q_cfd_con_tot = mod.ext[:parameters][:Q_cfd_con_tot] # Total cfd contracted capacity of all consumers, perhaps not working bc of the different iteration steps, consider using Q_cfd_gen_tot instead


        # cfd expressions (per year)
        share_cfd_con =  mod.ext[:expressions][:share_cfd_con] = @expression(mod,[jy=JY], Q_cfd_con[jy] / (Q_cfd_con_tot[jy]+0.00001)) # Adding a small value to avoid dividing by zero
        cfd_payout = mod.ext[:expressions][:cfd_payout] = @expression(mod,[jy=JY], sum(W[jd,jy] * share_cfd_con[jy] * (λ_EOM[jh,jd,jy] - λ_cfd) * g_cfd_total[jh,jd,jy] for jh in JH, jd in JD))
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

        mod.ext[:constraints][:cfd_demand_constraint] = @constraint(mod, [jy=JY],
        Q_cfd_con[jy] <= sum(D_fixed[jh,jd,jy] + D_ELA_max[jh,jd,jy] for jh in JH, jd in JD)
        )
    end
    
    mod.ext[:objective] = @objective(mod, Min, objective_consumer)
    
    # Energy balance
    mod.ext[:constraints][:energy_balance] = @constraint(mod, [jh=JH, jd=JD, jy=JY],
    g[jh,jd,jy] == - D_fixed[jh,jd,jy] - D_ELA[jh,jd,jy] + PV[jh,jd,jy] - charge[jh,jd,jy] + discharge[jh,jd,jy]
    )
    mod.ext[:constraints][:D_fixed] = @constraint(mod, [jh=JH, jd=JD, jy=JY],
    D_fixed[jh,jd,jy] >= 0 # Fixed demand cannot be negative
    )
    mod.ext[:constraints][:D_ELA] = @constraint(mod, [jh=JH, jd=JD, jy=JY],
    D_ELA[jh,jd,jy] <= D_ELA_max[jh,jd,jy] # Fixed demand cannot be negative
    )

    # Battery model 
    #= mod.ext[:constraints][:state_of_charge] = @constraint(mod, [jy=JY,jd=JD,jh in JH[2:end]],
    SOC[jh,jd,jy] == SOC[jh-1,jd,jy]* Decay + charge[jh-1,jd,jy] * EC - discharge[jh-1,jd,jy]/ ED
    )

    #= mod.ext[:constraints][:state_of_charge] = @constraint(mod, [jy=JY, jd=JD, jh in JH[2:end]],
    SOC[jh, jd, jy] == SOC[jh-1, jd, jy] * Decay
                      + EC * charge[jh, jd, jy]
                      - discharge[jh, jd, jy] / ED
    ) =#
    #mod.ext[:constraints][:soc] = @constraint(mod, [jh=JH, jd=JD, jy=JY; jh > first(JH)],
    #SOC[jh-1,jd,jy] * Decay + EC * charge[jh,jd,jy] <= cap_smax
#)
    mod.ext[:constraints][:start_discharge] = @constraint(mod, [jd=JD, jy=JY],
    discharge[first(JH), jd, jy] <= ED * SOC[first(JH), jd, jy]
)
    # alle volgende uren
    mod.ext[:constraints][:discharge] = @constraint(mod, [jh in JH[2:end], jd=JD, jy=JY],
        discharge[jh, jd, jy] <= ED * SOC[jh-1, jd, jy]
    )

    mod.ext[:constraints][:initial_SOC] = @constraint(mod, [jy=JY, jd=JD], SOC[1,jd,jy] == 0.2 * cap_smax) # perhaps set higher? 
    
    #= at end timestep the SOC is equal to the initital SOC
    #mod.ext[:constraints][:end_SOC] =
    #@constraint(mod, [jy=JY, jd=JD], SOC[end,jd,jy] >= min_soc
    #)

    mod.ext[:constraints][:discharge] = @constraint(mod, [jh=JH, jd=JD, jy=JY],
    discharge[jh,jd,jy] <= SOC[jh,jd,jy] # Discharge cannot exceed state of charge adjusted for efficiency
    ) =#
=#

# SOC dynamics: t-1 → t
mod.ext[:constraints][:state_of_charge] = @constraint(mod, [jy=JY, jd=JD, jh in JH[2:end]],
    SOC[jh,jd,jy] == SOC[jh-1,jd,jy]*Decay
                      + EC * charge[jh-1,jd,jy]
                      - discharge[jh-1,jd,jy]/ED
)

# Initial SOC: geef startvoorraad (20% van cap). GEEN end-SOC equality!
mod.ext[:constraints][:initial_SOC] =
    @constraint(mod, [jy=JY, jd=JD], SOC[first(JH), jd, jy] == 0.2 * cap_smax)

# Discharge limit vs previous SOC
mod.ext[:constraints][:start_discharge] =
    @constraint(mod, [jd=JD, jy=JY],
        discharge[first(JH), jd, jy] <= ED * SOC[first(JH), jd, jy])

mod.ext[:constraints][:discharge] =
    @constraint(mod, [jh in JH[2:end], jd=JD, jy=JY],
        discharge[jh, jd, jy] <= ED * SOC[jh-1, jd, jy])
    return mod
end