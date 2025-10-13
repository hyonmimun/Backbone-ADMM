# ADMM 
function ADMM!(results::Dict,ADMM::Dict,EOM::Dict,mdict::Dict,agents::Dict,scenario_overview_row::DataFrameRow,data::Dict,TO::TimerOutput,market_design::AbstractString, years::Dict)
    convergence = 0
    iterations = ProgressBar(1:data["ADMM"]["max_iter"])
    # Extract sets
    nY = data["General"]["nYears"]
    nR = data["General"]["nReprDays"]
    nT = data["General"]["nTimesteps"]

    # paths for logging
    results_dir = joinpath(home_dir,string("Results_", data["General"]["nReprDays"], "_repr_days"))
    out_dir = joinpath(results_dir, String(market_design))
    logpath = joinpath(out_dir, string(market_design, "_ADMM_residuals_all.csv"))
    isfile(logpath) && rm(logpath)

    if market_design == "cfd"
        # logging of Q_cfd values
        q_cfd_paths = joinpath(out_dir,"cfd_totals", "cfd_Q_cfd.csv")
        agent_order = [String(m) for m in agents[:all]]
            if isfile(q_cfd_paths)
                rm(q_cfd_paths; force=true)
            end
    # Headers schrijven als de CSV's nog niet bestaan
        if !isfile(q_cfd_paths)
            df0 = DataFrame()
            df0[!, :iteration] = Int[]
            for name in agent_order
                df0[!, Symbol(name)] = Float64[]
            end
            CSV.write(q_cfd_paths, df0)
        end
    end 
    
    for iter in iterations
        if convergence == 0 # convergence not reached yet; loop continues solving
           if market_design == "cfd"

                        # fix Q_cfd_con_tot on the previous iteration value whilst solving
                        Q_cfd_con_tot_prev = results["Q_cfd_con_tot"][end]
                        
                        # Totale cfd-productie (3D: tijd × repr. dag × jaar)
                        g_cfd_total_prev = results["g_cfd_total"][end]
                        
                        #println(iterations, @sprintf("Q_tot_pre_update = %s", string(Q_cfd_con_tot_prev)))
                        #println(iterations, @sprintf("g_cfd_total_prev = %s", string(g_cfd_total_prev)))
                        
                        # Zet snapshots in elk relevant agent-model
                        for m in agents[:Cons]
                        mdict[m].ext[:parameters][:Q_cfd_con_tot] = Q_cfd_con_tot_prev  # zelfde snapshot voor iedereen
                        mdict[m].ext[:parameters][:g_cfd_total] = g_cfd_total_prev
                        end
            end
            
            # Multi-threaded version
            @sync for m in agents[:all]
                # created subroutine to allow multi-threading to solve agents' decision problems
                @spawn ADMM_subroutine!(m,results,ADMM,EOM,mdict[m],agents,TO,market_design)
            end

            # 1 decision made once every iteration.
          if market_design == "cfd"
            for m in agents[:all]
            push!(results["Q_cfd"][m], value(mdict[m].ext[:variables][:Q_cfd]))
            #=
            println("Agent $m:")
            println("  Q_cfd value: ", value(mdict[m].ext[:variables][:Q_cfd]))
            println("  ζ_cfd value: ", mdict[m].ext[:parameters][:ζ_cfd])
            
            println("  ρ_cfd value: ", ADMM["ρ"]["cfd"][end])
            println("  Q_cfd_bar value: ", mdict[m].ext[:parameters][:Q_cfd_bar])
            =#
            end

            for m in agents[:Gen]
            push!(results["cfd_premium_gen"][m], value(mdict[m].ext[:expressions][:cfd_premium_gen]))
            push!(results["cfd_penalty_gen"][m], value(mdict[m].ext[:expressions][:cfd_penalty_gen]))
            end
            
            for m in agents[:Cons]
            push!(results["cfd_premium"][m], value(mdict[m].ext[:expressions][:cfd_premium]))
            push!(results["cfd_penalty_con"][m], value(mdict[m].ext[:expressions][:cfd_penalty_con]))
            push!(results["share_cfd_con"][m], value(mdict[m].ext[:expressions][:share_cfd_con]))
            end
                    # Som over alle consumenten (scalar)
                    Q_cfd_con_tot_new = sum(results["Q_cfd"][mc][end] for mc in agents[:Cons])
                    push!(results["Q_cfd_con_tot"], Q_cfd_con_tot_new)

                    # Som over alle generators → array (nT,nR,nY)
                    g_cfd_total_new = sum(results["g_cfd"][mg][end] for mg in agents[:Gen])
                    push!(results["g_cfd_total"], g_cfd_total_new)

                    Q_cfd_gen_tot = sum(results["Q_cfd"][g][end] for g in agents[:Gen])
                    push!(results["Q_cfd_gen_tot"], Q_cfd_gen_tot)
                    
                    #println(iterations, @sprintf("Q_tot_post_update = %s", string(Q_cfd_con_tot_new)))
                    #println(iterations, @sprintf("g_cfd_total_post = %s", string(g_cfd_total_new)))

                    #=for m in agents[:Cons]
                        share_val = value.(mdict[m].ext[:expressions][:share_cfd_con])
                                println(iterations,
                                    @sprintf("[iter=%d] Cons=%s share_cfd_con=%s",
                                            iter, String(m), string(share_val)))
                    end =#

                # Mapping: agent -> vector Q_cfd (laatste)
                    q_last = Dict{String, Float64}()
                    for m in agents[:all]
                        q_last[String(m)] = results["Q_cfd"][m][end]
                    end
                        row = DataFrame()
                        row[!, :iteration] = [iter]
                        for name in agent_order
                            val = q_last[name]
                            row[!, Symbol(name)] = [float(val)]
                        end
                        CSV.write(q_cfd_paths, row; append=true)     
                    end  
                    end

            # Imbalances
            @timeit TO "Compute imbalances" begin
                push!(ADMM["Imbalances"]["EOM"], sum(results["g"][m][end] for m in agents[:eom]) - (EOM["D"])) # subtract total fixed demand of all consumers and total elastic demand of all consumers!
                
                if market_design == "cfd"
                    push!(ADMM["Imbalances"]["cfd"], sum(results["Q_cfd"][m][end] for m in agents[:eom]))
                    #sum(results["Q_cfd_gen"][m][end] for m in agents[:Gen]) - sum(results["Q_cfd_con"][m][end] for m in agents[:Cons]))

                    # Add after imbalance calculations
                    #println("CfD Imbalance: ", ADMM["Imbalances"]["cfd"][end])
                    #println("Gen positions: ", sum(results["Q_cfd"][m][end] for m in agents[:Gen]))
                    #println("Con positions: ", sum(results["Q_cfd"][m][end] for m in agents[:Cons]))
                end
            end
            
            # Add debug prints for initialization
            #println(" CfD variables:")
            for m in agents[:all]
                println("Agent $m Q_cfd: ", value(mdict[m].ext[:variables][:Q_cfd]))
                println("Agent $m ζ_cfd: ", mdict[m].ext[:parameters][:ζ_cfd])
                println("Agent $m Q_cfd_bar: ", mdict[m].ext[:parameters][:Q_cfd_bar])
            end
            
            # Primal residuals
            @timeit TO "Compute primal residuals" begin
                push!(ADMM["Residuals"]["Primal"]["EOM"], sqrt(sum(ADMM["Imbalances"]["EOM"][end].^2)))
                
                if market_design == "cfd"
                    push!(ADMM["Residuals"]["Primal"]["cfd"], sqrt(sum(ADMM["Imbalances"]["cfd"][end]^2)))
                end
            end

            # Dual residuals
            @timeit TO "Compute dual residuals" begin 
            if iter > 1
                push!(ADMM["Residuals"]["Dual"]["EOM"], sqrt(sum(sum((ADMM["ρ"]["EOM"][end]*((results["g"][m][end]-sum(results["g"][mstar][end] for mstar in agents[:eom])./(EOM["nAgents"]+1)) - (results["g"][m][end-1]-sum(results["g"][mstar][end-1] for mstar in agents[:eom])./(EOM["nAgents"]+1)))).^2 for m in agents[:eom]))))
                
             if market_design == "cfd"
                push!(ADMM["Residuals"]["Dual"]["cfd"], sqrt(sum(sum((ADMM["ρ"]["cfd"][end]*((results["Q_cfd"][m][end]-sum(results["Q_cfd"][mstar][end] for mstar in agents[:eom])/(EOM["nAgents"]+1)) - (results["Q_cfd"][m][end-1]-sum(results["Q_cfd"][mstar][end-1] for mstar in agents[:eom])/(EOM["nAgents"]+1))))^2 for m in agents[:eom]))))
             end
            end

            # Price updates 
            @timeit TO "Update prices" begin
                push!(results[ "λ"]["EOM"], results[ "λ"]["EOM"][end] - ADMM["ρ"]["EOM"][end]/100*ADMM["Imbalances"]["EOM"][end])
                
                if market_design == "cfd"
                    push!(results[ "ζ"]["cfd"], results[ "ζ"]["cfd"][end] - ADMM["ρ"]["cfd"][end]/100*ADMM["Imbalances"]["cfd"][end])
                end
            end

            # Update ρ-values
            @timeit TO "Update ρ" begin
                 update_rho!(ADMM,iter,market_design)
            end

            # Progress bar
            @timeit TO "Progress bar" begin
                if market_design == "EOM"
                    set_description(iterations, string(@sprintf("Primal residual - EOM: %.3f -- Dual residual - EOM: %.3f",ADMM["Residuals"]["Primal"]["EOM"][end],ADMM["Residuals"]["Dual"]["EOM"][end])))
                
                else market_design == "cfd"
                    set_description(iterations,
                        @sprintf(
                            "EOM Primal: %.3f | EOM Dual: %.3f || CfD Primal: %.3f | CfD Dual: %.3f",
                            ADMM["Residuals"]["Primal"]["EOM"][end],
                            ADMM["Residuals"]["Dual"]["EOM"][end],
                            ADMM["Residuals"]["Primal"]["cfd"][end],
                            ADMM["Residuals"]["Dual"]["cfd"][end]
                        )
                    )
                end
            end

            # ADMM convergence results
            pr_eom = ADMM["Residuals"]["Primal"]["EOM"][end]
            du_eom = isempty(ADMM["Residuals"]["Dual"]["EOM"]) ? missing : ADMM["Residuals"]["Dual"]["EOM"][end]
            
            row = DataFrame(scen_number = scen_number = [scenario_overview_row["scen_number"]], iteration =[ADMM["n_iter"]], primal_residual = [pr_eom], dual_residual = Union{Missing,Float64}[du_eom])

            if market_design == "cfd"
                    pr_cfd = ADMM["Residuals"]["Primal"]["cfd"][end]
                    du_cfd = isempty(ADMM["Residuals"]["Dual"]["cfd"]) ? missing : ADMM["Residuals"]["Dual"]["cfd"][end]
                    row[!, :cfd_primal] = [pr_cfd]                              # kolom toevoegen
                    row[!, :cfd_dual]   = Union{Missing,Float64}[du_cfd]
                end
            CSV.write(logpath, row; append=isfile(logpath), delim=";")
            



            # Check convergence: primal and dual satisfy tolerance 
            if market_design == "EOM"
                if ADMM["Residuals"]["Primal"]["EOM"][end] <= ADMM["Tolerance"]["EOM"] && ADMM["Residuals"]["Dual"]["EOM"][end] <= ADMM["Tolerance"]["EOM"] 
                    convergence = 1 # stopping criterion is met
                end
            else market_design == "cfd"
                if ADMM["Residuals"]["Primal"]["EOM"][end] <= ADMM["Tolerance"]["EOM"] &&
                   ADMM["Residuals"]["Dual"]["EOM"][end] <= ADMM["Tolerance"]["EOM"] &&
                   ADMM["Residuals"]["Primal"]["cfd"][end] <= ADMM["Tolerance"]["cfd"] &&
                   ADMM["Residuals"]["Dual"]["cfd"][end] <= ADMM["Tolerance"]["cfd"]
                    convergence = 1
                end
            end
            # store number of iterations
            ADMM["n_iter"] = copy(iter)

        end
    end
end