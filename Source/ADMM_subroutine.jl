function ADMM_subroutine!(m::String,results::Dict,ADMM::Dict,EOM::Dict,mod::Model,agents::Dict,TO::TimerOutput,market_design:: AbstractString)
    TO_local = TimerOutput()
    
    # Calculate penalty terms ADMM and update price to most recent value 

    @timeit TO_local "Compute ADMM penalty terms" begin
        mod.ext[:parameters][:g_bar] = results["g"][m][end] - 1/(EOM["nAgents"]+1)*ADMM["Imbalances"]["EOM"][end] # local solution - scaled imbalance
        mod.ext[:parameters][:λ_EOM] = results["λ"]["EOM"][end]
        mod.ext[:parameters][:ρ_EOM] = ADMM["ρ"]["EOM"][end]

    if market_design == "cfd"
        Qgen_sum = sum([last(results["Q_cfd_gen"][g]) for g in agents[:Gen]])
        Qcon_sum = sum([last(results["Q_cfd_con"][c]) for c in agents[:Cons]])

        Qbar_gen = Qgen_sum ./ length(agents[:Gen])
        Qbar_con = Qcon_sum ./ length(agents[:Cons])

        for g in agents[:Gen]
            mdict[g].ext[:parameters][:Q_cfd_bar] = Qbar_gen
            push!(results["Q_cfd_bar"][g], Qbar_gen)
        end

        for c in agents[:Cons]
            mdict[c].ext[:parameters][:Q_cfd_bar] = Qbar_con
            push!(results["Q_cfd_bar"][c], Qbar_con)
        end
        mod.ext[:parameters][:ζ_cfd] = results["ζ"]["cfd"][end]
        mod.ext[:parameters][:ρ_cfd] = ADMM["ρ"]["cfd"][end]
    end

     #= all agents see the same consensus variable
       Qgen_sum = reduce(+, (last(results["Q_cfd_gen"][g]) for g in agents[:Gen]))
       Qcon_sum = reduce(+, (last(results["Q_cfd_con"][c]) for c in agents[:Cons]))

       Qbar = (Qgen_sum .+ Qcon_sum) ./ (EOM["nAgents"])  # ::Vector{Float64} met lengte nY

        for m in agents[:eom]
            mdict[m].ext[:parameters][:Q_cfd_bar] = Qbar
            push!(results["Q_cfd_bar"][m], Qbar)  # als je per agent een historiek bewaart
        end =#   

        #= if m in agents[:Gen]
                mod.ext[:parameters][:Q_cfd_bar] =
                    results["Q_cfd_gen"][m][end] -
                    (1 / (EOM["nAgents"])) * ADMM["Imbalances"]["CfD"][end]
                    push!(results["Q_cfd_bar"][m], mod.ext[:parameters][:Q_cfd_bar])
            
            elseif m in agents[:Cons]
                mod.ext[:parameters][:Q_cfd_bar] =
                results["Q_cfd_con"][m][end] -
                (1 / (EOM["nAgents"])) * ADMM["Imbalances"]["CfD"][end]
                push!(results["Q_cfd_bar"][m], mod.ext[:parameters][:Q_cfd_bar])
            end =#

        #= cfd consensus variables have two updates; since generators are positive in imbalance and consumers are negative in the imbalance: Q_cfd are defined as positive value in the imbalance constraint
          if m in agents[:Gen]
            mod.ext[:parameters][:Q_cfd_bar] = results["Q_cfd_gen"][m][end] .- ADMM["Imbalances"]["cfd"][end] ./ (2 * length(agents[:Gen]))
            push!(results["Q_cfd_bar"][m], mod.ext[:parameters][:Q_cfd_bar])
        
        elseif m in agents[:Cons]
            mod.ext[:parameters][:Q_cfd_bar] = results["Q_cfd_con"][m][end] .+ ADMM["Imbalances"]["cfd"][end] ./ (2 * length(agents[:Cons])) 
            push!(results["Q_cfd_bar"][m], mod.ext[:parameters][:Q_cfd_bar])
        end
    end =#

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
                    push!(results["share_cfd_con"][m], collect(value.(mod.ext[:expressions][:share_cfd_con])))
                    #push!(results["Q_cfd_con_tot"][m], collect(value.(mod.ext[:parameters][:Q_cfd_con_tot])))
                end
            end
        end
        # add similar line for variable necessary for computing imbalances, primal/dual res etc. (Q_cfd, g_cfd)
    end

    # Merge local TO with TO:
    merge!(TO,TO_local)
    end