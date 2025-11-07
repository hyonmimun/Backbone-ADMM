function update_rho!(ADMM::Dict, iter::Int64, market_design::AbstractString)
    if mod(iter,1) == 0
        # ρ-updates following Boyd et al. (2011)
        if ADMM["Residuals"]["Primal"]["EOM"][end] > 2*ADMM["Residuals"]["Dual"]["EOM"][end]
            push!(ADMM["ρ"]["EOM"], minimum([1000,1.1 * ADMM["ρ"]["EOM"][end]])) # minimum function caps the rho value at 1000 10^3€/GW
        elseif ADMM["Residuals"]["Dual"]["EOM"][end] > 2*ADMM["Residuals"]["Primal"]["EOM"][end]
            push!(ADMM["ρ"]["EOM"], 1/1.1*ADMM["ρ"]["EOM"][end])
        else
            push!(ADMM["ρ"]["EOM"], ADMM["ρ"]["EOM"][end])  # no change
        end

        if market_design == "cfd"
            if ADMM["Residuals"]["Primal"]["cfd"][end] > 2 * ADMM["Residuals"]["Dual"]["cfd"][end]
                push!(ADMM["ρ"]["cfd"], minimum([1000, 1.1 * ADMM["ρ"]["cfd"][end]]))
            elseif ADMM["Residuals"]["Dual"]["cfd"][end] > 2 * ADMM["Residuals"]["Primal"]["cfd"][end]
                push!(ADMM["ρ"]["cfd"], 1/1.1 * ADMM["ρ"]["cfd"][end])
            else
                push!(ADMM["ρ"]["cfd"], ADMM["ρ"]["cfd"][end])  # no change
            end
        end
    end
end 