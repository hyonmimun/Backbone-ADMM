using CSV, DataFrames

function scenario_market_values(revenue_file, generation_file, output_file)
    rev_df = CSV.read(revenue_file, DataFrame; delim=';')
    gen_df = CSV.read(generation_file, DataFrame; delim=',')

    generators = intersect(rev_df.Generator, gen_df.Generator)
    scenario_cols = names(rev_df)[2:end]

    out = DataFrame(Generator = generators)
    for col in scenario_cols
        out[!, col] = [
            rev_df[rev_df.Generator .== gen, col][1] / gen_df[gen_df.Generator .== gen, col][1]
            for gen in generators
        ]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

#= Example usage:
scenario_market_values(
    "results_new/EOM_1/expressions/Gen/EOM_eom_generator_revenue.csv",
    "results_new/new analysis/expected generation/generator/EOM_1_generation_totals.csv", # replace with your generation file path
    "results_new/new analysis/market values/EOM_generator_market_value.csv"
) =#

using CSV, DataFrames, Statistics

# Read the data
df = CSV.read("results_new/new analysis/market values/EOM_generator_market_value.csv", DataFrame)

scenario_cols = names(df)[2:end]

out = DataFrame(
    Generator = df.Generator,
    mean = [mean(row) for row in eachrow(df[:, scenario_cols])],
    min = [minimum(row) for row in eachrow(df[:, scenario_cols])],
    max = [maximum(row) for row in eachrow(df[:, scenario_cols])],
    std = [std(row) for row in eachrow(df[:, scenario_cols])]
)

CSV.write("results_new/new analysis/market values/EOM_generator_market_value_stats.csv", out)
println("✓ Wrote EOM_generator_market_value_stats.csv")