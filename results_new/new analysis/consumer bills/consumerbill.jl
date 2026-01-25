using CSV, DataFrames, Glob

function multiply_price_and_generation(; 
    folder::String = "cfd_0.2",
    n_scenarios::Int = 9
)
    # Find all consumer agents
    cons_dir = "results_new/$(folder)/generation/Cons"
    agents = filter(isdir, Glob.glob("*", cons_dir)) |> x -> map(basename, x)

    for agent in agents
        gen_dir = joinpath(cons_dir, agent, "synthesized_timeseries")
        for scenario_idx in 1:n_scenarios
            year = scenario_idx <= 3 ? "2018" : scenario_idx <= 6 ? "2021" : "2022"
            gen_file = joinpath(gen_dir, "synthetic_EOM_generation_$(agent)_$(scenario_idx)_$(year).csv")
            price_file = "results_new/$(folder)/electricity_price/synthesized_timeseries/synthetic_EOM_electricity_price_$(scenario_idx)_$(year).csv"
            out_file = joinpath("results_new","new analysis","consumer bills", "bills_$(folder)_$(agent)_$(scenario_idx)_$(year).csv")

            if !(isfile(gen_file) && isfile(price_file))
                println("⚠ Missing file for $agent scenario $scenario_idx")
                continue
            end

            gen_df = CSV.read(gen_file, DataFrame)
            price_df = CSV.read(price_file, DataFrame)

            @assert nrow(gen_df) == nrow(price_df)
            value = gen_df.generation .* price_df.price

            out_df = DataFrame(timestamp = gen_df.timestamp, value = value)
            CSV.write(out_file, out_df, delim=";")
            println("✓ Wrote $out_file")
        end
    end
end

# Example usage:
multiply_price_and_generation(folder="EOM_0.2")