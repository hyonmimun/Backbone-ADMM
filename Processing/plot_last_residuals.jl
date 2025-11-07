

df = CSV.read("Results_8_repr_days/cfd/ADMM_iteration_history.csv", DataFrame; delim=';')



n = nrow(df)
start_row = max(1, n - 100 + 1)
sub = df[start_row:end, [:iteration, :primal_cfd, :dual_cfd]]

p = plot(sub.iteration, sub.primal_cfd,
    label = "CfD Primal residual",
    linewidth=2, color = :blue)
plot!(sub.iteration, sub.dual_cfd,
    label = "CfD Dual residual",
    linewidth=2, color = :orange)
xlabel!("Iteration")
ylabel!("Residual")
title!("CfD residuals (last $(n - start_row + 1) iterations)")

out_png = "Results_8_repr_days/cfd/cfd_residuals_last500.png"
savefig(p, out_png)
println("Saved plot to: ", out_png)