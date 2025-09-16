function define_results!(data::Dict,results::Dict,ADMM::Dict,agents::Dict,market_design::AbstractString) 
    # Sets
    nT = data["nTimesteps"]
    nR = data["nReprDays"]
    nY = data["nYears"]
    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh
    
    results["g"] = Dict()
    for m in agents[:eom]
        results["g"][m] = CircularBuffer{Array{Float64,3}}(data["CircularBufferSize"]) 
        push!(results["g"][m],zeros(nT,nR,nY))
    end

    results["D_ELA"] = Dict()
    results["SOC"] = Dict()
    results["charge"] = Dict()
    results["discharge"] = Dict()
    for m in agents[:Cons]
        results["D_ELA"][m] = CircularBuffer{Array{Float64,3}}(data["CircularBufferSize"]) 
        push!(results["D_ELA"][m],zeros(nT,nR,nY))

        results["SOC"][m] = CircularBuffer{Array{Float64,3}}(data["CircularBufferSize"]) 
        push!(results["SOC"][m],zeros(nT,nR,nY))

        results["charge"][m] = CircularBuffer{Array{Float64,3}}(data["CircularBufferSize"]) 
        push!(results["charge"][m],zeros(nT,nR,nY))

        results["discharge"][m] = CircularBuffer{Array{Float64,3}}(data["CircularBufferSize"]) 
        push!(results["discharge"][m],zeros(nT,nR,nY))
    end

    results["λ"] = Dict()
    results[ "λ"]["EOM"] = CircularBuffer{Array{Float64,3}}(data["CircularBufferSize"]) 
    push!(results[ "λ"]["EOM"],zeros(nT,nR,nY))
   
    ADMM["Imbalances"] = Dict()
    ADMM["Imbalances"]["EOM"] = CircularBuffer{Array{Float64,3}}(data["CircularBufferSize"])
    push!(ADMM["Imbalances"]["EOM"],zeros(nT,nR,nY))
    
    ADMM["Residuals"] = Dict()
    ADMM["Residuals"]["Primal"] = Dict()
    ADMM["Residuals"]["Primal"]["EOM"] = CircularBuffer{Float64}(data["CircularBufferSize"])
    push!(ADMM["Residuals"]["Primal"]["EOM"],0)

    ADMM["Residuals"]["Dual"] = Dict()
    ADMM["Residuals"]["Dual"]["EOM"] = CircularBuffer{Float64}(data["CircularBufferSize"])
    push!(ADMM["Residuals"]["Dual"]["EOM"],0)
    
    ADMM["Tolerance"] = Dict()
    ADMM["Tolerance"]["EOM"] = data["epsilon"] 

    ADMM["ρ"] = Dict()
    ADMM["ρ"]["EOM"] = CircularBuffer{Float64}(data["CircularBufferSize"]) 
    push!(ADMM["ρ"]["EOM"],data["rho_EOM"])

    ADMM["n_iter"] = 1 
    ADMM["walltime"] = 0

    # cfd enabled
    if market_design == "cfd"
        
        results["Q_cfd_bar"] = Dict()
        for m in agents[:eom]
            results["Q_cfd_bar"][m] =  CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
            push!(results["Q_cfd_bar"][m],zeros(nY))
        end
        
        results["g_cfd"] = Dict()
        results["Q_cfd_gen"] = Dict()
        results["cfd_payout_gen"] = Dict()
        results["cfd_premium_gen"] = Dict()
        results["cfd_penalty_gen"] = Dict()
        
        for m in agents[:Gen]
            results["g_cfd"][m] = CircularBuffer{Array{Float64,3}}(data["CircularBufferSize"])
            push!(results["g_cfd"][m], zeros(nT,nR,nY))

            results["cfd_payout_gen"][m] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
            push!(results["cfd_payout_gen"][m],zeros(nY))

            results["Q_cfd_gen"][m] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
            push!(results["Q_cfd_gen"][m],zeros(nY))

            results["cfd_premium_gen"][m] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
            push!(results["cfd_premium_gen"][m],zeros(nY))

            results["cfd_penalty_gen"][m] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
            push!(results["cfd_penalty_gen"][m],zeros(nY))
        end
        
        results["Q_cfd_con"] = Dict()
        results["cfd_payout"] = Dict()
        results["cfd_premium"] = Dict()
        results["cfd_penalty_con"] = Dict()

        for m in agents[:Cons]
            results["Q_cfd_con"][m] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
            push!(results["Q_cfd_con"][m],zeros(nY))
            
            results["cfd_payout"][m] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
            push!(results["cfd_payout"][m],zeros(nY))

            results["cfd_premium"][m] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
            push!(results["cfd_premium"][m], zeros(nY))

            results["cfd_penalty_con"][m] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
            push!(results["cfd_penalty_con"][m], zeros(nY))
        end

        # cfd totals
        results["g_cfd_total"] = CircularBuffer{Array{Float64,3}}(data["CircularBufferSize"])
        push!(results["g_cfd_total"], zeros(nT,nR,nY))
        
        results["Q_cfd_con_tot"] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
        push!(results["Q_cfd_con_tot"],zeros(nY))

        results["Q_cfd_gen_tot"] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
        push!(results["Q_cfd_gen_tot"],zeros(nY))

        results["ζ"] = Dict()
        results["ζ"]["cfd"] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
        push!(results["ζ"]["cfd"],zeros(nY))

        # ADMM
        ADMM["Imbalances"]["cfd"] = CircularBuffer{Vector{Float64}}(data["CircularBufferSize"])
        push!(ADMM["Imbalances"]["cfd"],zeros(nY))

        ADMM["Residuals"]["Primal"]["cfd"] = CircularBuffer{Float64}(data["CircularBufferSize"])
        push!(ADMM["Residuals"]["Primal"]["cfd"], 0.0)

        ADMM["Residuals"]["Dual"]["cfd"] = CircularBuffer{Float64}(data["CircularBufferSize"])
        push!(ADMM["Residuals"]["Dual"]["cfd"], 0.0)

        ADMM["Tolerance"]["cfd"] = data["epsilon_cfd"]  # Or define this separately if needed

        ADMM["ρ"]["cfd"] = CircularBuffer{Float64}(data["CircularBufferSize"])
        push!(ADMM["ρ"]["cfd"], data["rho_cfd"])

    end
    
    return results, ADMM
end