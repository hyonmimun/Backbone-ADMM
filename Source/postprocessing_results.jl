using JLD2
using DataFrames
using CSV
using Statistics
using Plots

scenario = 2
variant  = "CfD"  # of wat je opgeslagen hebt
jld_path = joinpath("Results", "Scenario_$(scenario).jld2")
out_csv  = joinpath("Results", "Scenario_$(scenario)_last_iter_summary.csv")
out_csv_cfd = joinpath("Results", "Scenario_$(scenario)_cfd_payout_consumers_last_iter.csv")


@load jld_path results ADMM EOM agents data

λ_CfD = data["CfD"]["lambda_cfd"]
ζ_cfd = results["ζ"]["CfD"][end]
primal_residual_CfD = ADMM["Residuals"]["Primal"]["CfD"][end]
dual_residual_CfD = ADMM["Residuals"]["Dual"]["CfD"][end]

consumers = agents[:Cons]
generators = agents[:Gen]

# Generator results
Q_cfd_gen = results["Q_cfd_gen"]  # Dict per generator
gen_rows = [(AgentType = "Gen",
             Agent     = m,
             Q_cfd     = results["Q_cfd_gen"][m][end],
             cfd_penalty = results["cfd_penalty_gen"][m][end],
             Q_cfd_bar = results["Q_cfd_bar"][m][end],
             cfd_premium = results["cfd_premium_gen"][m][end],
             g_cfd_total = sum(results["g_cfd"][m][end])
             ) for m in generators]

             Q_cfd_gen_tot = sum(r.Q_cfd for r in gen_rows) # Q_cfd van alle generatoren gesommeerd over 1 iteratie


# Consumer results
Q_cfd_con = results["Q_cfd_con"]  # Dict per consumer
cons_rows = [(AgentType = "Cons",
              Agent     = m,
              Q_cfd     = results["Q_cfd_con"][m][end],
            cfd_penalty = results["cfd_penalty_con"][m][end],
             Q_cfd_bar = results["Q_cfd_bar"][m][end],
             cfd_premium = results["cfd_premium"][m][end]
             ) for m in consumers]

              Q_cfd_con_tot = sum(r.Q_cfd for r in cons_rows)

# Build DataFrame
df = DataFrame(
    Section = String[],
    AgentType = String[],
    Agent = String[],
    primal_CfD = Union{Missing,Float64}[],
    dual_CfD = Union{Missing,Float64}[],
    λ_CfD = Union{Missing,Float64}[],
    ζ_cfd   = Union{Missing,Float64}[],
    Q_cfd      = Union{Missing,Float64}[],
    Q_cfd_gen_tot = Union{Missing,Float64}[],
    Q_cfd_con_tot = Union{Missing,Float64}[],
    share_cfd = Union{Missing,Float64}[],
    g_cfd_total = Union{Missing,Float64}[],
    cfd_payout_sum = Union{Missing,Float64}[], #sum over all timesteps in 1 iteration
    cfd_premium = Union{Missing,Float64}[],
    cfd_penalty = Union{Missing,Float64}[],
    Q_cfd_bar = Union{Missing,Float64}[]
)
push!(df, (
    Section = "SUMMARY",
    AgentType = "ALL",
    Agent = "ALL",
    primal_CfD = primal_residual_CfD,
    dual_CfD = dual_residual_CfD,
    λ_CfD = λ_CfD,
    ζ_cfd   = ζ_cfd,
    Q_cfd  = missing,
    Q_cfd_gen_tot = Q_cfd_gen_tot,
    Q_cfd_con_tot = Q_cfd_con_tot,
    share_cfd = missing,
    g_cfd_total = missing,
    cfd_payout_sum = missing,
    cfd_premium = missing,
    cfd_penalty = missing,
    Q_cfd_bar = missing
))

for r in gen_rows
    cfd_payout_sum = sum(results["cfd_payout_gen"][r.Agent][end])
    #cfd_premium_sum = sum(results["cfd_premium_gen"][r.Agent][end])
    push!(df, (
        Section = "AGENT",
        AgentType = r.AgentType,
        Agent = r.Agent,
        primal_CfD = missing,  # niet herhalen per agent; alles staat in SUMMARY
        dual_CfD = missing,
        λ_CfD = missing,  # niet herhalen per agent; alles staat in SUMMARY
        ζ_cfd   = missing,
        Q_cfd  = r.Q_cfd,
        Q_cfd_gen_tot = missing,
        Q_cfd_con_tot = missing,
        share_cfd = cfd_share(r.Q_cfd, Q_cfd_gen_tot),
        g_cfd_total = r.g_cfd_total,
        cfd_payout_sum = cfd_payout_sum,
        cfd_premium = r.cfd_premium,
        cfd_penalty = r.cfd_penalty,
        Q_cfd_bar = r.Q_cfd_bar
    ))
end

for r in cons_rows
    cfd_payout_sum = sum(results["cfd_payout"][r.Agent][end])
    #cfd_premium_sum = sum(results["cfd_premium"][r.Agent][end])
    push!(df, (
        Section = "AGENT",
        AgentType = r.AgentType,
        Agent = r.Agent,
        primal_CfD = missing,  # niet herhalen per agent; alles staat in SUMMARY
        dual_CfD = missing,
        λ_CfD = missing,
        ζ_cfd   = missing,
        Q_cfd  = r.Q_cfd,
        Q_cfd_gen_tot = missing,
        Q_cfd_con_tot = missing,
        share_cfd = cfd_share(r.Q_cfd, Q_cfd_con_tot),
        g_cfd_total = missing,
        cfd_payout_sum = cfd_payout_sum,
        cfd_premium = r.cfd_premium,
        cfd_penalty = r.cfd_penalty,
        Q_cfd_bar = r.Q_cfd_bar
        ))
end

sort!(df, [:AgentType, :Agent])

CSV.write(out_csv, df, delim = ";")
println("✅ CSV geschreven naar: $out_csv")

#display(df)

out_csv_cfd_all = joinpath("Results", "Scenario_$(scenario)_cfd_payout_all_last_iter.csv")
nT = Int(data["General"]["nTimesteps"])
df_cfd_all = DataFrame(Timestep = 1:nT)

# Consumenten toevoegen
for m in consumers
    cp_last = results["cfd_payout"][m][end]  # vector laatste iteratie
    df_cfd_all[!, string(m) * "_CfD_payout"] = cp_last
end

# Generators toevoegen
generators = agents[:Gen]
for m in generators
    gp_last = results["cfd_payout_gen"][m][end]  # vector laatste iteratie
    gc_last = results["g_cfd"][m][end]
    # add columns
    df_cfd_all[!, string(m) * "_CfD_payout"] = gp_last
    df_cfd_all[!, string(m) * "_g_cfd"]  = gc_last

end

# Schrijf naar CSV
CSV.write(out_csv_cfd_all, df_cfd_all, delim = ";")
println("✅ Brede CSV geschreven naar: $out_csv_cfd_all")