# Save results
function save_results(mdict::Dict,EOM::Dict,ADMM::Dict,results::Dict,data::Dict,agents::Dict,scenario_overview_row::DataFrameRow,sens, market_design::AbstractString, scen_ts::AbstractString, years::Dict)
nY = data["General"]["nYears"]
nR = data["General"]["nReprDays"]
nT = data["General"]["nTimesteps"]

idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year

# folders
results_dir = joinpath(home_dir,string("Results_", data["General"]["nReprDays"], "_repr_days"))
out_dir = joinpath(results_dir, String(market_design))

# note that type of "sens" is not defined as a string stored in a dictionary is of type String31, whereas a "regular" string is of type String. Specifying one or the other may throw errors.
vector_output = [scenario_overview_row["scen_number"]; sens; ADMM["n_iter"]; ADMM["walltime"];ADMM["Residuals"]["Primal"]["EOM"][end];ADMM["Residuals"]["Dual"]["EOM"][end]]
CSV.write(joinpath(out_dir,string(scen_ts,"_",market_design,"_overview_results.csv")), DataFrame(reshape(vector_output,1,:),:auto), delim=";",append=true);

# Net profits
obj = Dict()
for m in agents[:eom]
    obj[m] = JuMP.value(objective_value(mdict[m]))
end
CSV.write(joinpath(out_dir,"expressions",string("objective.csv")), DataFrame(agent = collect(keys(obj)), weigthed_obj = collect(values(obj))), delim=";");

# CONSUMERS
consumer_profit = [collect(value.(mdict[m].ext[:expressions][:consumer_profit])) for m in agents[:Cons]]
consumer_costs   = [collect(value.(mdict[m].ext[:expressions][:consumer_costs]))  for m in agents[:Cons]]
consumer_mv   = [collect(value.(mdict[m].ext[:expressions][:consumer_mv]))      for m in agents[:Cons]]

idxs = sort(collect(keys(years)))          # [1,2,3]
sorted_years = [years[i] for i in idxs]    # [2018,2021,2022]
year_labels = string.(sorted_years)        # ["2018","2021","2022"]

df_profit = DataFrame(Consumer = String.(agents[:Cons]))
for (y, ylab) in enumerate(year_labels)
    df_profit[!, Symbol(ylab)] = getindex.(consumer_profit, y)
end

# costs
df_costs = DataFrame(Consumer = String.(agents[:Cons]))
for (j, ylab) in enumerate(year_labels)
    df_costs[!, Symbol(ylab)] = getindex.(consumer_costs, j)
end

#= mv
df_mv = DataFrame(Consumer = String.(agents[:Cons]))
for (j, ylab) in enumerate(year_labels)
    df_mv[!, Symbol(ylab)] = getindex.(consumer_mv, j)
end =#

CSV.write(joinpath(out_dir, "expressions", string(scen_ts, "_", market_design, "_consumer_profit.csv")),df_profit; delim=";")
CSV.write(joinpath(out_dir, "expressions", string(scen_ts, "_", market_design, "_consumer_costs.csv")),df_costs; delim=";")
#CSV.write(joinpath(out_dir, "expressions", string(scen_ts, "_", market_design, "_consumer_mv.csv")),df_mv; delim=";")

# Generators

    for jy in 1:nY
        #CSV.write(joinpath(home_dir,string("Results_",data["General"]["nReprDays"],"_repr_days"),string(market_design,"_demand_",jy,".csv")), DataFrame(EOM["D"][:,:,jy],:auto), delim=";");
        CSV.write(joinpath(out_dir,"electricity_price",string(scen_ts,"_",market_design,"_electricity_price_year_",jy,".csv")), DataFrame(results["λ"]["EOM"][end][:,:,jy],:auto), delim=";");

        for m in agents[:Gen]
            CSV.write(joinpath(out_dir,"generation","Gen",string(m), string(scen_ts,"_",market_design,"_generation_",m,"_year",jy,".csv")), DataFrame(results["g"][m][end][:,:,jy], :auto); delim=";")
        end

        for m in agents[:Cons]
            CSV.write(joinpath(out_dir,"generation","Cons",string(m), string(scen_ts,"_",market_design,"_generation_",m,"_year",jy,".csv")), DataFrame(results["g"][m][end][:,:,jy], :auto); delim=";")
            CSV.write(joinpath(out_dir,"D_ELA",string(m),string(scen_ts,"_",market_design,"_elastic_demand_",m,"_year",jy,".csv")), DataFrame(results["D_ELA"][m][end][:,:,jy],:auto), delim=";")
            CSV.write(joinpath(out_dir,"SOC",string(m),string(scen_ts,"_",market_design,"_SOC_",m,"_year",jy,".csv")), DataFrame(results["SOC"][m][end][:,:,jy],:auto), delim=";")
            CSV.write(joinpath(out_dir,"charge",string(m),string(scen_ts,"_",market_design,"_charge_",m,"_year",jy,".csv")), DataFrame(results["charge"][m][end][:,:,jy],:auto), delim=";")
            CSV.write(joinpath(out_dir,"discharge",string(m),string(scen_ts,"_",market_design,"_discharge_",m,"_year",jy,".csv")), DataFrame(results["discharge"][m][end][:,:,jy],:auto), delim=";")
        end

            # EOM
            g_out = zeros(nT*nR, EOM["nAgents"])
            mm = 1
        for m in agents[:eom]
            g_out[:, mm] = vec(results["g"][m][end][:,:,jy]) # reshape to 2D vector
            mm = mm+1
        end
        # volledige output matrix
        mat_output = hcat(collect(1:nT*nR),vec(results["λ"]["EOM"][end][:,:,jy]),g_out,-vec(EOM["D"][:,:,jy]))
        header_g = string.("G_", vcat(agents[:Gen], agents[:Cons]))
        CSV.write(joinpath(out_dir,"total",string(scen_ts,"_",market_design,"_total_year", jy,".csv")), 
        DataFrame(mat_output,:auto), delim=";",header=["Timestep";"Price";header_g;"Demand"]);
    end


# 1) Plot
df = CSV.read(joinpath(out_dir, string(scen_ts,"_",market_design,"_ADMM_residuals_all.csv")), DataFrame; delim=";")

# 2) Plot maken
plot(df.iteration, df.primal_residual,
     label = "Primal residual",
     xlabel = "Iteratie",
     ylabel = "Residual",
     lw = 2)

plot!(df.iteration, df.dual_residual,
      label = "Dual residual",
      lw = 2,
      linestyle = :dash)

savefig(joinpath(out_dir, string(scen_ts,"_",market_design,"_ADMM_residuals_plot.png")))

end