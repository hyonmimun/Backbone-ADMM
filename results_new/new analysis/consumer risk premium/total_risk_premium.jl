using CSV, DataFrames

function subtract_eom_from_cfd(eom_file, cfd_file, output_file)
    eom_df = CSV.read(eom_file, DataFrame)
    cfd_df = CSV.read(cfd_file, DataFrame)

    # Ensure agents are matched by name
    agents = intersect(eom_df.agent, cfd_df.agent)
    columns = names(eom_df)[2:end]  # risk-aversion levels

    out = DataFrame(agent = agents)
    for col in columns
        out[!, col] = [cfd_df[cfd_df.agent .== agent, col][1] - eom_df[eom_df.agent .== agent, col][1] for agent in agents]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
subtract_eom_from_cfd(
    "results_new/new analysis/consumer bills/mean_EOM_bills.csv",
    "results_new/new analysis/consumer bills/mean_cfd_bills.csv",
    "results_new/new analysis/consumer bills/total_risk_premium.csv"
)