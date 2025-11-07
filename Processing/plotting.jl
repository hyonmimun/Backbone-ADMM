using CSV, DataFrames, Plots

#################################### Q_cfd plots for individual agents ##################################
# --- Load the data ---
df = CSV.read("Results_8_repr_days/cfd/cfd_totals/cfd_Q_cfd.csv", DataFrame)

# --- Identify columns ---
iteration = df[:, 1]
agent_cols = names(df)[2:end]  # everything except iteration

# --- Loop over each agent and make a plot ---
for col in agent_cols
    plt = plot(iteration, df[!, col],
               title="Values over iterations: $(col)",
               xlabel="Iteration",
               ylabel="Q_cfd",
               lw=2,
               legend=false)
    
    filename = "Plots/Q_cfd/$(col)_plot.png"
    savefig(plt, filename)
    #display(plt)
    println("✅ Saved plot for $(col) as $(filename)")
end
############################## ζ_cfd and ρ_cfd plots #############################################
premium_penalty_df = CSV.read("Results_8_repr_days/cfd/cfd_totals/cfd_penalty_premium.csv", DataFrame)

iterations = premium_penalty_df[:,1]

ζ_cfd_col = filter(col -> occursin("zeta_cfd", col), names(premium_penalty_df))
ρ_cfd_col = filter(col -> occursin("rho_cfd", col), names(premium_penalty_df))

plot_ζ = plot(title="ζ_cfd over iterations", xlabel="Iteration", ylabel="ζ_cfd", lw=2, legend=:topright)

for col in ζ_cfd_col
    plot!(plot_ζ, iterations, premium_penalty_df[!,col], label=col)
end
savefig(plot_ζ, "Plots/zeta_cfd_plot.png")

plot_ρ = plot(title="ρ_cfd over iterations", xlabel="Iteration", ylabel="ρ_cfd", lw=2, legend=:topright)

for col in ρ_cfd_col
    plot!(plot_ρ, iterations, premium_penalty_df[!,col], label=col)
end
savefig(plot_ρ,"Plots/rho_cfd_plot.png")

println("plots for ζ_cfd and ρ_cfd saved")

############################## Q_cfd plots for agent types ##########################################
iterations = df[:, 1]
all_cols = names(df)[2:end]

# Consumers are named TypeA, TypeB, TypeC
consumer_cols = ["TypeA", "TypeB", "TypeC"]

# Everything else is a generator
generator_cols = setdiff(all_cols, consumer_cols)

# --- Plot generators ---
plt_gen = plot(title="Generators over iterations",
               xlabel="Iteration",
               ylabel="Q_cfd",
               lw=2,
               legend=:topright)

for col in generator_cols
    plot!(plt_gen, iterations, df[!, col], label=col)
end

savefig(plt_gen, "Plots/Q_cfd_generators_plot.png")
#display(plt_gen)
println("✅ Saved generator plot as generators_plot.png")

# --- Plot consumers ---
plt_con = plot(title="Consumers over iterations",
               xlabel="Iteration",
               ylabel="Q_cfd",
               lw=2,
               legend=:topright)

for col in consumer_cols
    plot!(plt_con, iterations, df[!, col], label=col)
end

savefig(plt_con, "Plots/Q_cfd_consumers_plot.png")
#display(plt_con)
println("✅ Saved consumer plot as consumers_plot.png") 
################################### Q_cfd_bar plots ###########################################
Q_cfd_bar_df = CSV.read("Results_8_repr_days/cfd/cfd_totals/cfd_Q_cfd_bar.csv", DataFrame)

iterations = Q_cfd_bar_df[:,1]
#agents = names(Q_cfd_bar_df)[2:end]

consumer_cols = ["TypeA", "TypeB", "TypeC"]
res_gen_cols = ["WindOnshore", "WindOffshore", "SolarPanels"]
conventional_gen = ["Baseload", "GasTurbine", "Peak"]

# Consumer plot
plt_con = plot(title="Consumer Q_cfd_bar",
               xlabel="Iteration",
               ylabel="Q_cfd_bar",
               lw=2,
               legend=:topright)

for col in consumer_cols
    plot!(plt_con, iterations, Q_cfd_bar_df[!, col], label=col)
end
savefig(plt_con, "Plots/Q_cfd_bar_consumers_plot.png")

# RES gen plot
plt_res = plot(title="RES Q_cfd_bar",xlabel="Iteration",ylabel="Q_cfd_bar",lw=2,legend=:topright)

for col in res_gen_cols
    plot!(plt_res, iterations, Q_cfd_bar_df[!, col], label=col)
end
savefig(plt_res, "Plots/Q_cfd_bar_res_plot.png")

# Conventional gen plot
plt_conv = plot(title="Conventional Gen Q_cfd_bar",xlabel="Iteration",ylabel="Q_cfd_bar",lw=2,legend=:topright)
for col in conventional_gen
    plot!(plt_conv, iterations, Q_cfd_bar_df[!, col], label=col)
end
savefig(plt_conv, "Plots/Q_cfd_bar_conventional_gen_plot.png")