using CSV, DataFrames

function collect_cfd_premiums_with_type(folders, results_dir, output_file)
    # Dict: agent => agent_type
    agent_type_dict = Dict{String, String}()
    agent_set = Set{String}()
    premiums_dict = Dict{String, Dict{String, Float64}}()

    # First pass: collect all agent names and types
    for folder in folders
        file = joinpath(results_dir, folder, "cfd_totals", "cfd_agents_results.csv")
        if isfile(file)
            df = CSV.read(file, DataFrame; delim=';')
            for row in eachrow(df)
                push!(agent_set, row.agent)
                agent_type_dict[row.agent] = row.agent_type
            end
        else
            println("⚠ File not found: $file")
        end
    end

    agents = sort(collect(agent_set))

    # Second pass: collect premiums
    for folder in folders
        file = joinpath(results_dir, folder, "cfd_totals", "cfd_agents_results.csv")
        premiums = Dict{String, Float64}()
        if isfile(file)
            df = CSV.read(file, DataFrame; delim=';')
            for row in eachrow(df)
                premiums[row.agent] = row.cfd_premium
            end
        end
        premiums_dict[folder] = premiums
    end

    # Build output DataFrame
    out = DataFrame(agent_type = [agent_type_dict[a] for a in agents], agent = agents)
    for folder in folders
        col = [get(premiums_dict[folder], agent, missing) for agent in agents]
        out[!, folder] = col
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
folders = ["cfd_1", "cfd_0.8", "cfd_0.6", "cfd_0.4", "cfd_0.2"]
results_dir = "results_new"
output_file = joinpath(results_dir, "new analysis", "consumer bills", "cfd_premium_sum.csv")
collect_cfd_premiums_with_type(folders, results_dir, output_file)