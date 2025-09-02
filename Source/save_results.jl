# Save results
function save_results(mdict::Dict,EOM::Dict,ADMM::Dict,results::Dict,data::Dict,agents::Dict,scenario_overview_row::DataFrameRow,sens, market_design::AbstractString)
    # note that type of "sens" is not defined as a string stored in a dictionary is of type String31, whereas a "regular" string is of type String. Specifying one or the other may throw errors.
    vector_output = [scenario_overview_row["scen_number"]; sens; ADMM["n_iter"]; ADMM["walltime"];ADMM["Residuals"]["Primal"]["EOM"][end];ADMM["Residuals"]["Dual"]["EOM"][end]]
    CSV.write(joinpath(home_dir,string("overview_results.csv")), DataFrame(reshape(vector_output,1,:),:auto), delim=";",append=true);

   nY = data["General"]["nYears"]
   nR = data["General"]["nReprDays"]
   nT = data["General"]["nTimesteps"]

   idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year


    for jy in 1:nY
        CSV.write(joinpath(home_dir,string("Results_",data["General"]["nReprDays"],"_repr_days"),string("demand_",jy,".csv")), DataFrame(EOM["D"][:,:,jy],:auto), delim=";");
    
    # EOM
    g_out = zeros(nT*nR, EOM["nAgents"])
    mm = 1
        for m in agents[:eom]
            #g_out[:,mm] = results["g"][m][end]
            g_out[:, mm] = vec(results["g"][m][end][:,:,jy]) # reshape to 2D vector
            mm = mm+1
        end

        # flatten to create nT*nR
        mat_output = hcat(
        collect(1:nT*nR),
        vec(results["λ"]["EOM"][end][:,:,jy]),
        g_out,
        -vec(EOM["D"][:,:,jy])
 )

        CSV.write(joinpath(home_dir,"Results",string("Scenario_",scenario_overview_row["scen_number"],"_EOM_",sens,"_year", jy,".csv")), 
        DataFrame(mat_output,:auto), delim=";",header=["Timestep";"Price";string.("G_",agents[:eom]);"Demand"]);

    
end
end