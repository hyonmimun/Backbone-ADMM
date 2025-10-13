function ADMM_subroutine!(m::String,results::Dict,ADMM::Dict,EOM::Dict,mod::Model,agents::Dict,TO::TimerOutput,market_design:: AbstractString)
    TO_local = TimerOutput()
    
    # Calculate penalty terms ADMM and update price to most recent value 
    @timeit TO_local "Compute ADMM penalty terms" begin
        mod.ext[:parameters][:g_bar] = results["g"][m][end] - 1/(EOM["nAgents"]+1)*ADMM["Imbalances"]["EOM"][end] # local solution - scaled imbalance
        mod.ext[:parameters][:λ_EOM] = results["λ"]["EOM"][end]
        mod.ext[:parameters][:ρ_EOM] = ADMM["ρ"]["EOM"][end]

        if market_design == "cfd"
        mod.ext[:parameters][:ζ_cfd] = results["ζ"]["cfd"][end]
        mod.ext[:parameters][:ρ_cfd] = ADMM["ρ"]["cfd"][end]
        mod.ext[:parameters][:Q_cfd_bar] = results["Q_cfd"][m][end] - 1/(EOM["nAgents"]+1)*ADMM["Imbalances"]["cfd"][end]
            #=if m in agents[:Gen]
                mod.ext[:parameters][:Q_cfd_bar] = results["Q_cfd"][m][end] - 1/(EOM["nAgents"]+1)*ADMM["Imbalances"]["cfd"][end]
            elseif m in agents[:Cons]
                # Note the + sign here since consumers have negative Q_cfd
                mod.ext[:parameters][:Q_cfd_bar] = results["Q_cfd"][m][end] + 1/(EOM["nAgents"]+1)*ADMM["Imbalances"]["cfd"][end]
            end =#
        #@show mod.ext[:parameters][:Q_cfd_bar]
        #@show mod.ext[:parameters][:ζ_cfd]
        end

    # Solve agents decision problems:
    if m in agents[:Gen]
        @timeit TO_local "Solve generator problems" begin
            solve_generator_agent!(mod, market_design, m)
        end
    elseif m in agents[:Cons]
        @timeit TO_local "Solve consumer problems" begin
            solve_consumer_agent!(mod, market_design,m)
        end
    end
    end

    # Query results
    @timeit TO_local "Query results" begin
        if has_values(mod)
            push!(results["g"][m], collect(value.(mod.ext[:variables][:g])))

            if m in agents[:Cons]
                # variables
                push!(results["D_ELA"][m], collect(value.(mod.ext[:variables][:D_ELA])))
                push!(results["SOC"][m], collect(value.(mod.ext[:variables][:SOC])))
                push!(results["charge"][m], collect(value.(mod.ext[:variables][:charge])))
                push!(results["discharge"][m], collect(value.(mod.ext[:variables][:discharge])))
            end

            if market_design == "cfd"
                if m in agents[:Gen]
                # data for every timestep
                    push!(results["g_cfd"][m], collect(value.(mod.ext[:variables][:g_cfd])))
                    push!(results["cfd_payout_gen"][m], collect(value.(mod.ext[:expressions][:cfd_payout_gen])))
                elseif m in agents[:Cons]    
                    push!(results["cfd_payout"][m], collect(value.(mod.ext[:expressions][:cfd_payout])))
                    #push!(results["Q_cfd_con_tot"][m], collect(value.(mod.ext[:parameters][:Q_cfd_con_tot])))
                end
            end
        end
        # add similar line for variable necessary for computing imbalances, primal/dual res etc. (Q_cfd, g_cfd)
    end

    # Merge local TO with TO:
    merge!(TO,TO_local)
    end