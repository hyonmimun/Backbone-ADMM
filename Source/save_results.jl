# Save results
function save_results(mdict::Dict,EOM::Dict,ADMM::Dict,results::Dict,data::Dict,agents::Dict,scenario_overview_row::DataFrameRow,sens, market_design::AbstractString)
    # note that type of "sens" is not defined as a string stored in a dictionary is of type String31, whereas a "regular" string is of type String. Specifying one or the other may throw errors.
    vector_output = [scenario_overview_row["scen_number"]; sens; ADMM["n_iter"]; ADMM["walltime"];ADMM["Residuals"]["Primal"]["EOM"][end];ADMM["Residuals"]["Dual"]["EOM"][end]]
    CSV.write(joinpath(home_dir,string("overview_results.csv")), DataFrame(reshape(vector_output,1,:),:auto), delim=";",append=true);

    # EOM
    g_out = zeros(data["General"]["nTimesteps"],EOM["nAgents"])
    mm = 1
    for m in agents[:eom]
        g_out[:,mm] = results["g"][m][end]
        mm = mm+1
    end
    mat_output = [range(1,stop=data["General"]["nTimesteps"]) results[ "λ"]["EOM"][end] g_out -EOM["D"]]
    
    CSV.write(joinpath(home_dir,"Results",string("Scenario_",scenario_overview_row["scen_number"],"_EOM_",sens,".csv")), 
    DataFrame(mat_output,:auto), delim=";",header=["Timestep";"Price";string.("G_",agents[:eom]);"Demand"]);

    #= CfD
    if market_design == "CfD"
        gen_ids = agents[:Gen]
        cons_ids = agents[:Cons]
        n_iter = ADMM["n_iter"]
        cfd_output = DataFrame(Iteration=Int[], AgentType = String[], Agent=String[], Capacity = Union{Missing, Float64}[], Q_cfd_agent=Float64[], cfd_payout_agent_total=Float64[], cfd_premium_agent=Float64[], cfd_penalty_agent=Float64[],ζ_cfd=Float64[], Q_cfd_bar=Float64[])

        iter = n_iter
            for m in gen_ids
                Capacity = data["Generators"][m]["C"]
                Q_cfd_gen = results["Q_cfd_gen"][m][end]
                payout_vec = results["cfd_payout_gen"][m][end]
                payout_total = sum(payout_vec)
                premium = results["cfd_premium_gen"][m][end]
                penalty = results["cfd_penalty_gen"][m][end]
                ζ_cfd = results["ζ"]["CfD"][end]
                Q_cfd_bar = results["Q_cfd_bar"][m][end]

                push!(cfd_output, (
                    Iteration = iter,
                    AgentType = "Gen",
                    Agent = m,
                    Capacity = Capacity,
                    Q_cfd_agent = Q_cfd_gen,
                    cfd_payout_agent_total = payout_total,
                    cfd_premium_agent = premium,
                    cfd_penalty_agent = penalty,
                    ζ_cfd = ζ_cfd,
                    Q_cfd_bar = Q_cfd_bar
                ))
            end 

            for m in cons_ids
                ζ_cfd = results["ζ"]["CfD"][end]
                Q_cfd_bar = results["Q_cfd_bar"][m][end]
                Q_cfd_con = results["Q_cfd_con"][m][end]

                payout_vec = results["cfd_payout"][m][end]
                payout_total = sum(payout_vec)
                premium = results["cfd_premium"][m][end]
                penalty = results["cfd_penalty_con"][m][end]

                push!(cfd_output, (
                    Iteration = iter,
                    AgentType = "Cons",
                    Agent = m,
                    Capacity = missing,
                    Q_cfd_agent = Q_cfd_con,  
                    cfd_payout_agent_total = payout_total,
                    cfd_premium_agent = premium,
                    cfd_penalty_agent = penalty,
                    ζ_cfd = ζ_cfd,
                    Q_cfd_bar = Q_cfd_bar
                ))
            end
        
        output_file = joinpath(home_dir, "Results", "Scenario_$(scenario_overview_row["scen_number"])_CfD_Iterations_$(sens).csv")        
        CSV.write(output_file, cfd_output, delim = ";")

    # Save g_cfd per generator, per iteratie, per timestep
        g_cfd_output = DataFrame(
            Iteration = Int[],
            Timestep = Int[],
            Generator = String[],
            g_cfd = Float64[],
            cfd_payout_gen = Float64[]
        )

        iter = n_iter
            for m in gen_ids
                g_cfd_vec = results["g_cfd"][m][end]
                payout_vec = results["cfd_payout_gen"][m][end]

                for t in 1:length(g_cfd_vec)
                    
                    push!(g_cfd_output, (
                        Iteration = iter,
                        Timestep = t,
                        Generator = m,
                        g_cfd = g_cfd_vec[t],
                        cfd_payout_gen = payout_vec[t]
                    ))
                end
            end

        g_cfd_file = joinpath(home_dir, "Results", "Scenario_$(scenario_overview_row["scen_number"])_g_cfd_and_payout_per_iteration_$(sens).csv")
        CSV.write(g_cfd_file, g_cfd_output, delim = ";") 
    end =#
end
