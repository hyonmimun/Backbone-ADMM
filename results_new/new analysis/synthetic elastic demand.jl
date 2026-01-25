using CSV, DataFrames, Dates, LinearAlgebra
using Glob

function create_synthetic_elastic_demand_timeseries_all(;
    folder::String = "EOM_0.2",
    market_design::String = "EOM",  # or "cfd"
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

    # Find all consumer types in D_ELA folder
    ela_dir = "results_new/$(folder)/D_ELA"
    consumers = filter(isdir, Glob.glob("*", ela_dir)) |> x -> map(basename, x)

    # Set file prefix based on market design
    file_prefix = market_design == "EOM" ? "EOM_elastic_demand" : "cfd_elastic_demand"

    for cons in consumers
        println("Processing elastic demand for $cons ...")
        for scenario_idx in 1:n_scenarios
            year = year_mapping[scenario_idx]
            weights_mat = weights_dict[year]

            ela_path = "results_new/$(folder)/D_ELA/$(cons)/$(file_prefix)_$(cons)_year$(scenario_idx).csv"
            if !isfile(ela_path)
                println("⚠ Elastic demand file not found: $ela_path")
                continue
            end

            ela_df = CSV.read(ela_path, DataFrame; delim=';')
            ela_mat = Matrix{Float64}(ela_df)

            @assert size(ela_mat, 2) == n_repr_days "Expected $n_repr_days representative days, got $(size(ela_mat, 2))"
            @assert size(ela_mat, 1) == 24 "Expected 24 hours, got $(size(ela_mat, 1))"

            year_24x365 = ela_mat * permutedims(weights_mat)
            @assert size(year_24x365) == (24, 365) "Expected (24, 365), got $(size(year_24x365))"

            year_hours_8760 = vec(year_24x365)

            t_start = DateTime(parse(Int, year), 1, 1, 0, 0, 0)
            t_end = DateTime(parse(Int, year), 12, 31, 23, 0, 0)
            timestamps = collect(t_start:Hour(1):t_end)

            @assert length(timestamps) == 8760 "Expected 8760 timestamps, got $(length(timestamps))"
            @assert length(year_hours_8760) == 8760 "Expected 8760 data points, got $(length(year_hours_8760))"

            out_df = DataFrame(timestamp = timestamps, elastic_demand = year_hours_8760)
            output_dir = "results_new/$(folder)/D_ELA/$(cons)/synthesized_timeseries"
            mkpath(output_dir)
            out_path = joinpath(output_dir, "synthetic_$(file_prefix)_$(cons)_$(scenario_idx)_$(year).csv")
            CSV.write(out_path, out_df, delim=";")
            println("✓ Created synthetic elastic demand timeseries: $(basename(out_path))")
        end
    end
    println("Synthetic elastic demand timeseries creation complete for all consumers!")
end

# Example usage for EOM:
create_synthetic_elastic_demand_timeseries_all(folder="EOM_1", market_design="EOM")
