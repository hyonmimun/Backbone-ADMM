using CSV, DataFrames, Plots

# Read the data
df = CSV.read("results_new/new analysis/price of risk/normalized_CVAR_gen_difference.csv", DataFrame)

risk_levels = names(df)[2:end]
x = parse.(Float64, risk_levels)

plt = plot(size=(700,400), legend=:outertopright, xlabel="Risk aversion [β]", ylabel="CVAR difference [€/MWh]", title="RES Pool CVAR Difference (CfD - EOM)", xflip=true, left_margin=5Plots.mm, bottom_margin=5Plots.mm, ylims=(-1,6))

res_gens = ["SolarPanels", "WindOffshore", "WindOnshore"]

for agent in res_gens
    y = (df[df.agent .== agent, risk_levels] |> Matrix |> vec) .* 1000
    plot!(plt, x, y, label=agent, marker=:circle)
end

hline!(plt, [0], color=:black, linestyle=:dash, label="")
savefig(plt, "results_new/new analysis/CVAR/normalized_CVAR_gen_change.png")