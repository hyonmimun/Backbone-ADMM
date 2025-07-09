# Save results
function save_results(mdict::Dict,EOM::Dict,ADMM::Dict,results::Dict,data::Dict,agents::Dict,scenario_overview_row::DataFrameRow,sens) 
    # note that type of "sens" is not defined as a string stored in a dictionary is of type String31, whereas a "regular" string is of type String. Specifying one or the other may trow errors.
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
    CSV.write(joinpath(home_dir,"Results",string("Scenario_",scenario_overview_row["scen_number"],"_EOM_",sens,".csv")), DataFrame(mat_output,:auto), delim=";",header=["Timestep";"Price";string.("G_",agents[:eom]);"Demand"]);
    
        # --- Save CfD savings per consumer (if applicable) ---
  

    df_cfd = DataFrame(
        TypeConsumers = String[], 
        TotalCfDSaving = Float64[], 
        TotalCost = Float64[], 
        EffectiveCost = Float64[],
        ElasticDemand = Float64[],
        BatteryCharge = Float64[],
        BatteryDischarge = Float64[],
        SelfConsumptionRatio = Float64[],
        PV_DirectUse = Float64[],
        PV_BatteryUse = Float64[],
        PV_Exported = Float64[]
    )

    for m in agents[:Cons]
        mod = mdict[m]
        JH = mod.ext[:sets][:JH]
        PV = mod.ext[:timeseries][:PV]
        D_fixed = mod.ext[:parameters][:D_fixed]
        D_ELA = mod.ext[:variables][:D_ELA]
        g = mod.ext[:variables][:g]
        charge = mod.ext[:variables][:charge]

        pv_used_locally = sum(PV[jh] - max(value(g[jh]), 0) for jh in JH)
        total_pv = sum(PV[jh] for jh in JH)
        pv_exported = sum(max(value(g[jh]), 0) for jh in JH)
        battery_charge_from_pv = sum(value(charge[jh]) for jh in JH)
        direct_pv_use = total_pv - pv_exported - battery_charge_from_pv

        self_consumption_ratio = total_pv > 0 ? (direct_pv_use + battery_charge_from_pv) / total_pv : 0.0

        if haskey(mdict[m].ext[:expressions], :cfd_saving)
            mod = mdict[m]
            JH = mod.ext[:sets][:JH]

            # Extract necessary data
            cfd_saving = mod.ext[:expressions][:cfd_saving]
            g = mod.ext[:variables][:g]
            λ_EOM = mod.ext[:parameters][:λ_EOM]
            D_ELA = mod.ext[:variables][:D_ELA]
            charge = mod.ext[:variables][:charge]
            discharge = mod.ext[:variables][:discharge]

            total_saving_cfd_cons = sum(value(cfd_saving[jh]) for jh in JH)
            total_cost = sum(λ_EOM[jh] * value(g[jh]) for jh in JH)
            effective_cost = total_cost - total_saving_cfd_cons # consumer costs after CfD savings

            elastic_demand = sum(value(D_ELA[jh]) for jh in JH)
            battery_charge = sum(value(charge[jh]) for jh in JH)
            battery_discharge = sum(value(discharge[jh]) for jh in JH)


            push!(df_cfd, (
                string(m), 
                total_saving_cfd_cons, 
                total_cost, 
                effective_cost,
                elastic_demand,
                battery_charge,
                battery_discharge,
                self_consumption_ratio,
                direct_pv_use,
                battery_charge_from_pv,
                pv_exported,
                ))
        end
    end

    if nrow(df_cfd) > 0
        filename = joinpath(home_dir, "Results", string("Scenario_", scenario_overview_row["scen_number"], "_CfD_", sens, ".csv"))
        col_order = [
            :TypeConsumers, 
            :TotalCfDSaving, 
            :TotalCost, 
            :EffectiveCost, 
            :ElasticDemand, 
            :BatteryCharge, 
            :BatteryDischarge, 
            :SelfConsumptionRatio,
            :PV_DirectUse,
            :PV_BatteryUse,
            :PV_Exported
        ]
        # Round all numeric columns to 2 decimals (skip the first column)
        for col in col_order[2:end]
            df_cfd[!, col] = round.(df_cfd[!, col], digits=2)
        end

        # Stack and unstack for transposed format
        df_long = stack(df_cfd, col_order[2:end], variable_name = "Metric", value_name = "Value")
        df_t = unstack(df_long, :Metric, :TypeConsumers, :Value)

        CSV.write(filename, df_t)
        println("✅ Saved transposed CfD + flexibility results to: ", filename)
    end
end
