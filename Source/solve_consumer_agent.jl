function solve_consumer_agent!(mod::Model)
   # Extract sets
   JH = mod.ext[:sets][:JH]
   PV = mod.ext[:timeseries][:PV]

   # Extract parameters
   λ_EOM = mod.ext[:parameters][:λ_EOM] # EOM prices
   g_bar = mod.ext[:parameters][:g_bar] # element in ADMM penalty term related to EOM
   ρ_EOM = mod.ext[:parameters][:ρ_EOM] # rho-value in ADMM related to EOM auctions
   D_ELA_max = mod.ext[:parameters][:D_ELA_max]  # Max elastic demand
   D_fixed = mod.ext[:parameters][:D_fixed] 

   # Create variables
   g = mod.ext[:variables][:g]  
   D_ELA = mod.ext[:variables][:D_ELA]
   charge = mod.ext[:variables][:charge] = @variable(mod, [jh=JH], base_name="charge") # charge
   discharge = mod.ext[:variables][:discharge] = @variable(mod, [jh=JH], base_name="discharge") # discharge

   # Create affine expressions
   utility_term = mod.ext[:expressions][:utility_term]

   # Objective 
   mod.ext[:objective] = @objective(mod, Min,
       - sum(λ_EOM[jh]*g[jh] for jh in JH)
       + sum(ρ_EOM/2*(g[jh] - g_bar[jh])^2 for jh in JH)
       - sum(utility_term[jh] for jh in JH) # Utility term

     #  + sum(λ_EOM[jh] * charge[jh] for jh in JH)  # Charging cost
     #  - sum(λ_EOM[jh] * discharge[jh] for jh in JH)  # Discharging revenue
   )
   # Demand constraint with price elasticity 
    for jh in JH 
        delete(mod, mod.ext[:constraints][:energy_balance][jh]) #remove previous constraint that is dependent on the price
    end

    mod.ext[:constraints][:energy_balance] = @constraint(mod, [jh in JH],
    g[jh] == -(D_fixed[jh]+D_ELA[jh] - PV[jh])- charge[jh] + discharge[jh]
    )
    mod.ext[:constraints][:elastic_demand] = @constraint(mod, [jh in JH],
    D_ELA[jh] <= D_ELA_max[jh]
    )

#    mod.ext[:constraints][:demand_balance] = @constraint(mod, [jh in JH],
#    g[jh] <= PV[jh] - D_fixed[jh] - D_elastic[jh] * (1 + elasticity * λ_EOM[jh])
#    )
   # mod.ext[:constraints][:demand_balance] = @constraint(mod, [jh in JH],
   # g[jh] <= D_fixed[jh] + D_elastic[jh] * (1 + elasticity * λ_EOM[jh])
  #  )
    # @constraint(mod, [jh in JH], charge[jh] <= PV[jh]) # Battery can only charge from PV production or the grid
    optimize!(mod);
   
    consumer_models = Dict(
      name => mod for (name, mod) in mdict if startswith(name, "Type")
  )
  for (name, mod) in consumer_models
    JH = mod.ext[:sets][:JH]
    cfd_saving = mod.ext[:expressions][:cfd_saving]
    total_saving = sum(value(cfd_saving[jh]) for jh in JH)

    println("💰 Total CfD saving for $name = €", round(total_saving, digits=2))
  end
    return mod
end