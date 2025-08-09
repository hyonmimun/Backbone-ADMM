using JLD2
using DataFrames
using CSV
using Statistics
using Plots

scenario = 2
variant  = "CfD"  # of wat je opgeslagen hebt
jld_path = joinpath("Results", "Scenario_$(scenario).jld2")
out_csv  = joinpath("Results", "Scenario_$(scenario)_last_iter_summary.csv")

@load jld_path results ADMM EOM agents data

lambda_CfD = data["CfD"]["lambda_cfd"]
ζ_cfd = results["ζ"]["CfD"][end]
primal_residual_CfD = ADMM["Residuals"]["Primal"]["CfD"][end]
dual_residual_CfD = ADMM["Residuals"]["Dual"]["CfD"][end]


consumers = agents[:Cons]
generators = agents[:Gen]

# Generator results
Q_cfd_gen = results["Q_cfd_gen"]  # Dictionary with Q_cfd_gen for each generator
    gen_rows = [(AgentType="Gen",
                Agent   = m,
                Q_cfd_gen = results["Q_cfd_gen"][m][end],
                Q_cfd_con = missing) for m in generators]

    Q_cfd_gen_tot = sum(r.Q_cfd_gen for r in gen_rows if r.Q_cfd_gen !== missing)

# Consumer results
Q_cfd_con = results["Q_cfd_con"]  # Dictionary with Q_cfd_gen for each generator
    cons_rows = [(AgentType="Cons",
                Agent   = m,
                Q_cfd_gen = missing,
                Q_cfd_con = results["Q_cfd_con"][m][end]) for m in consumers]

    Q_cfd_con_tot = sum(r.Q_cfd_con for r in cons_rows if r.Q_cfd_con !== missing)

    function cfd_share(val, total)
    return (total > 0 && val !== missing) ? (val / total) : missing
end

# Build DataFrame
df = DataFrame(
    Section = String[],
    AgentType = String[],
    Agent = String[],
    primal_residual_CfD = Union{Missing,Float64}[],
    dual_residual_CfD = Union{Missing,Float64}[],
    lambda_CfD = Union{Missing,Float64}[],
    zeta_cfd   = Union{Missing,Float64}[],
    Q_cfd_gen  = Union{Missing,Float64}[],
    Q_cfd_con  = Union{Missing,Float64}[],
    Q_cfd_gen_tot = Union{Missing,Float64}[],
    Q_cfd_con_tot = Union{Missing,Float64}[],
    share_cfd_gen = Union{Missing,Float64}[],
    share_cfd_con = Union{Missing,Float64}[]
)
push!(df, (
    Section = "SUMMARY",
    AgentType = "ALL",
    Agent = "ALL",
    primal_residual_CfD = primal_residual_CfD,
    dual_residual_CfD = dual_residual_CfD,
    lambda_CfD = lambda_CfD,
    zeta_cfd   = ζ_cfd,
    Q_cfd_gen  = missing,
    Q_cfd_con  = missing,
    Q_cfd_gen_tot = Q_cfd_gen_tot,
    Q_cfd_con_tot = Q_cfd_con_tot,
    share_cfd_gen = missing,
    share_cfd_con = missing
))

for r in gen_rows
    push!(df, (
        Section = "AGENT",
        AgentType = r.AgentType,
        Agent = r.Agent,
        primal_residual_CfD = missing,  # niet herhalen per agent; alles staat in SUMMARY
        dual_residual_CfD = missing,
        lambda_CfD = missing,  # niet herhalen per agent; alles staat in SUMMARY
        zeta_cfd   = missing,
        Q_cfd_gen  = r.Q_cfd_gen,
        Q_cfd_con  = missing,
        Q_cfd_gen_tot = missing,
        Q_cfd_con_tot = missing,
        share_cfd_gen = cfd_share(r.Q_cfd_gen, Q_cfd_gen_tot),
        share_cfd_con = missing
    ))
end

for r in cons_rows
    push!(df, (
        Section = "AGENT",
        AgentType = r.AgentType,
        Agent = r.Agent,
        primal_residual_CfD = missing,  # niet herhalen per agent; alles staat in SUMMARY
        dual_residual_CfD = missing,
        lambda_CfD = missing,
        zeta_cfd   = missing,
        Q_cfd_gen  = missing,
        Q_cfd_con  = r.Q_cfd_con,
        Q_cfd_gen_tot = missing,
        Q_cfd_con_tot = missing,
        share_cfd_gen = missing,
        share_cfd_con = cfd_share(r.Q_cfd_con, Q_cfd_con_tot)
        ))
end

sort!(df, [:Section, :AgentType, :Agent])

CSV.write(out_csv, df, delim = ";")
println("✅ CSV geschreven naar: $out_csv")

#display(df)