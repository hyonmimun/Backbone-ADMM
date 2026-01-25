using CSV, DataFrames

function market_cost_difference(cfd_file, eom_file, output_file)
    cfd_df = CSV.read(cfd_file, DataFrame)
    eom_df = CSV.read(eom_file, DataFrame)

    Generators = intersect(cfd_df.Generator, eom_df.Generator)
    risk_levels = names(cfd_df)[2:end]

    out = DataFrame(Generator = Generators)
    for col in risk_levels
        out[!, col] = [
            cfd_df[cfd_df.Generator .== Generator, col][1] - eom_df[eom_df.Generator .== Generator, col][1]
            for Generator in Generators
        ]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

#= Example usage:
market_cost_difference(
    "results_new/new analysis/price of risk/market_values_cfd_gen.csv",
    "results_new/new analysis/price of risk/market_values_EOM_gen.csv",
    "results_new/new analysis/price of risk/market_values_difference.csv"
) =#

function cvar_difference(cfd_file, eom_file, output_file)
    cfd_df = CSV.read(cfd_file, DataFrame)
    eom_df = CSV.read(eom_file, DataFrame)

    agents = intersect(cfd_df.agent, eom_df.agent)
    risk_levels = names(cfd_df)[2:end]

    out = DataFrame(agent = agents)
    for col in risk_levels
        out[!, col] = [
            cfd_df[cfd_df.agent .== agent, col][1] - eom_df[eom_df.agent .== agent, col][1]
            for agent in agents
        ]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

#= Example usage:
cvar_difference(
    "results_new/new analysis/price of risk/normalized_cfd_CVAR_gen.csv",
    "results_new/new analysis/price of risk/normalized_EOM_CVAR_gen.csv",
    "results_new/new analysis/price of risk/normalized_CVAR_gen_difference.csv"
)=#



function divide_market_costs_by_cvar(market_file, cvar_file, output_file)
    market_df = CSV.read(market_file, DataFrame)
    cvar_df = CSV.read(cvar_file, DataFrame)

    agents = intersect(market_df.agent, cvar_df.agent)
    risk_levels = names(market_df)[2:end]

    out = DataFrame(agent = agents)
    for col in risk_levels
        out[!, col] = [
            market_df[market_df.agent .== agent, col][1] / cvar_df[cvar_df.agent .== agent, col][1]
            for agent in agents
        ]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
divide_market_costs_by_cvar(
    "results_new/new analysis/price of risk/market_values_difference.csv",
    "results_new/new analysis/price of risk/normalized_CVAR_gen_difference.csv",
    "results_new/new analysis/price of risk/price_of_risk_generators.csv"
)