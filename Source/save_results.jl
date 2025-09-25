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
vector_output = [scenario_overview_row["scen_number"]; sens; ADMM["n_iter"]; ADMM["walltime"];ADMM["Residuals"]["Primal"]["EOM"][end];ADMM["Residuals"]["Dual"]["EOM"][end]; data["ADMM"]["rho_EOM"]]
CSV.write(joinpath(home_dir,string("overview_results.csv")), DataFrame(reshape(vector_output,1,:),:auto), delim=";",append=true);

# Net profits for last iteration
obj = Dict()
for m in agents[:eom]
    obj[m] = JuMP.value(objective_value(mdict[m]))
end
CSV.write(joinpath(out_dir,"expressions",string("objective.csv")), DataFrame(agent = collect(keys(obj)), weigthed_obj = collect(values(obj))), delim=";");

##### Expressions for last iteration #####
idxs = sort(collect(keys(years)))          # [1,2,3]
sorted_years = [years[i] for i in idxs]    # [2018,2021,2022]
year_labels = string.(sorted_years)        # ["2018","2021","2022"]

# Consumers
if market_design == "EOM"
utility_term = [collect(value.(mdict[m].ext[:expressions][:utility_term])) for m in agents[:Cons]]
consumer_profit = [collect(value.(mdict[m].ext[:expressions][:consumer_profit])) for m in agents[:Cons]]
consumer_settlement   = [collect(value.(mdict[m].ext[:expressions][:consumer_settlement]))  for m in agents[:Cons]]
tail_diff   = [collect(value.(mdict[m].ext[:variables][:u])) for m in agents[:Cons]]
elseif market_design == "cfd"
    utility_term = [collect(value.(mdict[m].ext[:expressions][:utility_term])) for m in agents[:Cons]]
    consumer_profit = [collect(value.(mdict[m].ext[:expressions][:cfd_consumer_profit])) for m in agents[:Cons]]
    consumer_settlement   = [collect(value.(mdict[m].ext[:expressions][:consumer_settlement]))  for m in agents[:Cons]]
    tail_diff   = [collect(value.(mdict[m].ext[:variables][:u])) for m in agents[:Cons]]
end

df_utility = DataFrame(Consumer = String.(agents[:Cons]))
df_profit = DataFrame(Consumer = String.(agents[:Cons]))
df_settlement = DataFrame(Consumer = String.(agents[:Cons]))
df_tail_diff = DataFrame(Consumer = String.(agents[:Cons]))

for (y, ylab) in enumerate(year_labels)
    df_utility[!, Symbol(ylab)] = getindex.(utility_term, y)
    df_profit[!, Symbol(ylab)] = getindex.(consumer_profit, y)
    df_settlement[!, Symbol(ylab)] = getindex.(consumer_settlement, y)
    df_tail_diff[!, Symbol(ylab)] = getindex.(tail_diff, y)
end
CSV.write(joinpath(out_dir, "expressions","Cons", string(scen_ts, "_", market_design, "_utility_term.csv")),df_utility; delim=";")
CSV.write(joinpath(out_dir, "expressions","Cons", string(scen_ts, "_", market_design, "_consumer_profit.csv")),df_profit; delim=";")
CSV.write(joinpath(out_dir, "expressions","Cons", string(scen_ts, "_", market_design, "_consumer_settlement.csv")),df_settlement; delim=";")
CSV.write(joinpath(out_dir, "expressions","Cons", string(scen_ts, "_", market_design, "_consumer_tail_diff.csv")),df_tail_diff; delim=";")

# Generators
generator_profit = [collect(value.(mdict[m].ext[:expressions][:generator_profit])) for m in agents[:Gen]]
generator_revenue = [collect(value.(mdict[m].ext[:expressions][:generator_revenue])) for m in agents[:Gen]]
generator_costs   = [collect(value.(mdict[m].ext[:expressions][:generator_costs]))  for m in agents[:Gen]]
gen_tail_diff   = [collect(value.(mdict[m].ext[:variables][:u])) for m in agents[:Gen]]

df_genprofit = DataFrame(Generator = String.(agents[:Gen]))
df_genrev = DataFrame(Generator = String.(agents[:Gen]))
df_gencosts = DataFrame(Generator = String.(agents[:Gen]))
df_gen_tail_diff = DataFrame(Generator = String.(agents[:Gen]))

for (y, ylab) in enumerate(year_labels)
    df_genprofit[!, Symbol(ylab)] = getindex.(generator_profit, y)
    df_genrev[!, Symbol(ylab)] = getindex.(generator_revenue, y)
    df_gencosts[!, Symbol(ylab)] = getindex.(generator_costs, y)
    df_gen_tail_diff[!, Symbol(ylab)] = getindex.(gen_tail_diff, y)
end
CSV.write(joinpath(out_dir, "expressions","Gen", string(scen_ts, "_", market_design, "_generator_profit.csv")),df_genprofit; delim=";")
CSV.write(joinpath(out_dir, "expressions","Gen", string(scen_ts, "_", market_design, "_generator_revenue.csv")),df_genrev; delim=";")
CSV.write(joinpath(out_dir, "expressions","Gen", string(scen_ts, "_", market_design, "_generator_costs.csv")),df_gencosts; delim=";")
CSV.write(joinpath(out_dir, "expressions","Gen",string(scen_ts, "_", market_design, "_generator_tail_diff.csv")),df_gen_tail_diff; delim=";")

CVAR = zeros(length(agents[:Cons]))
VAR = zeros(length(agents[:Cons]))
for (mm, m) in enumerate(agents[:Cons])
    CVAR[mm] = value.(mdict[m].ext[:expressions][:CVAR])
    VAR[mm] = value.(mdict[m].ext[:variables][:α])
end
CSV.write(joinpath(out_dir,"expressions","Cons","$(scen_ts),$(market_design),CVAR_cons.csv"),
    DataFrame(permutedims(CVAR), string.("CVAR_", agents[:Cons])))

CSV.write(joinpath(out_dir,"expressions","Cons","$(scen_ts),$(market_design),VAR_cons.csv"),
DataFrame(permutedims(VAR), string.("VAR_", agents[:Cons])))

gen_CVAR= zeros(length(agents[:Gen]))
gen_VAR = zeros(length(agents[:Gen]))
for (mm, m) in enumerate(agents[:Cons])
    gen_CVAR[mm] = value.(mdict[m].ext[:expressions][:CVAR])
    gen_VAR[mm] = value.(mdict[m].ext[:variables][:α])
end
CSV.write(joinpath(out_dir,"expressions","Gen","$(scen_ts),$(market_design),CVAR_gen.csv"),
    DataFrame(permutedims(gen_CVAR), string.("CVAR_", agents[:Gen])))

CSV.write(joinpath(out_dir,"expressions","Gen","$(scen_ts),$(market_design),VAR_gen.csv"),
DataFrame(permutedims(gen_VAR), string.("VAR_", agents[:Gen])))

##### Variables for all iterations #####   
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

        #CSV.write(joinpath(out_dir, "generation", "total_demand",string(scen_ts, "_", market_design, "_total_demand_year", jy, ".csv")),DataFrame(total_demand, :auto); delim=';')
        #CSV.write(joinpath(out_dir,"PV","$(scen_ts)_$(market_design)_$(m)_PV_timeseries_year$(jy).csv"), DataFrame(PV_cons[:, :, jy], :auto); delim=';')
        #CSV.write(joinpath(out_dir,"generation","Cons",string(m),string(scen_ts,"_",market_design,"_D_ela_fix_",m,"_year",jy,".csv")), DataFrame(D_fix_ela,:auto), delim=";")

        # total demand load 
        # D_ELA + D_fixed
        # consumer PV
        total_cons = zeros(nT, nR)
        PV_total = zeros(nT, nR)
        D_fixed = zeros(nT,nR)
        D_ela = zeros(nT,nR)
        D_fix_ela = zeros(nT,nR)
        tot_charge = zeros(nT,nR)
        tot_discharge = zeros(nT,nR)
        tot_SOC = zeros(nT,nR)

        for m in agents[:Cons]
            total_cons .+= results["g"][m][end][:,:,jy]
            PV_total .+= mdict[m].ext[:timeseries][:PV][:,:,jy]
            D_fixed .+= mdict[m].ext[:parameters][:D_fixed][:,:,jy]
            D_ela .+= results["D_ELA"][m][end][:,:,jy]
            D_fix_ela .+= D_fixed .+ D_ela
            tot_charge .+= results["charge"][m][end][:,:,jy]
            tot_discharge .+= results["discharge"][m][end][:,:,jy]
            tot_SOC .+= results["SOC"][m][end][:,:,jy]
        end

        gen_total = zeros(nT,nR)
        for m in agents[:Gen]
            gen_total .+=results["g"][m][end][:,:,jy]
        end
        total_demand = -(EOM["D"][:,:,jy])
        
        mat_outp = hcat(collect(1:nT*nR), vec(gen_total),vec(total_demand), vec(total_cons),vec(PV_total),vec(tot_SOC),vec(tot_charge),vec(tot_discharge))
        colnames = Symbol.(["Timestep","total_gen", "total_demand", "total_cons", "PV_cons","tot_SOC","tot_charging","tot_discharging"])

        df = DataFrame(mat_outp,colnames)
        
        CSV.write(joinpath(out_dir,"total",string(scen_ts,"_",market_design,"_all_output_", jy,".csv")), 
        df,delim=";")

            # EOM
            g_out = zeros(nT*nR, EOM["nAgents"])
            mm = 1
        for m in agents[:eom]
            g_out[:, mm] = vec(results["g"][m][end][:,:,jy]) # reshape to 2D vector
            mm = mm+1
        end
        # volledige output matrix
        mat_output = hcat(collect(1:nT*nR),vec(results["λ"]["EOM"][end][:,:,jy]),g_out,-vec(EOM["D"][:,:,jy]), vec(PV_total))
        header_g = string.("G_", vcat(agents[:Gen], agents[:Cons]))
        CSV.write(joinpath(out_dir,"total",string(scen_ts,"_",market_design,"_total_year", jy,".csv")), 
        DataFrame(mat_output,:auto), delim=";",header=["Timestep";"Price";header_g;"Demand";"Total_PV"]);
    end

##### Plot ADMM residuals for all iterations #####
df = CSV.read(joinpath(out_dir, string(scen_ts,"_",market_design,"_ADMM_residuals_all.csv")), DataFrame,delim=";")

plot(df.iteration, df.primal_residual,
     label = "Primal residual",
     xlabel = "Iteration",
     ylabel = "Residuals $(scen_ts) $(market_design)",
     lw = 2)

plot!(df.iteration, df.dual_residual,
      label = "Dual residual",
      lw = 2)

if market_design == "cfd"
    plot!(df.iteration, df.cfd_primal,
      label = "CfD primal residual",
      lw = 2,
      linestyle = :dash)

      plot!(df.iteration, df.cfd_dual,
      label = "CfD dual residual",
      lw = 2,
      linestyle = :dash)
end
savefig(joinpath(out_dir, string(scen_ts,"_",market_design,"_ADMM_residuals_plot.png")))

end