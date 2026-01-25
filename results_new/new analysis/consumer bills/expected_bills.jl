using CSV, DataFrames
using Statistics

function mean_bills_over_scenarios(bills_dir, folders, output_file)
    agent_set = Set{String}()
    means_dict = Dict{String, Dict{String, Float64}}()

    # Collect all agent names
    for folder in folders
        file = joinpath(bills_dir, "cfd_bills_$(folder).csv")
        if isfile(file)
            df = CSV.read(file, DataFrame)
            for agent in df.agent
                push!(agent_set, agent)
            end
        end
    end
    agents = sort(collect(agent_set))

    # Compute means
    for folder in folders
        file = joinpath(bills_dir, "cfd_bills_$(folder).csv")
        means = Dict{String, Float64}()
        if isfile(file)
            df = CSV.read(file, DataFrame)
            for row in eachrow(df)
                vals = [row[string(i)] for i in 1:9]
                means[row.agent] = mean(vals)
            end
        end
        means_dict[folder] = means
    end

    # Build output DataFrame
    out = DataFrame(agent = agents)
    for folder in folders
        col = [get(means_dict[folder], agent, missing) for agent in agents]
        out[!, folder] = col
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
bills_dir = "results_new/new analysis/consumer bills"
folders = ["cfd_1", "cfd_0.8", "cfd_0.6", "cfd_0.4", "cfd_0.2"]
output_file = joinpath(bills_dir, "cfd_bills_means.csv")
#mean_bills_over_scenarios(bills_dir, folders, output_file)



function mean_eom_bills_over_scenarios(bills_dir, folders, output_file)
    agent_set = Set{String}()
    means_dict = Dict{String, Dict{String, Float64}}()

    # Collect all agent names
    for folder in folders
        file = joinpath(bills_dir, "total_bills_EOM_$(folder).csv")
        if isfile(file)
            df = CSV.read(file, DataFrame)
            for agent in df.agent
                push!(agent_set, agent)
            end
        end
    end
    agents = sort(collect(agent_set))

    # Compute means
    for folder in folders
        file = joinpath(bills_dir, "total_bills_EOM_$(folder).csv")
        means = Dict{String, Float64}()
        if isfile(file)
            df = CSV.read(file, DataFrame)
            for row in eachrow(df)
                vals = [row[string(i)] for i in 1:9]
                means[row.agent] = mean(vals)
            end
        end
        means_dict[folder] = means
    end

    # Build output DataFrame
    out = DataFrame(agent = agents)
    for folder in folders
        col = [get(means_dict[folder], agent, missing) for agent in agents]
        out[!, folder] = col
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
bills_dir = "results_new/new analysis/consumer bills"
folders = ["1", "0.8", "0.6", "0.4", "0.2"]
output_file = joinpath(bills_dir, "mean_EOM_bills.csv")
mean_eom_bills_over_scenarios(bills_dir, folders, output_file)
