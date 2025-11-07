function define_results!(data::Dict,results::Dict,ADMM::Dict,agents::Dict,market_design::AbstractString) 
    # Sets
    nT = data["General"]["nTimesteps"]
    nR = data["General"]["nReprDays"]
    nY = data["General"]["nYears"]
    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh
    
    results["g"] = Dict()
    for m in agents[:eom]
        #=if m == "GasTurbine"
            results["g"][m] = Dict(jg => CircularBuffer{Array{Float64,3}}(ADMM["CircularBufferSize"]) for jg in 1:data["General"]["nGasPrice"])
        else =#
            
        results["g"][m] = CircularBuffer{Array{Float64,3}}(data["ADMM"]["CircularBufferSize"]) 
        push!(results["g"][m],zeros(nT,nR,nY))
    end

    results["D_ELA"] = Dict()
    results["SOC"] = Dict()
    results["charge"] = Dict()
    results["discharge"] = Dict()

    for m in agents[:Cons]
        results["D_ELA"][m] = CircularBuffer{Array{Float64,3}}(data["ADMM"]["CircularBufferSize"]) 
        push!(results["D_ELA"][m],zeros(nT,nR,nY))

        if haskey(data["Consumers"][m], "Battery")
            results["SOC"][m] = CircularBuffer{Array{Float64,3}}(data["ADMM"]["CircularBufferSize"]) 
            push!(results["SOC"][m],zeros(nT,nR,nY))

            results["charge"][m] = CircularBuffer{Array{Float64,3}}(data["ADMM"]["CircularBufferSize"]) 
            push!(results["charge"][m],zeros(nT,nR,nY))

            results["discharge"][m] = CircularBuffer{Array{Float64,3}}(data["ADMM"]["CircularBufferSize"]) 
            push!(results["discharge"][m],zeros(nT,nR,nY))
        end
    end

    results["λ"] = Dict()
    results[ "λ"]["EOM"] = CircularBuffer{Array{Float64,3}}(data["ADMM"]["CircularBufferSize"]) 
    push!(results[ "λ"]["EOM"],zeros(nT,nR,nY))
   
    ADMM["Imbalances"] = Dict()
    ADMM["Imbalances"]["EOM"] = CircularBuffer{Array{Float64,3}}(data["ADMM"]["CircularBufferSize"])
    push!(ADMM["Imbalances"]["EOM"],zeros(nT,nR,nY))
    
    ADMM["Residuals"] = Dict()
    ADMM["Residuals"]["Primal"] = Dict()
    ADMM["Residuals"]["Primal"]["EOM"] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
    push!(ADMM["Residuals"]["Primal"]["EOM"],0)

    ADMM["Residuals"]["Dual"] = Dict()
    ADMM["Residuals"]["Dual"]["EOM"] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
    push!(ADMM["Residuals"]["Dual"]["EOM"],0)
    
    ADMM["Tolerance"] = Dict()
    ADMM["Tolerance"]["EOM"] = data["ADMM"]["epsilon"]

    ADMM["ρ"] = Dict()
    ADMM["ρ"]["EOM"] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"]) 
    push!(ADMM["ρ"]["EOM"],data["ADMM"]["rho_EOM"])

    ADMM["n_iter"] = 1 
    ADMM["walltime"] = 0

    # cfd enabled
    if market_design == "cfd"
        results["Q_cfd"] = Dict()
        results["Q_cfd_bar"] = Dict()
        
        for m in agents[:eom]
            results["Q_cfd"][m] =  CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
            push!(results["Q_cfd"][m],0)

            results["Q_cfd_bar"][m] =  CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
            push!(results["Q_cfd_bar"][m],0)
        end
        
        results["g_cfd"] = Dict()
        results["cfd_payout_gen"] = Dict()
        results["cfd_premium_gen"] = Dict()
        results["cfd_penalty_gen"] = Dict()
        
        for m in agents[:Gen]
            results["g_cfd"][m] = CircularBuffer{Array{Float64,3}}(data["ADMM"]["CircularBufferSize"])
            push!(results["g_cfd"][m], zeros(nT,nR,nY))

            results["cfd_payout_gen"][m] = CircularBuffer{Vector{Float64}}(data["ADMM"]["CircularBufferSize"])
            push!(results["cfd_payout_gen"][m],zeros(nY))

            results["cfd_premium_gen"][m] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
            push!(results["cfd_premium_gen"][m],0)

            results["cfd_penalty_gen"][m] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
            push!(results["cfd_penalty_gen"][m],0)
        end
        
        results["cfd_payout"] = Dict()
        results["cfd_premium"] = Dict()
        results["cfd_penalty_con"] = Dict()
        results["share_cfd_con"] = Dict()

        for m in agents[:Cons]
            results["cfd_payout"][m] = CircularBuffer{Vector{Float64}}(data["ADMM"]["CircularBufferSize"])
            push!(results["cfd_payout"][m],zeros(nY))

            results["cfd_premium"][m] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
            push!(results["cfd_premium"][m], 0)

            results["cfd_penalty_con"][m] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
            push!(results["cfd_penalty_con"][m], 0)

            results["share_cfd_con"][m] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
            push!(results["share_cfd_con"][m], 0)
        end

        # cfd totals
        # sum(g_cfd) over all generators per timestep
        results["g_cfd_total"] = CircularBuffer{Array{Float64,3}}(data["ADMM"]["CircularBufferSize"])
        push!(results["g_cfd_total"], zeros(nT,nR,nY))
        
        results["Q_cfd_con_tot"] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
        push!(results["Q_cfd_con_tot"],0)

        results["Q_cfd_gen_tot"] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
        push!(results["Q_cfd_gen_tot"],0)

        results["ζ"] = Dict()
        results["ζ"]["cfd"] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
        push!(results["ζ"]["cfd"],0)

        # ADMM
        ADMM["Imbalances"]["cfd"] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
        push!(ADMM["Imbalances"]["cfd"],0)

        ADMM["Residuals"]["Primal"]["cfd"] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
        push!(ADMM["Residuals"]["Primal"]["cfd"], 0)

        ADMM["Residuals"]["Dual"]["cfd"] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
        push!(ADMM["Residuals"]["Dual"]["cfd"], 0)

        ADMM["Tolerance"]["cfd"] = data["cfd"]["epsilon_cfd"]

        ADMM["ρ"]["cfd"] = CircularBuffer{Float64}(data["ADMM"]["CircularBufferSize"])
        push!(ADMM["ρ"]["cfd"], data["cfd"]["rho_cfd"])
    end
    # Full history for plotting (separate from CircularBuffers)
# Only stores scalar values - minimal memory overhead
ADMM["History"] = Dict{String, Vector{Float64}}()
ADMM["History"]["Primal_EOM"] = Float64[]
ADMM["History"]["Dual_EOM"] = Float64[]
ADMM["History"]["rho_EOM"] = Float64[]

if market_design == "cfd"
    ADMM["History"]["Primal_cfd"] = Float64[]
    ADMM["History"]["Dual_cfd"] = Float64[]
    ADMM["History"]["rho_cfd"] = Float64[]
    ADMM["History"]["zeta_cfd"] = Float64[]
    ADMM["History"]["imbalance_cfd"] = Float64[]
end

# Separate history for decision variables (not ADMM metrics)
results["History"] = Dict{String, Any}()

if market_design == "cfd"
    results["History"]["Q_cfd"] = Dict{String, Vector{Float64}}()
    for m in agents[:all]
        results["History"]["Q_cfd"][m] = Float64[]
    end
end
    return results, ADMM
end