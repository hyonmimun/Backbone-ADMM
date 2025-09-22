using CSV, DataFrames, Dates, LinearAlgebra, Statistics

year          = 2022
year_nr = "year3"

market_design = "EOM"
scenario = "base"
variable = "SOC"
#agent_type = Cons #Gen
agent = "TypeA"


results_path = joinpath("Results_8_repr_days","$market_design","$variable","$agent")
synthetic_results_path = joinpath(results_path,"$(scenario)_$(market_design)_$(variable)_$(agent)_$year_nr.csv")
#synthetic_results_path = "Results_8_repr_days/EOM/SOC/TypeA/base_EOM_SOC_TypeA_year1.csv"
weights_path  = "Input/output_$year/ordering_variable_$year.csv"
out_path      = joinpath(results_path,"synthetic_$(scenario)_$(market_design)_$(variable)_$(agent)_$(year_nr).csv")

repr_results = CSV.read(synthetic_results_path, DataFrame)        # 24 x 8
weights_df = CSV.read(weights_path, DataFrame)     # 365 x 8

rep_mat = Matrix{Float64}(repr_results)    # (24 x 8)
weights_mat = Matrix{Float64}(weights_df)  # (365 x 8)

@assert size(rep_mat, 1) == 24 "Expect 24 uur-rijen in electricity_price_1.csv"
@assert size(rep_mat, 2) == size(weights_mat, 2) "Aantal representatieve dagen moet matchen"

# 24x365
year_24x365 = rep_mat * permutedims(weights_mat)
year_hours_8760 = vec(year_24x365)  # lengte 24*365 = 8760

# timestamps
t_start = DateTime(year, 1, 1, 0, 0, 0)
t_end   = DateTime(year, 12, 31, 23, 0, 0)
timestamps = collect(t_start:Hour(1):t_end)
@assert length(timestamps) == 8760 "Aantal timestamps is niet 8760; check schrikkeljaar of inputs."

out_df = DataFrame(timestamp = timestamps, SOC = year_hours_8760)
CSV.write(out_path, out_df)
println("Klaar! Weggeschreven naar: $out_path")


println("Dim rep_mat: ", size(rep_mat), "   Dim weights_mat: ", size(weights_mat))
println("Min/Max prijs (jaar): ", minimum(year_hours_8760), " / ", maximum(year_hours_8760))

#= Plot PDC
using Plots

df = CSV.read("Input/output_2018/prices_synthetic_timeseries.csv", DataFrame)

# ==== PDC MAKEN ====
prices = collect(df.eom_price)                 # Vector van 8760 prijzen
p_sorted = sort(prices; rev=true)              # Aflopend sorteren
n = length(p_sorted)

# x-as: aandeel van uren (0–100%)
#x_pct = range(0, 100; length=n)                # 0% ... 100%
hours = 1:n

# ==== PLOT ====
default(fmt = :png)                            # voor saven naar .png
plot(hours, p_sorted,
     xlabel="hours",
     ylabel="EOM price [€/MWh]",
     legend=false,
     title="Price Duration Curve 2022 (n=$(n) uur)")

#= (Optioneel) wat referentiepercentielen markeren
p10, p50, p90 = quantile(prices, (0.10, 0.50, 0.90))
hline!([p10, p50, p90], linestyle=:dash)
annotate!(100, p10, text("P10 ≈ $(round(p10,digits=1))", 8, :left))
annotate!(4000, p50, text("P50 ≈ $(round(p50,digits=1))", 8, :left))
annotate!(8000, p90, text("P90 ≈ $(round(p90,digits=1))", 8, :left))
=#
# ==== OPSLAAN ====
savefig("Input/output_2022/price_duration_curve_2022.png")
println("PDC opgeslagen als price_duration_curve_2022.png") =#