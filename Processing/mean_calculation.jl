using CSV
using DataFrames
using Statistics

function mean_generation_across_all()
    # Resolve the folder relative to this script
    dir = normpath(joinpath(@__DIR__, "..", "Results", "CfD_risk_1_strike_0.07", "generation", "Cons", "TypeD", "synthesized timeseries"))
    isdir(dir) || error("Directory not found: $dir")

    files = sort(filter(f -> endswith(lowercase(f), ".csv"), readdir(dir; join=true)))
    @assert length(files) == 9 "Expected 9 CSV files in: $dir (got $(length(files)))"

    total_sum = 0.0
    total_count = 0

    for f in files
        df = CSV.read(f, DataFrame; delim=';')
        col = df.generation
        total_sum += sum(skipmissing(col))
        total_count += count(!ismissing, col)
    end

    overall_mean = total_sum / total_count
    println("Overall mean generation across all 9 files: ", overall_mean)
    return overall_mean
end

# Run when executed as a script
if abspath(PROGRAM_FILE) == @__FILE__
    mean_generation_across_all()
end

#mean_generation_across_all()

######## mean electricity prices

println("\n" * "="^80)
println("Calculating Mean Elastic Demand Across All Scenarios")
println("="^80)

# Directory with the 9 price files
price_dir = joinpath("Results", "CfD_risk_1_strike_0.07", "D_ELA","TypeD", "synthesized timeseries")

# Collect CSV files
files = sort(filter(f -> endswith(lowercase(f), ".csv"), readdir(price_dir; join=true)))
@assert length(files) == 9 "Expected 9 CSV files in: $price_dir (got $(length(files)))"

# Initialize array to store all price series
all_prices = []

# Read all files
for (idx, f) in enumerate(files)
    df = CSV.read(f, DataFrame; delim=';')
    
    # Get price column (second column after timestamp)
    price_col = names(df)[2]
    prices = df[!, price_col]
    
    push!(all_prices, prices)
    
    println("✓ Loaded Scenario $idx: $(basename(f)) ($(length(prices)) hours)")
end

# Verify all files have the same length
n_hours = length(all_prices[1])
@assert all(length(p) == n_hours for p in all_prices) "All scenarios must have the same number of hours"

println("\nTotal scenarios: $(length(all_prices))")
println("Hours per scenario: $n_hours")

# Calculate mean per timestep
mean_prices = zeros(n_hours)

for hour in 1:n_hours
    # Get prices for this hour across all scenarios
    hour_prices = [all_prices[scenario][hour] for scenario in 1:9]
    mean_prices[hour] = mean(hour_prices)
end

# Get timestamps from the first file
first_df = CSV.read(files[1], DataFrame; delim=';')
timestamps = first_df[!, 1]  # First column is timestamp

# Create output DataFrame
output_df = DataFrame(
    timestamp = timestamps,
    mean_D_ela = mean_prices
)

# Save to CSV
output_path = joinpath(price_dir, "mean_D_ELA_all_scenarios.csv")
CSV.write(output_path, output_df, delim=';')

println("\n" * "="^80)
println("Mean Electricity Price Statistics")
println("="^80)
println("Min mean price: $(round(minimum(mean_prices), digits=5)) M€/GWh")
println("Max mean price: $(round(maximum(mean_prices), digits=5)) M€/GWh")
println("Overall mean: $(round(mean(mean_prices), digits=5)) M€/GWh")
println("Median: $(round(median(mean_prices), digits=5)) M€/GWh")
println("Std dev: $(round(std(mean_prices), digits=5)) M€/GWh")

println("\n✓ Mean prices saved to: $output_path")
println("="^80)