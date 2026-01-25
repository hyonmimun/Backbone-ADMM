using CSV, DataFrames

function calculate_market_costs(bill_file, gen_file, output_file)
    bill_df = CSV.read(bill_file, DataFrame)
    gen_df = CSV.read(gen_file, DataFrame)

    agents = intersect(bill_df.agent, gen_df.agent)
    risk_levels = names(bill_df)[2:end]

    out = DataFrame(agent = agents)
    for col in risk_levels
        out[!, col] = [
            bill_df[bill_df.agent .== agent, col][1] / gen_df[gen_df.agent .== agent, col][1]
            for agent in agents
        ]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

#= Calculate for CfD
calculate_market_costs(
    "results_new/new analysis/consumer bills/mean_cfd_bills.csv",
    "results_new/new analysis/expected generation/mean_cfd_cons_generation.csv",
    "results_new/new analysis/consumer bills/market_costs_cfd.csv"
)=#

#= Calculate for EOM
calculate_market_costs(
    "results_new/new analysis/consumer bills/mean_EOM_bills.csv",
    "results_new/new analysis/expected generation/mean_EOM_cons_generation.csv",
    "results_new/new analysis/consumer bills/market_costs_EOM.csv"
)=#



function calculate_generator_market_costs(bill_file, gen_file, output_file; bill_col="Generator", gen_col="agent")
    bill_df = CSV.read(bill_file, DataFrame)
    gen_df = CSV.read(gen_file, DataFrame)

    # Use the correct column for generator name
    generators = intersect(bill_df[!, bill_col], gen_df[!, gen_col])
    risk_levels = names(bill_df)[2:end]

    out = DataFrame(Generator = generators)
    for col in risk_levels
        out[!, col] = [
            bill_df[bill_df[!, bill_col] .== gen, col][1] / gen_df[gen_df[!, gen_col] .== gen, col][1]
            for gen in generators
        ]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Calculate for CfD
calculate_generator_market_costs(
    "results_new/new analysis/generator revenues/mean_cfd_gen_net_profit.csv",
    "results_new/new analysis/expected generation/mean_cfd_generation.csv",
    "results_new/new analysis/generator revenues/market_costs_cfd_gen.csv",
    bill_col="Generator", gen_col="agent"
)

# Calculate for EOM
calculate_generator_market_costs(
    "results_new/new analysis/generator revenues/mean_EOM_gen_profit.csv",
    "results_new/new analysis/expected generation/mean_EOM_generation.csv",
    "results_new/new analysis/generator revenues/market_costs_EOM_gen.csv",
    bill_col="Generator", gen_col="agent"
)