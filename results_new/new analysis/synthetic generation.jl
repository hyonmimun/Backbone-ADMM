using CSV, DataFrames, Dates, LinearAlgebra
using Glob

function create_synthetic_generation_timeseries_all(;
    folder::String = "cfd_0.2",
    market_design::String = "cfd",  # or "EOM"
    years::Vector{String} = ["2018", "2021", "2022"],
    n_repr_days::Int = 8,
    n_scenarios::Int = 9
)
    println("Using folder: $folder")
    println("Market design: $market_design")

    # Map scenario years to calendar years
    year_mapping = Dict(
        1 => years[1], 2 => years[1], 3 => years[1],
        4 => years[2], 5 => years[2], 6 => years[2],
        7 => years[3], 8 => years[3], 9 => years[3]
    )

    # Load all ordering variable files once
    weights_dict = Dict{String, Matrix{Float64}}()
    for year in years
        weights_path = "Input/output_$(year)_base/ordering_variable.csv"
        weights_df = CSV.read(weights_path, DataFrame, delim=",", header=1)
        weights_dict[year] = Matrix{Float64}(weights_df)
    end

    # Find all agent names for Gen and Cons
    gen_dir = "results_new/$(folder)/generation/Gen"
    cons_dir = "results_new/$(folder)/generation/Cons"
    generators = filter(isdir, Glob.glob("*", gen_dir)) |> x -> map(basename, x)
    consumers  = filter(isdir, Glob.glob("*", cons_dir)) |> x -> map(basename, x)

    for (agent_type, agent_list) in [("Gen", generators), ("Cons", consumers)]
        for agent_name in agent_list
            println("Processing $agent_type/$agent_name ...")
            for scenario_idx in 1:n_scenarios
                year = year_mapping[scenario_idx]
                weights_mat = weights_dict[year]

                file_prefix = market_design == "EOM" ? "EOM_generation" : "cfd_generation"
                gen_path = "results_new/$(folder)/generation/$(agent_type)/$(agent_name)/$(file_prefix)_$(agent_name)_year$(scenario_idx).csv"
                if !isfile(gen_path)
                    println("⚠ Generation file not found: $gen_path")
                    continue
                end

                gen_df = CSV.read(gen_path, DataFrame; delim=';')
                gen_mat = Matrix{Float64}(gen_df)

                @assert size(gen_mat, 2) == n_repr_days "Expected $n_repr_days representative days, got $(size(gen_mat, 2))"
                @assert size(gen_mat, 1) == 24 "Expected 24 hours, got $(size(gen_mat, 1))"

                year_24x365 = gen_mat * permutedims(weights_mat)
                @assert size(year_24x365) == (24, 365) "Expected (24, 365), got $(size(year_24x365))"

                year_hours_8760 = vec(year_24x365)

                t_start = DateTime(parse(Int, year), 1, 1, 0, 0, 0)
                t_end = DateTime(parse(Int, year), 12, 31, 23, 0, 0)
                timestamps = collect(t_start:Hour(1):t_end)

                @assert length(timestamps) == 8760 "Expected 8760 timestamps, got $(length(timestamps))"
                @assert length(year_hours_8760) == 8760 "Expected 8760 data points, got $(length(year_hours_8760))"

                out_df = DataFrame(timestamp = timestamps, generation = year_hours_8760)
                output_dir = "results_new/$(folder)/generation/$(agent_type)/$(agent_name)/synthesized_timeseries"
                mkpath(output_dir)
                out_path = joinpath(output_dir, "synthetic_$(file_prefix)_$(agent_name)_$(scenario_idx)_$(year).csv")
                CSV.write(out_path, out_df, delim=";")
                println("✓ Created synthetic generation timeseries: $(basename(out_path))")
            end
        end
    end
    println("Synthetic generation timeseries creation complete for all agents!")
end

# Example usage:
create_synthetic_generation_timeseries_all(folder="EOM_1", market_design="EOM")