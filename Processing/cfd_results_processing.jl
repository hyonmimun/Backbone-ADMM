using JLD2, DataFrames, CSV


jld_path  = joinpath("Results", "cfd", "$(scen_ts)_$(market_design).jld2")
out_prefx = joinpath("Results", "cfd", "$(scen_ts)_cfd_agents_results")

@load jld_path results ADMM EOM agents data

get_latest(buf) = buf[end]
to_str(k) = String(k)
nY = data["General"]["nYears"]
years = collect(1:nY)

function sum_over_time_and_reprdays(A::AbstractArray)
    ndims(A) == 3 || error("Verwacht 3D array (nT,nR,nY)")
    vec(dropdims(sum(A; dims=(1,2)), dims=(1,2)))
end

function add_series!(df::DataFrame, agent_type::AbstractString, agent::AbstractString,
                     metric::AbstractString, series::AbstractVector, years)
    @assert length(series) == length(years)
    for (y, v) in zip(years, series)
        push!(df, (y, agent_type, agent, metric, Float64(v)))
    end
end

# Long-format tabel: alleen individuele agents (Gen + Cons)
df = DataFrame(year=Int[], agent_type=String[], agent=String[], metric=String[], value=Float64[])

# haskey(results, "g_cfd") || error("CfD-resultaten niet gevonden. Is market_design = \"cfd\" gedraaid?")

# Generators (per individuele generator)
for (gen, buf) in results["g_cfd"]
    g3d = get_latest(buf)                         # (nT,nR,nY)
    g_y = sum_over_time_and_reprdays(g3d)
    add_series!(df, "Gen", to_str(gen), "g_cfd_total", g_y, years)
end
for (gen, buf) in get(results, "Q_cfd_gen", Dict())
    add_series!(df, "Gen", to_str(gen), "Q_cfd_gen", get_latest(buf), years)
end
for (gen, buf) in get(results, "cfd_payout_gen", Dict())
    add_series!(df, "Gen", to_str(gen), "cfd_payout_gen", get_latest(buf), years)
end
for (gen, buf) in get(results, "cfd_premium_gen", Dict())
    add_series!(df, "Gen", to_str(gen), "cfd_premium_gen", get_latest(buf), years)
end
for (gen, buf) in get(results, "cfd_penalty_gen", Dict())
    add_series!(df, "Gen", to_str(gen), "cfd_penalty_gen", get_latest(buf), years)
end

# Consumenten (per individuele consument)
for (con, buf) in get(results, "Q_cfd_con", Dict())
    add_series!(df, "Cons", to_str(con), "Q_cfd_con", get_latest(buf), years)
end
for (con, buf) in get(results, "cfd_payout", Dict())
    add_series!(df, "Cons", to_str(con), "cfd_payout_con", get_latest(buf), years)
end
for (con, buf) in get(results, "cfd_premium", Dict())
    add_series!(df, "Cons", to_str(con), "cfd_premium_con", get_latest(buf), years)
end
for (con, buf) in get(results, "cfd_penalty_con", Dict())
    add_series!(df, "Cons", to_str(con), "cfd_penalty_con", get_latest(buf), years)
end

for (con, buf) in get(results, "share_cfd_con", Dict())
    add_series!(df, "Cons", to_str(con), "share_cfd_con", get_latest(buf), years)
end

# ---- Schrijf één CSV per jaar: rijen = (agent_type, agent), kolommen = metrics ----
for y in years
    df_y = filter(:year => ==(y), df)

    # Pivot naar wide: keys = [:agent_type, :agent], kolommen = :metric
    wide = unstack(df_y, [:agent_type, :agent], :metric, :value)

    # Missende combinaties opvullen met 0
    for c in names(wide)
        if !(c in (:agent_type, :agent))
            wide[!, c] = coalesce.(wide[!, c], 0.0)
        end
    end

    # Sorteer: eerst op agent_type, dan op agent
    sort!(wide, [:agent_type, :agent])

    # Bestandsnaam en schrijven
    ytag = lpad(string(y), 2, '0')  # Y01, Y02, ...
    outfile_csv = out_prefx * "_Y$(ytag).csv"
    CSV.write(outfile_csv, wide)
    println("Geschreven: ", outfile_csv)
end