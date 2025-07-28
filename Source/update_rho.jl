function update_rho!(ADMM::Dict, iter::Int64, market_design::AbstractString)
    if mod(iter,1) == 0
        # ρ-updates following Boyd et al. (2011)
        if ADMM["Residuals"]["Primal"]["EOM"][end] > 2*ADMM["Residuals"]["Dual"]["EOM"][end]
            push!(ADMM["ρ"]["EOM"], minimum([1000,1.1*ADMM["ρ"]["EOM"][end]])) #minimum function caps the rho value at 1000
        elseif ADMM["Residuals"]["Dual"]["EOM"][end] > 2*ADMM["Residuals"]["Primal"]["EOM"][end]
            push!(ADMM["ρ"]["EOM"], 1/1.1*ADMM["ρ"]["EOM"][end])
        else
            push!(ADMM["ρ"]["EOM"], ADMM["ρ"]["EOM"][end])  # no change
        end

        if market_design == "CfD"
            if ADMM["Residuals"]["Primal"]["CfD"][end] > 2 * ADMM["Residuals"]["Dual"]["CfD"][end]
                push!(ADMM["ρ"]["CfD"], minimum(1000.0, 1.1 * ADMM["ρ"]["CfD"][end]))
            elseif ADMM["Residuals"]["Dual"]["CfD"][end] > 2 * ADMM["Residuals"]["Primal"]["CfD"][end]
                push!(ADMM["ρ"]["CfD"], 1/1.1 * ADMM["ρ"]["CfD"][end])
            else
                push!(ADMM["ρ"]["CfD"], ADMM["ρ"]["CfD"][end])  # no change
            end
        else
            # Ensure that buffer contains same number of entries across all iterations even when rho is not updated = maintain buffer length (last entry gets repeated)
            if haskey(ADMM["ρ"], "CfD") # if CfD is enabled
                push!(ADMM["ρ"]["CfD"], ADMM["ρ"]["CfD"][end]) # Avoid IndexError or KeyError
            end
            end
        end
    end