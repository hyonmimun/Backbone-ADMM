function define_results!(data::Dict,results::Dict,ADMM::Dict,agents::Dict,market_design::AbstractString) 
    results["g"] = Dict()
    for m in agents[:eom]
        results["g"][m] = CircularBuffer{Array{Float64,1}}(data["CircularBufferSize"]) 
        push!(results["g"][m],zeros(data["nTimesteps"]))
    end

    results["λ"] = Dict()
    results[ "λ"]["EOM"] = CircularBuffer{Array{Float64,1}}(data["CircularBufferSize"]) 
    push!(results[ "λ"]["EOM"],zeros(data["nTimesteps"]))
   
    ADMM["Imbalances"] = Dict()
    ADMM["Imbalances"]["EOM"] = CircularBuffer{Array{Float64,1}}(data["CircularBufferSize"])
    push!(ADMM["Imbalances"]["EOM"],zeros(data["nTimesteps"]))
  
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

# CfD enabled
    if market_design == "CfD"
        results["g_cfd"] = Dict()
        for m in agents[:Gen]
            results["g_cfd"][m] = CircularBuffer{Array{Float64,1}}(data["CircularBufferSize"])
            push!(results["g_cfd"][m], zeros(data["nTimesteps"]))
        end
        
        results["g_cfd_total"] = CircularBuffer{Array{Float64,1}}(data["CircularBufferSize"])
        push!(results["g_cfd_total"], zeros(data["nTimesteps"]))

        results["Q_cfd_gen"] = Dict()
        for m in agents[:Gen]
            results["Q_cfd_gen"][m] = CircularBuffer{Float64}(data["CircularBufferSize"])
            push!(results["Q_cfd_gen"][m], 0.0)
        end

        results["Q_cfd_con"] = Dict()
        for m in agents[:Cons]
            results["Q_cfd_con"][m] = CircularBuffer{Float64}(data["CircularBufferSize"])
            push!(results["Q_cfd_con"][m], 0.0)
        end

        results["Q_cfd_con_tot"] = CircularBuffer{Float64}(data["CircularBufferSize"])
        push!(results["Q_cfd_con_tot"], 0.0)

        results["ζ"] = Dict()
        results["ζ"]["CfD"] = CircularBuffer{Float64}(data["CircularBufferSize"])
        push!(results["ζ"]["CfD"], 0.0)

        ADMM["Imbalances"]["CfD"] = CircularBuffer{Float64}(data["CircularBufferSize"])
        push!(ADMM["Imbalances"]["CfD"], 0.0)

        ADMM["Residuals"]["Primal"]["CfD"] = CircularBuffer{Float64}(data["CircularBufferSize"])
        push!(ADMM["Residuals"]["Primal"]["CfD"], 0.0)

        ADMM["Residuals"]["Dual"]["CfD"] = CircularBuffer{Float64}(data["CircularBufferSize"])
        push!(ADMM["Residuals"]["Dual"]["CfD"], 0.0)

        ADMM["Tolerance"]["CfD"] = data["epsilon_cfd"]  # Or define this separately if needed

        ADMM["ρ"]["CfD"] = CircularBuffer{Float64}(data["CircularBufferSize"])
        push!(ADMM["ρ"]["CfD"], data["rho_cfd"])
    end
    
    return results, ADMM
end