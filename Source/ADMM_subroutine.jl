function ADMM_subroutine!(m::String,results::Dict,ADMM::Dict,EOM::Dict,mod::Model,agents::Dict,TO::TimerOutput,market_design:: AbstractString)
    TO_local = TimerOutput()
    
    # Calculate penalty terms ADMM and update price to most recent value 

    @timeit TO_local "Compute ADMM penalty terms" begin
        mod.ext[:parameters][:g_bar] = results["g"][m][end] - 1/(EOM["nAgents"]+1)*ADMM["Imbalances"]["EOM"][end]
        mod.ext[:parameters][:λ_EOM] = results["λ"]["EOM"][end]
        mod.ext[:parameters][:ρ_EOM] = ADMM["ρ"]["EOM"][end]

    if market_design == "cfd"
        mod.ext[:parameters][:ζ_cfd] = results["ζ"]["cfd"][end]
        mod.ext[:parameters][:ρ_cfd] = ADMM["ρ"]["cfd"][end]

        if m in agents[:Gen]
            mod.ext[:parameters][:Q_cfd_bar] = results["Q_cfd_gen"][m][end] .- (1 / (EOM["nAgents"])) * ADMM["Imbalances"]["cfd"][end]
            push!(results["Q_cfd_bar"][m], mod.ext[:parameters][:Q_cfd_bar])
        
        elseif m in agents[:Cons]
            mod.ext[:parameters][:Q_cfd_bar] = results["Q_cfd_con"][m][end] .- (1 / (EOM["nAgents"])) * ADMM["Imbalances"]["cfd"][end]
            push!(results["Q_cfd_bar"][m], mod.ext[:parameters][:Q_cfd_bar])
        end
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
                
                # expressions
                #= push!(results["utility_term"][m], collect(value.(mod.ext[:expressions][:utility_term])))
                push!(results["consumer_costs"][m], collect(value.(mod.ext[:expressions][:consumer_costs])))
                push!(results["consumer_profit"][m], collect(value.(mod.ext[:expressions][:consumer_profit])))
                push!(results["consumer_penalty"][m], collect(value.(mod.ext[:expressions][:consumer_penalty])))
                push!(results["exp_cons_prof"][m], collect(value.(mod.ext[:expressions][:expected_consumer_profit])))
                push!(results["consumer_var"][m], collect(value.(mod.ext[:expressions][:consumer_var])))
                push!(results["consumer_mv"][m], collect(value.(mod.ext[:expressions][:consumer_mv]))) =#
            end

           #= if m in agents[:Gen]
                # expressions
                push!(results["generator_costs"][m], collect(value.(mod.ext[:expressions][:generator_costs])))
                push!(results["generator_revenue"][m], collect(value.(mod.ext[:expressions][:generator_revenue])))
                push!(results["generator_profit"][m], collect(value.(mod.ext[:expressions][:generator_profit])))
                push!(results["generator_penalty"][m], collect(value.(mod.ext[:expressions][:generator_penalty])))
                push!(results["exp_gen_prof"][m], collect(value.(mod.ext[:expressions][:exp_gen_prof])))
                push!(results["generator_var"][m], collect(value.(mod.ext[:expressions][:generator_var])))
                push!(results["generator_mv"][m], collect(value.(mod.ext[:expressions][:generator_mv])))
            end =#

            if market_design == "cfd"
                if m in agents[:Gen]
                    push!(results["g_cfd"][m], collect(value.(mod.ext[:variables][:g_cfd]))) # dictionary of optimal values for g_cfd > vector of current iteration pushed into circular buffer
                    push!(results["Q_cfd_gen"][m], collect(value.(mod.ext[:variables][:Q_cfd_gen])))
                    #println("[$m] Q_cfd_gen = ", value(mod.ext[:variables][:Q_cfd_gen]))
                    push!(results["cfd_payout_gen"][m], collect(value.(mod.ext[:expressions][:cfd_payout_gen])))
                    push!(results["cfd_premium_gen"][m], collect(value.(mod.ext[:expressions][:cfd_premium_gen])))
                    push!(results["cfd_penalty_gen"][m], collect(value.(mod.ext[:expressions][:cfd_penalty_gen])))
                
                elseif m in agents[:Cons]
                    push!(results["Q_cfd_con"][m], collect(value.(mod.ext[:variables][:Q_cfd_con])))

                    push!(results["cfd_payout"][m], collect(value.(mod.ext[:expressions][:cfd_payout])))
                    push!(results["cfd_premium"][m], collect(value.(mod.ext[:expressions][:cfd_premium])))
                    push!(results["cfd_penalty_con"][m], collect(value.(mod.ext[:expressions][:cfd_penalty_con])))
                end
            end
        end
        # add similar line for variable necessary for computing imbalances, primal/dual res etc. (Q_cfd, g_cfd)
    end

    # Merge local TO with TO:
    merge!(TO,TO_local)
    end