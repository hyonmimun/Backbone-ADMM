# Save results
function save_results(mdict::Dict,EOM::Dict,ADMM::Dict,results::Dict,data::Dict,agents::Dict,scenario_overview_row::DataFrameRow,sens, market_design::AbstractString, years::Dict)
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

# (risk-adjusted) expected profit - penalties
obj = Dict()
for m in agents[:eom]
    obj[m] = JuMP.value(objective_value(mdict[m]))
end
CSV.write(joinpath(out_dir,"expressions",string("objective.csv")), DataFrame(agent = collect(keys(obj)), weigthed_obj = collect(values(obj))), delim=";");

########### Expressions for last iteration ############
idxs = sort(collect(keys(years)))          # [1,2,3]
sorted_years = [years[i] for i in idxs]    # [2018,2021,2022]
year_labels = string.(sorted_years)        # ["2018","2021","2022"]

# row for each consumer
#df_utility = DataFrame(Consumer = String.(agents[:Cons]))
df_profit = DataFrame(Consumer = String.(agents[:Cons]))
df_settlement = DataFrame(Consumer = String.(agents[:Cons]))
df_tail_diff = DataFrame(Consumer = String.(agents[:Cons]))
df_penalty_con = DataFrame(Consumer = String.(agents[:Cons]))

# Every column has the same length as the number of rows (agents) = empty columns
for ylab in year_labels
    col = Symbol(ylab)
    df_profit[!, col]      = Vector{Float64}(undef, length(agents[:Cons]))
    df_settlement[!, col]  = Vector{Float64}(undef, length(agents[:Cons]))
    df_tail_diff[!, col]   = Vector{Float64}(undef, length(agents[:Cons]))
    df_penalty_con[!, col] = Vector{Float64}(undef, length(agents[:Cons]))
end

# Consumers
for (i,m) in enumerate(agents[:Cons]) # i = index, the specific element (choose row)
#utility_term = [collect(value.(mdict[m].ext[:expressions][:utility_term]))] # 3D array not nY vector
consumer_profit = collect(value.(mdict[m].ext[:expressions][:consumer_profit]))
consumer_settlement   = collect(value.(mdict[m].ext[:expressions][:consumer_settlement]))
consumer_penalty   = collect(value.(mdict[m].ext[:expressions][:consumer_penalty]))
tail_diff   = collect(value.(mdict[m].ext[:variables][:u]))

for (y, ylab) in enumerate(year_labels) # y = index/position of element, ylab = specific year
    #df_utility[!, Symbol(ylab)] = utility_term[y]
    df_profit[i, Symbol(ylab)] = consumer_profit[y]
    df_settlement[i, Symbol(ylab)] = consumer_settlement[y]
    df_tail_diff[i, Symbol(ylab)] = tail_diff[y]
    df_penalty_con[i, Symbol(ylab)] = consumer_penalty[y]
end

#CSV.write(joinpath(out_dir, "expressions","Cons", string(market_design, "_utility_term.csv")),df_utility; delim=";")
CSV.write(joinpath(out_dir, "expressions","Cons", string(market_design, "_consumer_profit.csv")),df_profit; delim=";")
CSV.write(joinpath(out_dir, "expressions","Cons", string(market_design, "_consumer_settlement.csv")),df_settlement; delim=";")
CSV.write(joinpath(out_dir, "expressions","Cons", string(market_design, "_consumer_tail_diff.csv")),df_tail_diff; delim=";")
CSV.write(joinpath(out_dir, "expressions","Cons", string(market_design, "_consumer_penalty.csv")),df_penalty_con; delim=";")

if market_design == "cfd"
# make dataframe
df_cfd_profit = DataFrame(Consumer = String.(agents[:Cons]))
df_cfd_payout = DataFrame(Consumer = String.(agents[:Cons]))

# Maak de jaarkolommen aan (zelfde lengte als aantal consumenten)
for ylab in year_labels
    column = Symbol(ylab)
    df_cfd_profit[!, column] = Vector{Float64}(undef, length(agents[:Cons]))
    df_cfd_payout[!, column] = Vector{Float64}(undef, length(agents[:Cons]))
end
    for (i,m) in enumerate(agents[:Cons])
    cfd_consumer_profit = collect(value.(mdict[m].ext[:expressions][:cfd_consumer_profit]))
    cfd_payout = collect(value.(mdict[m].ext[:expressions][:cfd_payout]))

    for (y, ylab) in enumerate(year_labels)
        df_cfd_profit[i, Symbol(ylab)] = cfd_consumer_profit[y]
        df_cfd_payout[i, Symbol(ylab)] = cfd_payout[y]
    end

    CSV.write(joinpath(out_dir, "expressions","Cons","total_CFD_consumer_profit.csv"),df_cfd_profit; delim=";")
   
    CSV.write(joinpath(out_dir,"expressions","Cons", "cfd_payout_cons.csv"), df_cfd_payout; delim=";")
end
end
end

# Generators
# initialize dataframe with rows = number of generators
df_genprofit = DataFrame(Generator = String.(agents[:Gen]))
df_genrev = DataFrame(Generator = String.(agents[:Gen]))
df_gencosts = DataFrame(Generator = String.(agents[:Gen]))
df_gen_tail_diff = DataFrame(Generator = String.(agents[:Gen]))
df_gen_penalty = DataFrame(Generator = String.(agents[:Gen]))

for ylab in year_labels
    col = Symbol(ylab)

    df_genprofit[!, col] = Vector{Float64}(undef, length(agents[:Gen]))
    df_genrev[!, col] = Vector{Float64}(undef, length(agents[:Gen]))
    df_gencosts[!, col] = Vector{Float64}(undef, length(agents[:Gen]))
    df_gen_tail_diff[!, col] = Vector{Float64}(undef, length(agents[:Gen]))
    df_gen_penalty[!, col] = Vector{Float64}(undef, length(agents[:Gen]))
end

for (i,m) in enumerate(agents[:Gen])
generator_profit = collect(value.(mdict[m].ext[:expressions][:generator_profit]))
generator_revenue = collect(value.(mdict[m].ext[:expressions][:generator_revenue]))
generator_costs = collect(value.(mdict[m].ext[:expressions][:generator_costs]))
gen_tail_diff = collect(value.(mdict[m].ext[:variables][:u]))
generator_penalty = collect(value.(mdict[m].ext[:expressions][:generator_penalty]))

# add value for that year in the respective column
for (y, ylab) in enumerate(year_labels)
    df_genprofit[i, Symbol(ylab)] = generator_profit[y]
    df_genrev[i, Symbol(ylab)] = generator_revenue[y]
    df_gencosts[i, Symbol(ylab)] = generator_costs[y]
    df_gen_tail_diff[i, Symbol(ylab)] = gen_tail_diff[y]
    df_gen_penalty[i,Symbol(ylab)] = generator_penalty[y]
end

CSV.write(joinpath(out_dir, "expressions","Gen", string(market_design, "_eom_generator_profit.csv")),df_genprofit; delim=";")
CSV.write(joinpath(out_dir, "expressions","Gen", string(market_design, "_eom_generator_revenue.csv")),df_genrev; delim=";")
CSV.write(joinpath(out_dir, "expressions","Gen", string(market_design, "_eom_generator_costs.csv")),df_gencosts; delim=";")
CSV.write(joinpath(out_dir, "expressions","Gen",string(market_design, "_eom_generator_tail_diff.csv")),df_gen_tail_diff; delim=";")
CSV.write(joinpath(out_dir, "expressions","Gen",string(market_design, "_eom_generator_penalty.csv")),df_gen_penalty; delim=";")

if market_design == "cfd"

df_gen_cfd_payout = DataFrame(Generator = String.(agents[:Gen]))
df_gen_cfd_costs = DataFrame(Generator = String.(agents[:Gen]))
df_gen_cfd_profit = DataFrame(Generator = String.(agents[:Gen]))

for ylab in year_labels
    column = Symbol(ylab)
    df_gen_cfd_payout[!, column] = Vector{Float64}(undef, length(agents[:Gen]))
    df_gen_cfd_costs[!, column] = Vector{Float64}(undef, length(agents[:Gen]))
    df_gen_cfd_profit[!,column] = Vector{Float64}(undef, length(agents[:Gen]))
end

for (i,m) in enumerate(agents[:Gen])
cfd_payout_gen = collect(value.(mdict[m].ext[:expressions][:cfd_payout_gen]))
#gen_cfd_costs = collect(value.(mdict[m].ext[:expressions][:gen_cfd_costs]))
cfd_generator_profit = collect(value.(mdict[m].ext[:expressions][:cfd_generator_profit]))

for (y, ylab) in enumerate(year_labels)
    df_gen_cfd_payout[i, Symbol(ylab)] = cfd_payout_gen[y]
    #df_gen_cfd_costs[i, Symbol(ylab)] = gen_cfd_costs[y]
    df_gen_cfd_profit[i, Symbol(ylab)] = cfd_generator_profit[y]
end

CSV.write(joinpath(out_dir, "expressions","Gen", "cfd_gen_payout.csv"),df_gen_cfd_payout; delim=";")
#CSV.write(joinpath(out_dir, "expressions","Gen", "cfd_generation_costs.csv"), df_gen_cfd_costs; delim=";")
CSV.write(joinpath(out_dir, "expressions","Gen", "cfd_gen_TOTAL_profit.csv"), df_gen_cfd_profit; delim=";")
end
end
end
################## Risk aversion #########################
CVAR = zeros(length(agents[:Cons]))
VAR = zeros(length(agents[:Cons]))

for (mm, m) in enumerate(agents[:Cons])
    CVAR[mm] = value.(mdict[m].ext[:expressions][:CVAR])
    VAR[mm] = value.(mdict[m].ext[:variables][:α])
end
CSV.write(joinpath(out_dir,"expressions","Cons","$(market_design),CVAR_cons.csv"),
    DataFrame(permutedims(CVAR), string.("CVAR_", agents[:Cons])))

CSV.write(joinpath(out_dir,"expressions","Cons","$(market_design),VAR_cons.csv"),
DataFrame(permutedims(VAR), string.("VAR_", agents[:Cons])))

gen_CVAR= zeros(length(agents[:Gen]))
gen_VAR = zeros(length(agents[:Gen]))

for (mm, m) in enumerate(agents[:Gen])
    gen_CVAR[mm] = value.(mdict[m].ext[:expressions][:CVAR])
    gen_VAR[mm] = value.(mdict[m].ext[:variables][:α])
end
CSV.write(joinpath(out_dir,"expressions","Gen","$(market_design)_CVAR_gen.csv"),
    DataFrame(permutedims(gen_CVAR), string.("CVAR_", agents[:Gen])))

CSV.write(joinpath(out_dir,"expressions","Gen","$(market_design)_VAR_gen.csv"),
DataFrame(permutedims(gen_VAR), string.("VAR_", agents[:Gen])))

###################### Variables for all scenarios ##########################
for jy in 1:nY
        #CSV.write(joinpath(home_dir,string("Results_",data["General"]["nReprDays"],"_repr_days"),string(market_design,"_demand_",jy,".csv")), DataFrame(EOM["D"][:,:,jy],:auto), delim=";");
        CSV.write(joinpath(out_dir,"electricity_price",string(market_design,"_electricity_price_year_",jy,".csv")), 
        DataFrame(results["λ"]["EOM"][end][:,:,jy],:auto), delim=";");

        for m in agents[:Gen]
            CSV.write(joinpath(out_dir,"generation","Gen",string(m), string(market_design,"_generation_",m,"_year",jy,".csv")), DataFrame(results["g"][m][end][:,:,jy], :auto); delim=";")
        end

        for m in agents[:Cons]
            CSV.write(joinpath(out_dir,"generation","Cons",string(m), string(market_design,"_generation_",m,"_year",jy,".csv")), DataFrame(results["g"][m][end][:,:,jy], :auto); delim=";")
            CSV.write(joinpath(out_dir,"D_ELA",string(m),string(market_design,"_elastic_demand_",m,"_year",jy,".csv")), DataFrame(results["D_ELA"][m][end][:,:,jy],:auto), delim=";")
            if haskey(results["SOC"], m)
            CSV.write(joinpath(out_dir,"SOC",string(m),string(market_design,"_SOC_",m,"_year",jy,".csv")), DataFrame(results["SOC"][m][end][:,:,jy],:auto), delim=";")
            CSV.write(joinpath(out_dir,"charge",string(m),string(market_design,"_charge_",m,"_year",jy,".csv")), DataFrame(results["charge"][m][end][:,:,jy],:auto), delim=";")
            CSV.write(joinpath(out_dir,"discharge",string(m),string(market_design,"_discharge_",m,"_year",jy,".csv")), DataFrame(results["discharge"][m][end][:,:,jy],:auto), delim=";")
            end
        end

        #CSV.write(joinpath(out_dir, "generation", "total_demand",string(market_design, "_total_demand_year", jy, ".csv")),DataFrame(total_demand, :auto); delim=';')
        #CSV.write(joinpath(out_dir,"generation","Cons",string(m),string(market_design,"_D_ela_fix_",m,"_year",jy,".csv")), DataFrame(D_fix_ela,:auto), delim=";")

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
            if haskey(mdict[m].ext[:timeseries], :PV)
                PV_total .+= mdict[m].ext[:timeseries][:PV][:,:,jy]
            else
                PV_total .+= zeros(nT, nR)
            end
            D_fixed .+= mdict[m].ext[:parameters][:D_fixed][:,:,jy]
            D_ela .+= results["D_ELA"][m][end][:,:,jy]
            D_fix_ela .+= D_fixed .+ D_ela
            # Battery aggregation: only add if this consumer has battery
            if haskey(results["SOC"], m)
                tot_charge .+= results["charge"][m][end][:,:,jy]
                tot_discharge .+= results["discharge"][m][end][:,:,jy]
                tot_SOC .+= results["SOC"][m][end][:,:,jy]
            end
        end

        gen_total = zeros(nT,nR)
        for m in agents[:Gen]
            gen_total .+=results["g"][m][end][:,:,jy]
        end
        total_demand = -(EOM["D"][:,:,jy])
        
        mat_outp = hcat(collect(1:nT*nR), vec(gen_total),vec(total_demand), vec(total_cons),vec(PV_total),vec(tot_SOC),vec(tot_charge),vec(tot_discharge))
        colnames = Symbol.(["Timestep","total_gen", "total_demand", "total_cons", "PV_cons","tot_SOC","tot_charging","tot_discharging"])

        df = DataFrame(mat_outp,colnames)
        
        CSV.write(joinpath(out_dir,"total","all_output",string(market_design,"_all_output_", jy,".csv")), 
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
        CSV.write(joinpath(out_dir,"total",string(market_design,"_total_year", jy,".csv")), 
        DataFrame(mat_output,:auto), delim=";",header=["Timestep";"Price";header_g;"Demand";"Total_PV"]);
    end

    ############################## Save ADMM history for analysis ###################################
    # Create history DataFrame
    n_iter = ADMM["n_iter"]
    history_df = DataFrame(
        iteration = 1:n_iter,
        primal_EOM = ADMM["History"]["Primal_EOM"],
        dual_EOM = vcat([0.0],ADMM["History"]["Dual_EOM"]),
        rho_EOM = ADMM["History"]["rho_EOM"]
    )

    if market_design == "cfd"
        history_df.primal_cfd = ADMM["History"]["Primal_cfd"]
        history_df.dual_cfd = vcat([0.0],ADMM["History"]["Dual_cfd"])
        history_df.rho_cfd = ADMM["History"]["rho_cfd"]
        history_df.zeta_cfd = ADMM["History"]["zeta_cfd"]
        history_df.imbalance_cfd = ADMM["History"]["imbalance_cfd"]
    end

    # Save to CSV
    CSV.write(joinpath(out_dir, "ADMM_iteration_history.csv"), history_df; delim=";")
    #CSV.read(joinpath(out_dir, "ADMM_iteration_history.csv"), DataFrame ,delim=";")

    plot(history_df.iteration, history_df.primal_EOM, 
            title= "EOM ADMM residuals",
            label = "EOM Primal Residual",
            xlabel = "Iteration",
            ylabel = "EOM Residuals for $(market_design)",
            lw = 2)

    plot!(history_df.iteration, history_df.dual_EOM, 
    label = "EOM Dual Residual", lw=2)

    savefig(savefig(joinpath(out_dir, "EOM_ADMM_residuals_plot.png")))
    
    plot(history_df.iteration, history_df.rho_EOM, 
                label = "ρ_EOM",
                xlabel = "Iteration",
                ylabel = "ρ $(market_design)",
                lw = 2)

    savefig(savefig(joinpath(out_dir, "rho_EOM_plot.png")))
    
    if market_design == "cfd"
        # CfD residuals plot
        p2 = plot(history_df.iteration, history_df.primal_cfd,
            label="CfD Primal Residual",
            xlabel="Iteration",
            ylabel="CfD Residuals",
            title="CfD Residuals",
            lw=2)
        plot!(p2, history_df.iteration, history_df.dual_cfd,
            label="CfD Dual Residual", lw=2)
        savefig(p2, joinpath(out_dir, "CfD_ADMM_residuals.png"))

        # Rho evolution plot
        p3 = plot(history_df.iteration, history_df.rho_cfd,
            label="ρ_cfd",
            xlabel="Iteration",
            ylabel="Penalty Parameter",
            title="CfD Penalty Evolution",
            lw=2)
        savefig(p3, joinpath(out_dir, "rho_cfd_evolution.png"))
        
        # Zeta evolution plot
        p4 = plot(history_df.iteration, history_df.zeta_cfd,
            label="ζ_cfd",
            xlabel="Iteration",
            ylabel="Premium (€/MWh)",
            title="CfD Premium Evolution",
            lw=2)
        hline!(p4, [0], color=:black, linestyle=:dash, label=false)
        savefig(p4, joinpath(out_dir, "cfd_totals", "zeta_cfd_evolution.png"))
    end

    ##################################### CfD results ########################################

        if market_design == "cfd"

        cfd_agents = DataFrame(agent_type=String[], agent=String[], Q_cfd=Float64[], Q_cfd_total=Float64[], share_cfd=Float64[], Q_cfd_bar=Float64[],cfd_penalty=Float64[], ζ_cfd=Float64[],cfd_premium=Float64[])

        for m in agents[:Gen]
        push!(cfd_agents, (
            "Gen",
            String(m),
            results["Q_cfd"][m][end],
            results["Q_cfd_gen_tot"][end],
            NaN,  
            results["Q_cfd_bar"][m][end],
            results["cfd_penalty_gen"][m][end],
            results[ "ζ"]["cfd"][end],
            results["cfd_premium_gen"][m][end],
                                        # geen share voor generators
        ))
        end

        for m in agents[:Cons]
        push!(cfd_agents, (
            "Cons",
            String(m),
            results["Q_cfd"][m][end],
            results["Q_cfd_con_tot"][end],
            results["share_cfd_con"][m][end],
            results["Q_cfd_bar"][m][end],
            results["cfd_penalty_con"][m][end],
            results[ "ζ"]["cfd"][end],
            results["cfd_premium"][m][end],
        ))
        end
        #sort!(cfd_agents,[:agent_type,:agent])
        
        CSV.write(joinpath(out_dir,"cfd_totals","cfd_agents_results.csv"), cfd_agents; delim=";")
        
        for jy in 1:nY
            # g_cfd_total over all generators for each timestep (nT x nR)
            CSV.write(joinpath(out_dir,"cfd_totals","g_cfd_totals",string("g_cfd_totals_",jy,".csv")), DataFrame(results["g_cfd_total"][end][:,:,jy], :auto); delim=";")

            # g_cfd per generator per timestep 
            for m in agents[:Gen]
            CSV.write(joinpath(out_dir,"g_cfd",string( "g_cfd_",m,"_",jy,".csv")), DataFrame(results["g_cfd"][m][end][:,:,jy], :auto); delim=";")
            end
        end

        # g_cfd_tot per generator over all timesteps sum(nT x nR) for each year
        df_g_cfd_tot_gen = DataFrame(Generator = string.(agents[:Gen]))
        
        for ylab in year_labels
            df_g_cfd_tot_gen[!, Symbol(ylab)] = Vector{Float64}(undef, length(agents[:Gen]))
        end

        for (i, g) in enumerate(agents[:Gen])
            G = results["g_cfd"][g][end]   # 3D array: (nT, nR, nY) met y = derde dim
            
            for (y_idx, ylab) in enumerate(year_labels)
                # Som over alle tijdstappen en repr-days van jaar y_idx
                df_g_cfd_tot_gen[i, Symbol(ylab)] = sum(@view G[:, :, y_idx])
                # 2D slice en sum = totale som.
            end
            CSV.write(joinpath(out_dir,"cfd_totals",string( "g_cfd_tot_yearly.csv")), df_g_cfd_tot_gen; delim=";")
        end

  ############################ Q_cfd results #####################################
    q_cfd_df = DataFrame(iteration = 1:n_iter)
            for m in agents[:all]
                q_cfd_df[!,m] = results["History"]["Q_cfd"][m][1:n_iter]
            end
            CSV.write(joinpath(out_dir, "cfd_totals", "Q_cfd_evolution.csv"), q_cfd_df)

        plot_q_cfd = plot(title="Generator Q_cfd", 
                            xlabel="Iteration",
                            ylabel="Q_cfd (GW)", 
                            lw=2, legend=:best)

        for m in agents[:Gen]
            plot!(plot_q_cfd, q_cfd_df.iteration, q_cfd_df[!,m], label=m) 
        end
        savefig(plot_q_cfd, joinpath(out_dir, "cfd_totals", "Q_cfd_gen.png"))

        plot_cons = plot(title="Consumer Q_cfd", xlabel="Iteration", ylabel="Q_cfd (GW)", lw=2, legend=:best)

        for m in agents[:Cons]
            plot!(plot_cons, q_cfd_df.iteration, q_cfd_df[!,m], label=m)
        end
        savefig(plot_cons, joinpath(out_dir, "cfd_totals", "Q_cfd_con.png"))

         # Plot all agents combined
    p_all = plot(title="All Agents Q_cfd Evolution",
                 xlabel="Iteration",
                 ylabel="Q_cfd (GW)",
                 lw=2,
                 legend=:outerright)
    
    for m in agents[:Gen]
        plot!(p_all, q_cfd_df.iteration, q_cfd_df[!, m], 
              label=m, linestyle=:solid)
    end
    
    for m in agents[:Cons]
        plot!(p_all, q_cfd_df.iteration, q_cfd_df[!, m], 
              label=m, linestyle=:dash)
    end
    
    # Add zero reference line
    hline!(p_all, [0], color=:black, linestyle=:dot, label="Zero", lw=1)
    
    savefig(p_all, joinpath(out_dir, "cfd_totals", "Q_cfd_all_agents.png"))
end
end 