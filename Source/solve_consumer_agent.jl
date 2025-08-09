function solve_consumer_agent!(mod::Model,market_design::AbstractString, m::String)
   # Extract sets
   JH = mod.ext[:sets][:JH]
   PV = mod.ext[:timeseries][:PV]
   D = mod.ext[:timeseries][:D]

   # Extract parameters
   λ_EOM = mod.ext[:parameters][:λ_EOM] # EOM prices
   g_bar = mod.ext[:parameters][:g_bar] # element in ADMM penalty term related to EOM
   ρ_EOM = mod.ext[:parameters][:ρ_EOM] # rho-value in ADMM related to EOM auctions
   D_ELA_max = mod.ext[:parameters][:D_ELA_max]  # Max elastic demand
   WTP = mod.ext[:parameters][:WTP]
   D_fixed = mod.ext[:parameters][:D_fixed] 
   
   cap_smax = mod.ext[:parameters][:cap_smax] # Battery capacity
   EC = mod.ext[:parameters][:EC] # Charging efficiency
   ED = mod.ext[:parameters][:ED] # Discharging efficiency
   Decay = mod.ext[:parameters][:Decay] # Hourly decay

   # Create variables
   g = mod.ext[:variables][:g]  
   D_ELA = mod.ext[:variables][:D_ELA]
   charge = mod.ext[:variables][:charge]
   discharge = mod.ext[:variables][:discharge]
   SOC = mod.ext[:variables][:SOC]

   # Create affine expressions
   utility_term = mod.ext[:expressions][:utility_term] = @expression(mod, [jh in JH], WTP * D_ELA[jh] - (WTP / (2 * D_ELA_max[jh])) * D_ELA[jh]^2) 
   # Redefine utility_term expression since parameters are udpated each iteration (D_ELA_max comes from time-varying demand profile)
   
   # Build objective function
   objective_consumer = mod.ext[:expressions][:objective_generator] = @expression(mod,            
        - sum(λ_EOM[jh]*g[jh] for jh in JH)
        + sum(ρ_EOM/2*(g[jh] - g_bar[jh])^2 for jh in JH)
        - sum(utility_term[jh] for jh in JH))

   if market_design == "CfD"    
        # CfD variables
        Q_cfd_con = mod.ext[:variables][:Q_cfd_con]

        # CfD parameters
        λ_cfd = mod.ext[:parameters][:λ_cfd]  # €/MWh (strike price)
        ζ_cfd = mod.ext[:parameters][:ζ_cfd]  # €/MWh (CfD contract premium)
        g_cfd_total = mod.ext[:parameters][:g_cfd_total] # total generation under CfD
        Q_cfd_bar = mod.ext[:parameters][:Q_cfd_bar] # Average CfD contracted capacity across all agents [MW]
        ρ_CfD = mod.ext[:parameters][:ρ_cfd] # rho-value in ADMM related to CfD auctions
        Q_cfd_con_tot = mod.ext[:parameters][:Q_cfd_con_tot] # Total CfD contracted capacity of all consumers

        # CfD expressions
        share_cfd_con =  mod.ext[:expressions][:share_cfd_con] = @expression(mod, Q_cfd_con / Q_cfd_con_tot)
        cfd_payout = mod.ext[:expressions][:cfd_payout] = @expression(mod, [jh in JH], share_cfd_con*(λ_EOM[jh] - λ_cfd) * g_cfd_total[jh])
        #cfd_payout = mod.ext[:expressions][:cfd_payout] = @expression(mod, [jh in JH], (λ_EOM[jh] - λ_cfd) *  Q_cfd_con)
        cfd_premium = mod.ext[:expressions][:cfd_premium] = @expression(mod, ζ_cfd * Q_cfd_con)
        cfd_penalty_con = mod.ext[:expressions][:cfd_penalty_con] = @expression(mod, ρ_CfD/2 * (Q_cfd_con - Q_cfd_bar)^2)
        #cfd_penalty_con = mod.ext[:expressions][:cfd_penalty_con] = @expression(mod, ρ_CfD/2 * ((Q_cfd_con - Q_cfd_bar)/(Q_cfd_bar + 0.0001))^2)
        
        # Redefine objective for CfD scenario
        objective_consumer = mod.ext[:expressions][:objective_generator] = @expression(mod,            
            - sum(λ_EOM[jh]*g[jh] for jh in JH)
            + sum(ρ_EOM/2*(g[jh] - g_bar[jh])^2 for jh in JH)
            - sum(utility_term[jh] for jh in JH)
            - sum(cfd_payout[jh] for jh in JH)
            + cfd_premium
            + cfd_penalty_con
            )

    end
    
    mod.ext[:objective] = @objective(mod, Min, objective_consumer)

    if haskey(mod.ext[:constraints], :energy_balance) # Check whether constraint :energybalance exists in the model
        delete.(Ref(mod), collect(mod.ext[:constraints][:energy_balance])) # Makes DenseAxisArray into vector, deletes the existing energy balance constraint if it exists
        delete!(mod.ext[:constraints], :energy_balance)  # Remove the reference/key :energy_balance from the constraints dictionary
    end

    # Redefine energy balance
    mod.ext[:constraints][:energy_balance] = @constraint(mod, [jh in JH],
    g[jh] == - D_fixed[jh] - D_ELA[jh] + PV[jh] - charge[jh] + discharge[jh]
    )

   optimize!(mod)
   return mod
end
