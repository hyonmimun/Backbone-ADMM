using CSV, DataFrames

function combine_cvar_files(folders, base_dir, output_file)
    agent_names = String[]
    cvar_dict = Dict{String, Dict{String, Float64}}()

    # Read all CVAR files and collect agent names
    for folder in folders
        file = joinpath(base_dir, folder, "expressions", "Cons", "EOM,CVAR_cons.csv")
        if !isfile(file)
            println("⚠ File not found: $file")
            continue
        end
        df = CSV.read(file, DataFrame)
        # The column names are like CVAR_TypeA, CVAR_TypeB, ...
        for col in names(df)
            agent = split(col, "_")[end]
            if !(agent in agent_names)
                push!(agent_names, agent)
            end
        end
        # Store values for this folder
        cvar_dict[folder] = Dict{String, Float64}()
        for col in names(df)
            agent = split(col, "_")[end]
            cvar_dict[folder][agent] = df[1, col]
        end
    end

    agent_names = sort(agent_names)
    out = DataFrame(agent = agent_names)
    for folder in folders
        col = [get(cvar_dict[folder], agent, missing) for agent in agent_names]
        out[!, folder] = col
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
folders = ["EOM_1", "EOM_0.8", "EOM_0.6", "EOM_0.4", "EOM_0.2"]
base_dir = "results_new"
output_file = joinpath(base_dir, "new analysis", "CVAR", "EOM_CVAR_cons.csv")
#combine_cvar_files(folders, base_dir, output_file)


function subtract_cfd_cvar_from_eom(eom_file, cfd_file, output_file)
    eom_df = CSV.read(eom_file, DataFrame)
    cfd_df = CSV.read(cfd_file, DataFrame)

    agents = intersect(eom_df.agent, cfd_df.agent)
    columns = names(eom_df)[2:end]  # risk levels

    out = DataFrame(agent = agents)
    for col in columns
        out[!, col] = [cfd_df[cfd_df.agent .== agent, col][1] - eom_df[eom_df.agent .== agent, col][1] for agent in agents]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
subtract_cfd_cvar_from_eom(
    "results_new/new analysis/CVAR/EOM_CVAR_gen.csv",
    "results_new/new analysis/CVAR/cfd_CVAR_gen.csv",
    "results_new/new analysis/CVAR/CVAR_change_gen.csv"
)