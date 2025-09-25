using JLD2
using DataFrames
using CSV
using Statistics

isdefined(@__MODULE__, :home_dir) || (const home_dir = @__DIR__)


jld_path = joinpath("Results", "cfd", "$(scen_ts)_$(market_design).jld2")
out_csv = joinpath("Results", "cfd", "$(scen_ts)_yearly_summary.csv")

@load jld_path results ADMM EOM agents data

nY = data["General"]["nYears"]
nR = data["General"]["nReprDays"]
nT = data["General"]["nTimesteps"]

consumers  = agents[:Cons]
generators = agents[:Gen]
eom_agents = agents[:eom]

years = collect(1:nY)

# Haal laatste iteratie vector (per jaar) uit een CircularBuffer{Vector{Float64}}
last_vec_per_year = vbuf -> (v = vbuf[end]; length(v) == nY || error("len!=nY"); v)

# Sommeer per jaar over een Dict{agent => CircularBuffer{Vector}}
function sum_over_agents_vec(dictbuf::Dict, keys_list, nY)
    s = zeros(Float64, nY)
    for m in keys_list
        vbuf = dictbuf[m]
        s .+= last_vec_per_year(vbuf)
    end
    return s
end

# Sommeer over (t,r) uit een CircularBuffer{Array{Float64,3}} → Vector{Float64} per jaar
function sum_tr_per_year(arrbuf)
    A = arrbuf[end]                 # A :: Array{Float64,3} met (nT,nR,nY)
    size(A,3) == nY || error("A's 3e dim != nY")
    # som over 1e en 2e dimensie → 1×1×nY, daarna 'vec'
    vec(dropdims(sum(A; dims=(1,2)), dims=(1,2)))
end

ζ_cfd_vec = begin
    v = results["ζ"]["cfd"][end]       # CircularBuffer{Vector} → laatste vector
    length(v) == nY || error("ζ len != nY")
    v
end

# Totals per jaar
Q_cfd_gen_year        = sum_over_agents_vec(results["Q_cfd_gen"],        generators, nY)
Q_cfd_con_year        = sum_over_agents_vec(results["Q_cfd_con"],        consumers,  nY)
#Q_cfd_bar_gen_year    = sum_over_agents_vec(results["Q_cfd_bar"],        generators, nY)  # let op: Q_cfd_bar is bij :eom opgezet, maar je vult ‘m per type? pas desnoods aan
#Q_cfd_bar_con_year    = sum_over_agents_vec(results["Q_cfd_bar"],        consumers,  nY)  # idem

cfd_premium_gen_year  = sum_over_agents_vec(results["cfd_premium_gen"],  generators, nY)
cfd_premium_con_year  = sum_over_agents_vec(results["cfd_premium"],      consumers,  nY)

cfd_penalty_gen_year  = sum_over_agents_vec(results["cfd_penalty_gen"],  generators, nY)
cfd_penalty_con_year  = sum_over_agents_vec(results["cfd_penalty_con"],  consumers,  nY)

g_cfd_total_year      = sum_tr_per_year(results["g_cfd_total"])          # uit 3D → per jaar

df = DataFrame(
    Year                  = years,
    Section               = fill("SUMMARY", nY),
    AgentType             = fill("ALL", nY),
    Agent                 = fill("ALL", nY),
    ζ_cfd                 = ζ_cfd_vec,
    Q_cfd_gen_tot         = Q_cfd_gen_year,
    Q_cfd_con_tot         = Q_cfd_con_year,
    g_cfd_total           = g_cfd_total_year,
    cfd_premium_gen_tot   = cfd_premium_gen_year,
    cfd_premium_con_tot   = cfd_premium_con_year,
    cfd_penalty_gen_tot   = cfd_penalty_gen_year,
    cfd_penalty_con_tot   = cfd_penalty_con_year,
)

CSV.write(out_csv, df)
println("Schreef CfD yearly summary naar: $out_csv")


#= Generator results
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

#end =#