using CSV, DataFrames, Dates, LinearAlgebra

function create_synthetic_price_timeseries(;
    folder::String = "cfd_0.2",
    market_design::String = ["EOM" or "cfd"],
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

    for scenario_idx in 1:n_scenarios
        year = year_mapping[scenario_idx]
        weights_mat = weights_dict[year]

        # Set file prefix based on market design
        file_prefix = market_design == "EOM" ? "EOM_electricity_price" : "cfd_electricity_price"

        # Path to the price file for this scenario (now uses folder and market_design)
        price_path = "results_new/$(folder)/electricity_price/$(file_prefix)_year_$(scenario_idx).csv"
        if !isfile(price_path)
            println("⚠ Price file not found: $price_path")
            continue
        end

        # Load representative day price matrix (24 x 8)
        price_df = CSV.read(price_path, DataFrame; delim=';')
        price_mat = Matrix{Float64}(price_df)

        @assert size(price_mat, 2) == n_repr_days "Expected $n_repr_days representative days, got $(size(price_mat, 2))"
        @assert size(price_mat, 1) == 24 "Expected 24 hours, got $(size(price_mat, 1))"

        # Create full year timeseries: (24 x 8) * (8 x 365)' = (24 x 365)
        year_24x365 = price_mat * permutedims(weights_mat)
        @assert size(year_24x365) == (24, 365) "Expected (24, 365), got $(size(year_24x365))"

        # Reshape to 8760 hours
        year_hours_8760 = vec(year_24x365)

        # Create timestamps for the calendar year
        t_start = DateTime(parse(Int, year), 1, 1, 0, 0, 0)
        t_end = DateTime(parse(Int, year), 12, 31, 23, 0, 0)
        timestamps = collect(t_start:Hour(1):t_end)

        @assert length(timestamps) == 8760 "Expected 8760 timestamps, got $(length(timestamps))"
        @assert length(year_hours_8760) == 8760 "Expected 8760 data points, got $(length(year_hours_8760))"

        # Create output dataframe
        out_df = DataFrame(timestamp = timestamps, price = year_hours_8760)

        # Save results (now uses folder and market_design)
        output_dir = "results_new/$(folder)/electricity_price/synthesized_timeseries"
        mkpath(output_dir)
        out_path = joinpath(output_dir, "synthetic_$(file_prefix)_$(scenario_idx)_$(year).csv")
        CSV.write(out_path, out_df, delim=";")
        println("✓ Created synthetic price timeseries: $(basename(out_path))")
    end
    println("Synthetic electricity price timeseries creation complete!")
end

# Example usage:
#create_synthetic_price_timeseries(folder="EOM_0.2", market_design="EOM")
#create_synthetic_price_timeseries(folder="cfd_0.2", market_design="cfd")