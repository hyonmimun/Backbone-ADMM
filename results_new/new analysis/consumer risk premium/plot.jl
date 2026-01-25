using CSV, DataFrames, Plots

# Read the data
df = CSV.read("results_new/new analysis/consumer risk premium/total_risk_premium.csv", DataFrame)

risk_levels = names(df)[2:end]
x = parse.(Float64, risk_levels)

plt = plot(size=(600,400), legend=:outertopright, xlabel="Risk aversion [β]", ylabel="Risk premium (CfD-EOM) [M€]", title="Risk Premium Consumers", xflip=true)
#################### multiply with -1 #########################
for agent in df.agent
    y = (df[df.agent .== agent, risk_levels] |> Matrix |> vec) .* -1
    plot!(plt, x, y, label=agent, marker=:circle)
end

hline!(plt, [0], color=:black, linestyle=:dash, label="")
savefig(plt, "results_new/new analysis/consumer risk premium/risk_premium_cons.png")