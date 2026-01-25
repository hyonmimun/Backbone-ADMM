using CSV, DataFrames

function add_premium_to_bills(premium_file, bills_dir, folders)
    # Read the premium summary
    premium_df = CSV.read(premium_file, DataFrame)
    # For each folder (e.g., cfd_1, cfd_0.8, ...)
    for folder in folders
        bills_file = joinpath(bills_dir, "cfd_bills_$(folder).csv")
        if !isfile(bills_file)
            println("⚠ Bills file not found: $bills_file")
            continue
        end
        bills_df = CSV.read(bills_file, DataFrame)
        # Find the premium column for this folder
        if !(folder in names(premium_df))
            println("⚠ Premium column not found for $folder")
            continue
        end
        # Add premium to each scenario value for each agent
        for row in 1:nrow(bills_df)
            agent = bills_df.agent[row]
            premium_row = findfirst(premium_df.agent .== agent)
            if isnothing(premium_row)
                println("⚠ Agent $agent not found in premium file")
                continue
            end
            premium = premium_df[premium_row, folder]
            for scenario in 1:9
                bills_df[row, string(scenario)] += premium
            end
        end

        # Write the updated bills file (overwrite or change name as needed)
        CSV.write(bills_file, bills_df)
        println("✓ Updated $bills_file")
    end
end

# Example usage:
premium_file = "results_new/new analysis/consumer bills/cfd_premium_sum.csv"
bills_dir = "results_new/new analysis/consumer bills"
folders = ["cfd_1", "cfd_0.8", "cfd_0.6", "cfd_0.4", "cfd_0.2"]
add_premium_to_bills(premium_file, bills_dir, folders)