using CSV, DataFrames, Plots

# Read the data
df = CSV.read("results_new/new analysis/CVAR/EOM_CVAR_cons.csv", DataFrame)

risk_levels = names(df)[2:end]
x = parse.(Float64, risk_levels)

plt = plot(size=(700,400), legend=:outertopright, xlabel="Risk aversion [β]", ylabel="CVaR [M€]", title="EOM Consumer CVAR", xflip=true, left_margin=5Plots.mm)

for agent in df.agent
    y = df[df.agent .== agent, risk_levels] |> Matrix |> vec
    plot!(plt, x, y, label=agent, marker=:circle)
end

savefig(plt, "results_new/new analysis/CVAR/EOM_CVAR_cons_plot.png")
