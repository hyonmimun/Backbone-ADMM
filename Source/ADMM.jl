# ADMM 
function ADMM!(results::Dict,ADMM::Dict,EOM::Dict,mdict::Dict,agents::Dict,scenario_overview_row::DataFrameRow,data::Dict,TO::TimerOutput,market_design::AbstractString)
    convergence = 0
    iterations = ProgressBar(1:data["ADMM"]["max_iter"])
    
    for iter in iterations
        if convergence == 0 # convergence not reached yet; loop continues solving
            
            # Multi-threaded version
            @sync for m in agents[:all]
                # created subroutine to allow multi-threading to solve agents' decision problems
                @spawn ADMM_subroutine!(m,results,ADMM,EOM,mdict[m],agents,TO,market_design)
            end
        end

            # Imbalances
            @timeit TO "Compute imbalances" begin
                push!(ADMM["Imbalances"]["EOM"], sum(results["g"][m][end] for m in agents[:eom]) - EOM["D"][:])
                
                if market_design == "CfD"
                    push!(ADMM["Imbalances"]["CfD"], 
                    sum(results["Q_cfd_gen"][m][end] for m in agents[:Gen]) 
                    - sum(results["Q_cfd_con"][m][end] for m in agents[:Cons])) # CfD imbalance in contract volume between aggregated generator and consumer

                end
            end


            # Primal residuals
            @timeit TO "Compute primal residuals" begin
                push!(ADMM["Residuals"]["Primal"]["EOM"], sqrt(sum(ADMM["Imbalances"]["EOM"][end].^2)))
                
                if market_design == "CfD"
                    push!(ADMM["Residuals"]["Primal"]["CfD"], sqrt(sum(ADMM["Imbalances"]["CfD"][end].^2))) # CfD primal residuals
                end
            end

            # Dual residuals
            @timeit TO "Compute dual residuals" begin 
            if iter > 1
                push!(ADMM["Residuals"]["Dual"]["EOM"], sqrt(sum(sum((ADMM["ρ"]["EOM"][end]*((results["g"][m][end]-sum(results["g"][mstar][end] for mstar in agents[:eom])./(EOM["nAgents"]+1)) - (results["g"][m][end-1]-sum(results["g"][mstar][end-1] for mstar in agents[:eom])./(EOM["nAgents"]+1)))).^2 for m in agents[:eom]))))
                
                if market_design == "CfD"    
                    push!(ADMM["Residuals"]["Dual"]["CfD"], sqrt(sum(ADMM["ρ"]["CfD"][end]*((sum(results["Q_cfd_gen"][m][end] for m in agents[:Gen]) - sum(results["Q_cfd_con"][m][end] for m in agents[:Cons])) - (sum(results["Q_cfd_gen"][m][end-1] for m in agents[:Gen]) - sum(results["Q_cfd_con"][m][end-1] for m in agents[:Cons])))).^2)) # CfD dual residuals            
                end

            end

            # Price updates 
            @timeit TO "Update prices" begin
                push!(results[ "λ"]["EOM"], results[ "λ"]["EOM"][end] - ADMM["ρ"]["EOM"][end]/100*ADMM["Imbalances"]["EOM"][end])
                
                if market_design == "CfD"
                    push!(results[ "ζ"]["CfD"], results[ "ζ"]["CfD"][end] - ADMM["ρ"]["CfD"][end]/100*ADMM["Imbalances"]["CfD"][end])
                    #println(string("ζ_cfd: ", results[ "ζ"]["CfD"][end]))
                end
            end

            # Update ρ-values
            @timeit TO "Update ρ" begin
                 update_rho!(ADMM,iter,market_design)
            end

            # Progress bar
            @timeit TO "Progress bar" begin
                if market_design == "default"
                    set_description(iterations, string(@sprintf("Primal residual - EOM: %.3f -- Dual residual - EOM: %.3f",ADMM["Residuals"]["Primal"]["EOM"][end],ADMM["Residuals"]["Dual"]["EOM"][end])))
                
                elseif market_design == "CfD"
                    set_description(iterations, @sprintf("CfD Primal: %.3f | Dual: %.3f",
                     ADMM["Residuals"]["Primal"]["CfD"][end],
                     ADMM["Residuals"]["Dual"]["CfD"][end]))
                end
            end

            # Check convergence: primal and dual satisfy tolerance 
            if market_design == "default"
                if ADMM["Residuals"]["Primal"]["EOM"][end] <= ADMM["Tolerance"]["EOM"] && ADMM["Residuals"]["Dual"]["EOM"][end] <= ADMM["Tolerance"]["EOM"] 
                    convergence = 1 # stopping criterion is met
                end
            
            elseif market_design == "CfD"
                if ADMM["Residuals"]["Primal"]["EOM"][end] <= ADMM["Tolerance"]["EOM"] &&
                   ADMM["Residuals"]["Dual"]["EOM"][end] <= ADMM["Tolerance"]["EOM"] &&
                   ADMM["Residuals"]["Primal"]["CfD"][end] <= ADMM["Tolerance"]["CfD"] &&
                   ADMM["Residuals"]["Dual"]["CfD"][end] <= ADMM["Tolerance"]["CfD"]
                    convergence = 1
                end
            end
            # store number of iterations
            ADMM["n_iter"] = copy(iter)

        end
    end
end