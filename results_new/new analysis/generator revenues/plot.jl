using CSV, DataFrames, Plots

# Read the data
df = CSV.read("results_new/new analysis/generator revenues/total_risk_premium_gen.csv", DataFrame)

# Define RES generator group
res_gens = ["SolarPanels", "WindOnshore", "WindOffshore"]
risk_levels = names(df)[2:end]
x = parse.(Float64, risk_levels)

plt = plot(size=(600,400), legend=:outerbottomright, xlabel="Risk aversion [β]", ylabel="Risk premium (CfD - EOM) [M€]", title="Risk Premium RES Gen", xflip=true, ylims=(-20,50))

for gen in res_gens
    y = df[df.Generator .== gen, risk_levels] |> Matrix |> vec
    plot!(plt, x, y, label=gen, marker=:circle)
end

hline!(plt, [0], color=:black, linestyle=:dash, label="")
savefig(plt, "results_new/new analysis/generator revenues/total_risk_premium_RES.png")
