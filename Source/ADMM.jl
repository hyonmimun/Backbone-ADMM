# ADMM 
function ADMM!(results::Dict,ADMM::Dict,EOM::Dict,mdict::Dict,agents::Dict,scenario_overview_row::DataFrameRow,data::Dict,TO::TimerOutput,market_design::AbstractString)
    convergence = 0
    iterations = ProgressBar(1:data["ADMM"]["max_iter"])
        # Extract sets
    nY = data["General"]["nYears"]
    nR = data["General"]["nReprDays"]
    nT = data["General"]["nTimesteps"]
    
    for iter in iterations
        if convergence == 0 # convergence not reached yet; loop continues solving
            if market_design == "cfd"
                        # fix Q_cfd_con_tot on the previous iteration value whilst solving
                        Q_cfd_con_tot_prev = isempty(results["Q_cfd_con_tot"]) ? fill(1e-8, nY) : copy(last(results["Q_cfd_con_tot"]))
                        # Totale cfd-productie (3D: tijd × repr. dag × jaar)
                        g_cfd_total_prev = isempty(results["g_cfd_total"]) ? zeros(nT, nR, nY) : copy(last(results["g_cfd_total"]))

                        # Zet snapshots in elk relevant agent-model
                        for m in agents[:Cons]
                        mdict[m].ext[:parameters][:Q_cfd_con_tot] = Q_cfd_con_tot_prev  # zelfde snapshot voor iedereen
                        mdict[m].ext[:parameters][:g_cfd_total]   = g_cfd_total_prev
                        end
            end
            # Multi-threaded version
            @sync for m in agents[:all]
                # created subroutine to allow multi-threading to solve agents' decision problems
                @spawn ADMM_subroutine!(m,results,ADMM,EOM,mdict[m],agents,TO,market_design)
            end
            if market_design == "cfd"
                    # Som over alle consumenten → vector (nY)
                    Q_cfd_con_tot_new = sum((last(results["Q_cfd_con"][mc]) for mc in agents[:Cons]);
                                            init = zeros(nY))
                    push!(results["Q_cfd_con_tot"], Q_cfd_con_tot_new)

                    # Som over alle generators → array (nT,nR,nY)
                    g_cfd_total_new = sum((last(results["g_cfd"][mg]) for mg in agents[:Gen]);
                                        init = zeros(nT, nR, nY))
                    push!(results["g_cfd_total"], g_cfd_total_new)
            end

            end
            # Imbalances
            @timeit TO "Compute imbalances" begin
                push!(ADMM["Imbalances"]["EOM"], sum(results["g"][m][end] for m in agents[:eom]) - (EOM["D"])) # subtract total fixed demand of all consumers and total elastic demand of all consumers!
                
                if market_design == "cfd"
                    push!(ADMM["Imbalances"]["cfd"], 
                    sum(results["Q_cfd_gen"][m][end] for m in agents[:Gen]) - sum(results["Q_cfd_con"][m][end] for m in agents[:Cons])) # cfd imbalance in contract volume between aggregated generator and consumer for each year
                end
            end

            # Primal residuals
            @timeit TO "Compute primal residuals" begin
                push!(ADMM["Residuals"]["Primal"]["EOM"], sqrt(sum(ADMM["Imbalances"]["EOM"][end].^2)))
                
                if market_design == "cfd"
                    push!(ADMM["Residuals"]["Primal"]["cfd"], sqrt(sum(ADMM["Imbalances"]["cfd"][end].^2))) # cfd primal residuals
                end
            end

            # Dual residuals
            @timeit TO "Compute dual residuals" begin 
            if iter > 1
                push!(ADMM["Residuals"]["Dual"]["EOM"], sqrt(sum(sum((ADMM["ρ"]["EOM"][end]*((results["g"][m][end]-sum(results["g"][mstar][end] for mstar in agents[:eom])./(EOM["nAgents"]+1)) - (results["g"][m][end-1]-sum(results["g"][mstar][end-1] for mstar in agents[:eom])./(EOM["nAgents"]+1)))).^2 for m in agents[:eom]))))
                
                #=if market_design == "cfd"
                    push!(ADMM["Residuals"]["Dual"]["cfd"], sqrt(
                    sum((ADMM["ρ"]["cfd"][end] * (results["Q_cfd_gen"][m][end] .- results["Q_cfd_gen"][m][end-1])).^2 for m in agents[:Gen]) +
                    sum((ADMM["ρ"]["cfd"][end] * (results["Q_cfd_con"][m][end] .- results["Q_cfd_con"][m][end-1])).^2 for m in agents[:Cons])
                ))  # per agent L2 =#

                if market_design == "cfd"
                    ρ = ADMM["ρ"]["cfd"][end]
                    diff_or_zero(buf) = length(buf) >= 2 ? (buf[end] .- buf[end-1]) : zeros(nY)

                    r2 = sum( sum(abs2, diff_or_zero(results["Q_cfd_gen"][m])) for m in agents[:Gen]) +
                        sum( sum(abs2, diff_or_zero(results["Q_cfd_con"][m])) for m in agents[:Cons])
                    push!(ADMM["Residuals"]["Dual"]["cfd"], ρ * sqrt(r2))
                end
                #=
                    sqrt(sum(ADMM["ρ"]["cfd"][end]*((sum(results["Q_cfd_gen"][m][end] for m in agents[:Gen]) - 
                    sum(results["Q_cfd_con"][m][end] for m in agents[:Cons])) - (sum(results["Q_cfd_gen"][m][end-1] for m in agents[:Gen]) - 
                    sum(results["Q_cfd_con"][m][end-1] for m in agents[:Cons])))).^2)) # aggregate dual residuals 
                    end =#           
            
            end

            # Price updates 
            @timeit TO "Update prices" begin
                push!(results[ "λ"]["EOM"], results[ "λ"]["EOM"][end] - ADMM["ρ"]["EOM"][end]/100*ADMM["Imbalances"]["EOM"][end])
                
                if market_design == "cfd"
                    push!(results[ "ζ"]["cfd"], results[ "ζ"]["cfd"][end] - ADMM["ρ"]["cfd"][end]/100*ADMM["Imbalances"]["cfd"][end])
                    #println(string("ζ_cfd: ", results[ "ζ"]["cfd"][end]))
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
                
                elseif market_design == "cfd"
                    set_description(iterations, @sprintf("cfd Primal: %.3f | Dual: %.3f",
                     ADMM["Residuals"]["Primal"]["cfd"][end],
                     ADMM["Residuals"]["Dual"]["cfd"][end]))
                end
            end

            # ADMM convergence results
            results_dir = joinpath(home_dir,string("Results_", data["General"]["nReprDays"], "_repr_days"))
            out_dir = joinpath(results_dir, String(market_design))
            logpath = joinpath(out_dir, string(scen_ts, "_", market_design, "_ADMM_residuals_all.csv"))

            row = DataFrame(scen_number     = [scenario_overview_row["scen_number"]], iteration = [ADMM["n_iter"]],primal_residual = [ADMM["Residuals"]["Primal"]["EOM"][end]], dual_residual   = [ADMM["Residuals"]["Dual"]["EOM"][end]])
                
            if market_design == "cfd"
                    push!(row, DataFrame(cfd_primal = [ADMM["Residuals"]["Primal"]["cfd"][end]], cfd_dual = [ADMM["Residuals"]["Dual"]["cfd"][end]]; cols = :union))
                end
            # schrijf/append: bij eerste keer wordt header geschreven, daarna alleen rijen
            CSV.write(logpath, row; append=isfile(logpath))
            
            # Check convergence: primal and dual satisfy tolerance 
            if market_design == "EOM"
                if ADMM["Residuals"]["Primal"]["EOM"][end] <= ADMM["Tolerance"]["EOM"] && ADMM["Residuals"]["Dual"]["EOM"][end] <= ADMM["Tolerance"]["EOM"] 
                    convergence = 1 # stopping criterion is met
                end
            
            elseif market_design == "cfd"
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