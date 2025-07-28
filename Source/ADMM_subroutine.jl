function ADMM_subroutine!(m::String,results::Dict,ADMM::Dict,EOM::Dict,mod::Model,agents::Dict,TO::TimerOutput,market_design:: AbstractString)
TO_local = TimerOutput()
# Calculate penalty terms ADMM and update price to most recent value 
@timeit TO_local "Compute ADMM penalty terms" begin
    mod.ext[:parameters][:g_bar] = results["g"][m][end] - 1/(EOM["nAgents"]+1)*ADMM["Imbalances"]["EOM"][end]
    mod.ext[:parameters][:λ_EOM] = results["λ"]["EOM"][end]
    mod.ext[:parameters][:ρ_EOM] = ADMM["ρ"]["EOM"][end]
    
    if market_design == "CfD"
        Q_gen_cfd_tot = sum(results["Q_cfd_gen"][gen][end] for gen in agents[:Gen])
        Q_con_cfd_tot = sum(results["Q_cfd_con"][con][end] for con in agents[:Cons])
        mod.ext[:parameters][:Q_cfd_bar] = (Q_gen_cfd_tot + Q_con_cfd_tot) / 2

        mod.ext[:parameters][:ζ_cfd] = results["ζ"]["CfD"][end]
        mod.ext[:parameters][:ρ_CfD] = ADMM["ρ"]["CfD"][end]

        if m in agents[:Cons]
            push!(results["Q_cfd_con_tot"], Q_con_cfd_tot)
            mod.ext[:parameters][:Q_cfd_con_tot] = Q_con_cfd_tot
        end
    end
end

# Solve agents decision problems:
if m in agents[:Gen]
    @timeit TO_local "Solve generator problems" begin
        solve_generator_agent!(mod, market_design,m)  
    end
elseif m in agents[:Cons]
    @timeit TO_local "Solve consumer problems" begin
        solve_consumer_agent!(mod, market_design,m)  
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
            elseif m in agents[:Cons]
                push!(results["Q_cfd_con"][m], value(mod.ext[:variables][:Q_cfd_con])) # scalar variable
            end
        end 
    else
        @warn "No solution found for agent $m. Skipping result extraction."
    end
    # add similar line for variable necessary for computing imbalances, primal/dual res etc. (Q_CfD, g_cfd)
end

# Merge local TO with TO:
merge!(TO,TO_local)
end