function ADMM_subroutine!(m::String,results::Dict,ADMM::Dict,EOM::Dict,mod::Model,agents::Dict,TO::TimerOutput,market_design:: AbstractString)
TO_local = TimerOutput()
# Calculate penalty terms ADMM and update price to most recent value 
@timeit TO_local "Compute ADMM penalty terms" begin
    mod.ext[:parameters][:g_bar] = results["g"][m][end] - 1/(EOM["nAgents"]+1)*ADMM["Imbalances"]["EOM"][end]
    mod.ext[:parameters][:λ_EOM] = results["λ"]["EOM"][end]
    mod.ext[:parameters][:ρ_EOM] = ADMM["ρ"]["EOM"][end]

if market_design == "CfD"
    
    Q_cfd_gen_tot = sum(results["Q_cfd_gen"][m][end] for m in agents[:Gen])
    Q_cfd_con_tot = sum(results["Q_cfd_con"][m][end] for m in agents[:Cons])

    if m in agents[:Gen]
        mod.ext[:parameters][:Q_cfd_bar] =
            results["Q_cfd_gen"][m][end] -
            (1 / (EOM["nAgents"]+1)) * ADMM["Imbalances"]["CfD"][end]
            push!(results["Q_cfd_bar"][m], mod.ext[:parameters][:Q_cfd_bar])
    
    elseif m in agents[:Cons]
        mod.ext[:parameters][:Q_cfd_bar] =
        results["Q_cfd_con"][m][end] +
        (1 / (EOM["nAgents"]+1)) * ADMM["Imbalances"]["CfD"][end]
        push!(results["Q_cfd_bar"][m], mod.ext[:parameters][:Q_cfd_bar])
    end

    #mod.ext[:parameters][:Q_cfd_bar] = (Q_cfd_gen_tot + Q_cfd_con_tot) / 2
    mod.ext[:parameters][:ζ_cfd] = results["ζ"]["CfD"][end]
    mod.ext[:parameters][:ρ_CfD] = ADMM["ρ"]["CfD"][end]
    mod.ext[:parameters][:Q_cfd_con_tot] = Q_cfd_con_tot

    if m in agents[:Cons]
        push!(results["Q_cfd_con_tot"], Q_cfd_con_tot)
        mod.ext[:parameters][:Q_cfd_con_tot] = Q_cfd_con_tot
    end
end

# Solve agents decision problems:
if m in agents[:Gen]
    @timeit TO_local "Solve generator problems" begin
        solve_generator_agent!(mod, market_design,m)

        # Aggregate g_cfd from all generators
        if market_design == "CfD" && !isempty(agents[:Gen])
            g_cfd_agg = zeros(data["General"]["nTimesteps"])
            for gen in agents[:Gen]
                g_cfd_agg .+= results["g_cfd"][gen][end] # .+= element-wise addtion for all time steps
            end
            push!(results["g_cfd_total"], g_cfd_agg)
            push!(results["cfd_payout_gen"][m], collect(value.(mod.ext[:expressions][:cfd_payout_gen])))
            push!(results["cfd_premium_gen"][m], value(mod.ext[:expressions][:cfd_premium_gen]))
            push!(results["cfd_penalty_gen"][m], value(mod.ext[:expressions][:cfd_penalty_gen]))
        end

    end

elseif m in agents[:Cons]
    @timeit TO_local "Solve consumer problems" begin
        solve_consumer_agent!(mod, market_design,m)
        if market_design == "CfD"
            push!(results["cfd_payout"][m], collect(value.(mod.ext[:expressions][:cfd_payout])))
            push!(results["cfd_premium"][m], value(mod.ext[:expressions][:cfd_premium]))
            push!(results["cfd_penalty_con"][m], value(mod.ext[:expressions][:cfd_penalty_con]))
        end
    end
end

end

# Query results
@timeit TO_local "Query results" begin
    if has_values(mod)
        push!(results["g"][m], collect(value.(mod.ext[:variables][:g])))
        
        if market_design == "CfD"
            if m in agents[:Gen]
                push!(results["g_cfd"][m], collect(value.(mod.ext[:variables][:g_cfd]))) # dictionary of optimal values for g_cfd > vector of current iteration pushed into circular buffer
                push!(results["Q_cfd_gen"][m], value(mod.ext[:variables][:Q_cfd_gen])) # scalar variable
                #println("[$m] Q_cfd_gen = ", value(mod.ext[:variables][:Q_cfd_gen]))
            
            elseif m in agents[:Cons]
                push!(results["Q_cfd_con"][m], value(mod.ext[:variables][:Q_cfd_con])) # scalar variable
            end
        end
    end
    # add similar line for variable necessary for computing imbalances, primal/dual res etc. (Q_CfD, g_cfd)
end

# Merge local TO with TO:
merge!(TO,TO_local)
end