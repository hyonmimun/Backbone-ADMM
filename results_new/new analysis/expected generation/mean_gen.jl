using CSV, DataFrames

function mean_generation_over_scenarios(files::Vector{String}, risk_levels::Vector{String}, output_file::String)
    agent_set = Set{String}()
    means_dict = Dict{String, Dict{String, Float64}}()

    # Collect all agent names
    for file in files
        df = CSV.read(file, DataFrame)
        for agent in df.agent
            push!(agent_set, agent)
        end
    end
    agents = sort(collect(agent_set))

    # Compute means for each file (risk level)
    for (i, file) in enumerate(files)
        df = CSV.read(file, DataFrame)
        scenario_cols = names(df)[2:end]  # skip 'agent'
        means = Dict{String, Float64}()
        for row in eachrow(df)
            vals = [row[col] for col in scenario_cols]
            means[row.agent] = mean(vals)
        end
        means_dict[risk_levels[i]] = means
    end

    # Build output DataFrame
    out = DataFrame(agent = agents)
    for risk in risk_levels
        col = [get(means_dict[risk], agent, missing) for agent in agents]
        out[!, risk] = col
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
files = [
    "results_new/new analysis/expected generation/consumer/cfd_1_cons_generation_totals.csv",

    "results_new/new analysis/expected generation/consumer/cfd_0.8_cons_generation_totals.csv",

    "results_new/new analysis/expected generation/consumer/cfd_0.6_cons_generation_totals.csv",

    "results_new/new analysis/expected generation/consumer/cfd_0.4_cons_generation_totals.csv",
    "results_new/new analysis/expected generation/consumer/cfd_0.2_cons_generation_totals.csv"
]
risk_levels = ["1", "0.8", "0.6", "0.4", "0.2"]
output_file = "results_new/new analysis/expected generation/mean_cfd_cons_by_risk.csv"
mean_generation_over_scenarios(files, risk_levels, output_file)