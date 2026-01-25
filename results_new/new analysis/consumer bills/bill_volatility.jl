for agent in agents
    all_bills = Float64[]
    all_labels = String[]
    all_groups = String[]
    for (i, risk) in enumerate(reverse(risk_levels))
        # EOM
        df_eom = CSV.read(files_eom[length(risk_levels) - i + 1], DataFrame)
        bills_eom = collect(df_eom[df_eom.agent .== agent, 2:end][1, :]) .* -1
        append!(all_bills, bills_eom)
        append!(all_labels, fill("β=$risk", length(bills_eom)))
        append!(all_groups, fill("EOM", length(bills_eom)))
        # CfD
        df_cfd = CSV.read(files_cfd[length(risk_levels) - i + 1], DataFrame)
        bills_cfd = collect(df_cfd[df_cfd.agent .== agent, 2:end][1, :]) .* -1
        append!(all_bills, bills_cfd)
        append!(all_labels, fill("β=$risk", length(bills_cfd)))
        append!(all_groups, fill("CfD", length(bills_cfd)))
    end
    p = groupedboxplot(
        all_labels,
        all_bills,
        group = all_groups,
        ylabel = "Consumer Bill [M€/year]",
        xlabel = "Risk Aversion [β]",
        title = "Electricity Bill Distribution",  # <-- custom title
        legend = :outertopright,
        color = [:blue :red],
        fillalpha = 0.5,
        linewidth = 1.5,
        outliers = true,
        whisker_width = 0.5,
        grid = true,
        xflip =true,
        gridstyle = :dash,
        gridalpha = 0.3,
        xrotation = 0,
        titlefontsize = 12,
        xguidefontsize = 10,
        yguidefontsize = 10,
        tickfontsize = 8,
        bottom_margin = 10Plots.mm,
        bar_width = 0.5
    )
    savefig(p, "results_new/new analysis/consumer bills/boxplot_$(agent)_bill_distribution_grouped.png")
end