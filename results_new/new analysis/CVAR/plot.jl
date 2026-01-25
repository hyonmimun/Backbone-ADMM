using CSV, DataFrames, Plots

# Read the data
df = CSV.read("results_new/new analysis/CVAR/CVAR_change_gen.csv", DataFrame)

# Define RES generator group
res_gens = ["SolarPanels", "WindOnshore", "WindOffshore"]
risk_levels = names(df)[2:end]
x = parse.(Float64, risk_levels)

plt = plot(size=(600,400), legend=:outerbottomright, xlabel="Risk aversion", ylabel="CfD - EOM CVaR [M€]", title="RES Generators", xflip=true, ylims=(-5,60))

for gen in res_gens
    y = df[df.agent .== gen, risk_levels] |> Matrix |> vec
    plot!(plt, x, y, label=gen, marker=:circle)
end

hline!(plt, [0], color=:black, linestyle=:dash, label="")
savefig(plt, "results_new/new analysis/CVAR/CVAR_RES.png")
display(plt)


########### Consumers #############
# Read the data
df = CSV.read("results_new/new analysis/CVAR/CVAR_change_cons.csv", DataFrame)

risk_levels = names(df)[2:end]
x = parse.(Float64, risk_levels)

plt = plot(size=(600,400), legend=:outerbottomright, xlabel="Risk aversion", ylabel="CfD - EOM CVaR [M€]", title="CVAR Change for Consumers", xflip=true)

for agent in df.agent
    y = df[df.agent .== agent, risk_levels] |> Matrix |> vec
    plot!(plt, x, y, label=agent, marker=:circle)
end

hline!(plt, [0], color=:black, linestyle=:dash, label="")
savefig(plt, "results_new/new analysis/CVAR/CVAR_change_cons.png")