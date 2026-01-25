using CSV, DataFrames, Statistics

function mean_total_profit_per_generator(folders, base_dir, output_file)
    agent_set = Set{String}()
    means_dict = Dict{String, Dict{String, Float64}}()

    # Collect all generator names
    for folder in folders
        file = joinpath(base_dir, folder, "expressions", "Gen", "EOM_eom_generator_profit.csv")
        if isfile(file)
            df = CSV.read(file, DataFrame; delim=';')
            for agent in df.Generator
                push!(agent_set, agent)
            end
        end
    end
    agents = sort(collect(agent_set))

    # Compute means
    for folder in folders
        file = joinpath(base_dir, folder, "expressions", "Gen", "EOM_eom_generator_profit.csv")
        means = Dict{String, Float64}()
        if isfile(file)
            df = CSV.read(file, DataFrame; delim=';')
            scenario_cols = names(df)[2:end]
            for row in eachrow(df)
                vals = [row[col] for col in scenario_cols]
                means[row.Generator] = mean(vals)
            end
        end
        means_dict[folder] = means
    end

    # Build output DataFrame
    out = DataFrame(Generator = agents)
    for folder in folders
        col = [get(means_dict[folder], agent, missing) for agent in agents]
        out[!, folder] = col
    end

    CSV.write(output_file, out)
    #println("✓ Wrote $output_file")
    return out
end

# Example usage:
folders = ["EOM_1", "EOM_0.8", "EOM_0.6", "EOM_0.4", "EOM_0.2"]
base_dir = "results_new"
output_file = joinpath(base_dir, "new analysis", "generator revenues", "mean_EOM_gen_profit.csv")
#mean_total_profit_per_generator(folders, base_dir, output_file)


function add_premium_to_mean_cfd_gen(cfd_file, premium_file, output_file)
    cfd_df = CSV.read(cfd_file, DataFrame)
    premium_df = CSV.read(premium_file, DataFrame)

    # Filter only generator rows in the premium file
    premium_df = premium_df[premium_df.agent_type .== "Gen", :]

    gens = intersect(cfd_df.Generator, premium_df.agent)
    risk_levels = names(cfd_df)[2:end]

    out = DataFrame(Generator = gens)
    for col in risk_levels
        out[!, col] = [
            cfd_df[cfd_df.Generator .== gen, col][1] +
            premium_df[premium_df.agent .== gen, col][1]
            for gen in gens
        ]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
#=add_premium_to_mean_cfd_gen(
    "results_new/new analysis/generator revenues/mean_cfd_gen_profit.csv",
    "results_new/new analysis/cfd_premium_sum.csv",
    "results_new/new analysis/generator revenues/mean_cfd_gen_net_profit.csv"
)=#

function subtract_eom_from_cfd_gen(cfd_file, eom_file, output_file)
    cfd_df = CSV.read(cfd_file, DataFrame)
    eom_df = CSV.read(eom_file, DataFrame)

    agents = intersect(cfd_df.Generator, eom_df.Generator)
    columns = names(cfd_df)[2:end]  # risk levels

    out = DataFrame(Generator = agents)
    for col in columns
        out[!, col] = [eom_df[eom_df.Generator .== agent, col][1] - cfd_df[cfd_df.Generator .== agent, col][1] for agent in agents]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
subtract_eom_from_cfd_gen(
    "results_new/new analysis/generator revenues/mean_cfd_gen_net_profit.csv",
    "results_new/new analysis/generator revenues/mean_EOM_gen_profit.csv",
    "results_new/new analysis/generator revenues/total_risk_premium_gen.csv"
)