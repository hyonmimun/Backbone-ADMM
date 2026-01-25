

df = CSV.read("Results/CfD_risk_0.2_strike_0.07/ADMM_iteration_history.csv", DataFrame; delim=';')



n = nrow(df)
start_row = max(1, n - 600 +1)
sub = df[start_row:end, [:iteration,:primal_EOM,:dual_EOM, :primal_cfd, :dual_cfd]]

p = plot(sub.iteration, sub.primal_EOM,
    label = "EOM Primal residual [GWh]",
    linewidth=2, color = :red)

    plot!(sub.iteration, sub.dual_EOM,
    label = "EOM Dual residual [GWh]",
    linewidth=2, color = :red, linestyle=:dot)

    plot!(sub.iteration, sub.primal_cfd,
    label = "CfD Primal residual [GW]",
    linewidth=2, color = :green)

    plot!(sub.iteration, sub.dual_cfd,
    label = "CfD Dual residual [GW]",
    linewidth=2, color = :green, linestyle=:dot)

xlabel!("Iteration")
ylabel!("Residuals")
title!("CfD residuals (last $(n - start_row + 1) iterations)", titlefontsize=10,guidefontsize=9)

out_png = "Results/CfD_risk_0.2_strike_0.07/cfd_residuals_last.png"
savefig(p, out_png)
println("Saved plot to: ", out_png)