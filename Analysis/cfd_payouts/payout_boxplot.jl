#= using CSV
using DataFrames
using Plots
using StatsPlots
using Statistics

println("\n" * "="^80)
println("Creating CfD Payout Boxplots for All Consumer Types")
println("="^80)

# Configuration
risk_level = "0.2"
strike_price = "0.07"

# Read the CfD payout data
data_path = joinpath("Results", "CfD_risk_$(risk_level)_strike_$(strike_price)", 
                     "expressions", "Cons", "cfd_payout_cons.csv")
df = CSV.read(data_path, DataFrame; delim=';')

println("Loaded CfD payout data from: $data_path")
println("Columns: ", names(df))
println("Consumers: ", df.Consumer)

# Color mapping for each consumer
colors_map = Dict("TypeC" => :green, "TypeA" => :blue, "TypeD" => :purple, "TypeB" => :red)

# Create the initial plot
p = plot(
    size = (1000, 700),
    ylabel = "CfD Payout (M€)",
    xlabel = "Consumer Type",
    title = "CfD Payout Distribution for Consumers for β = 0.2",
    legend = false,
    titlefontsize = 14,
    xguidefontsize = 12,
    yguidefontsize = 12,
    tickfontsize = 11,
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3,
    left_margin = 5Plots.mm,
    right_margin = 5Plots.mm,
    bottom_margin = 5Plots.mm,
    top_margin = 5Plots.mm
)

# Add boxplot for each consumer
for (idx, row) in enumerate(eachrow(df))
    consumer = row.Consumer
    
    # Extract the 9 scenario values (columns 2 through 10)
    payouts = collect(row[2:end])
    
    println("\n$consumer:")
    println("  Payouts: $payouts")
    println("  Mean: $(round(mean(payouts), digits=2)) M€")
    println("  Median: $(round(median(payouts), digits=2)) M€")
    println("  Min: $(round(minimum(payouts), digits=2)) M€")
    println("  Max: $(round(maximum(payouts), digits=2)) M€")
    
    # Add boxplot for this consumer
    boxplot!(
        p,
        [consumer],
        [payouts],
        fillalpha = 0.75,
        linewidth = 2,
        fillcolor = colors_map[consumer],
        label = false
    )
end

# Display the plot
display(p)

# Save the plot
output_dir = joinpath("Results", "Analysis", "plots")
mkpath(output_dir)
output_file = joinpath(output_dir, "CfD_payout_boxplots_all_consumers.png")
savefig(p, output_file)

println("\n" * "="^80)
println("CfD payout boxplot saved to: $output_file")
println("="^80) 

=#
#=
using CSV
using DataFrames
using Plots
using Statistics

println("\n" * "="^80)
println("Creating CfD Payout Histogram for All Consumer Types")
println("="^80)

# Configuration
risk_level = "0.2"
strike_price = "0.07"

# Read the CfD payout data
data_path = joinpath("Results", "CfD_risk_$(risk_level)_strike_$(strike_price)", 
                     "expressions", "Cons", "cfd_payout_cons.csv")
df = CSV.read(data_path, DataFrame; delim=';')

println("Loaded CfD payout data from: $data_path")

# Calculate average payout for each consumer across all 9 scenarios
consumer_types = df.Consumer
avg_payouts = Float64[]

for row in eachrow(df)
    consumer = row.Consumer
    
    # Extract the 9 scenario values (columns 2 through 10)
    payouts = collect(row[2:end])
    avg_payout = mean(payouts)
    
    push!(avg_payouts, avg_payout)
    
    println("\n$consumer:")
    println("  Average payout: $(round(avg_payout, digits=4)) M€")
end

# Color mapping for each consumer
colors_map = Dict("TypeC" => :green, "TypeA" => :blue, "TypeD" => :purple, "TypeB" => :red)
bar_colors = [colors_map[c] for c in consumer_types]

# Create bar chart (histogram)
p = bar(
    consumer_types,
    avg_payouts,
    fillalpha = 0.75,
    linewidth = 2,
    fillcolor = bar_colors,
    ylabel = "Average CfD Payout (M€)",
    xlabel = "Consumer Type",
    title = "Average CfD Payout - All Consumer Types (Across 9 Scenarios)",
    legend = false,
    size = (1000, 700),
    titlefontsize = 14,
    xguidefontsize = 12,
    yguidefontsize = 12,
    tickfontsize = 11,
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3,
    left_margin = 5Plots.mm,
    right_margin = 5Plots.mm,
    bottom_margin = 5Plots.mm,
    top_margin = 5Plots.mm
)

# Add value labels on top of bars
for (i, (consumer, value)) in enumerate(zip(consumer_types, avg_payouts))
    annotate!(i, value, text("$(round(value, digits=2))", :center, 10))
end

# Display the plot
display(p)

# Save the plot
output_dir = joinpath("Results", "Analysis", "plots")
mkpath(output_dir)
output_file = joinpath(output_dir, "CfD_payout_average_histogram.png")
savefig(p, output_file)

println("\n" * "="^80)
println("CfD payout histogram saved to: $output_file")
println("="^80)

=#
using CSV
using DataFrames
using Plots
using Statistics

println("\n" * "="^80)
println("Creating Combined CfD Payout Bar Chart for All Risk Levels")
println("="^80)

# Configuration
risk_levels = ["0.2", "0.4", "0.6", "0.8", "1"]
data_dir = joinpath("Analysis", "cfd_payouts")

# Dictionary to store results
results = Dict{String, Dict{String, Float64}}()

# Process each risk level
for risk_level in risk_levels
    println("\nProcessing β = $risk_level")
    
    # Read the data
    data_path = joinpath(data_dir, "cfd_payout_cons_$(risk_level).csv")
    df = CSV.read(data_path, DataFrame; delim=';')
    
    # Calculate average payout for each consumer
    for row in eachrow(df)
        consumer = row.Consumer
        payouts = collect(row[2:end])
        avg_payout = mean(payouts)
        
        # Store result
        if !haskey(results, consumer)
            results[consumer] = Dict{String, Float64}()
        end
        results[consumer][risk_level] = avg_payout
        
        println("  $consumer: $(round(avg_payout, digits=4)) M€")
    end
end

# Prepare data for grouped bar chart
consumer_types = sort(collect(keys(results)))  # ["TypeA", "TypeB", "TypeC", "TypeD"]
risk_labels = ["β=$r" for r in risk_levels]

# Create matrix: rows = risk levels, columns = consumers
data_matrix = zeros(length(risk_levels), length(consumer_types))

for (i, risk) in enumerate(risk_levels)
    for (j, consumer) in enumerate(consumer_types)
        data_matrix[i, j] = results[consumer][risk]
    end
end

# Create grouped bar chart
p = groupedbar(
    data_matrix,
    bar_position = :dodge,
    bar_width = 0.7,
    xticks = (1:length(risk_levels), risk_labels),
    labels = permutedims(consumer_types),
    ylabel = "CfD Payout [M€]",
    xlabel = "Risk Aversion Parameter [β]",
    title = "Consumer CfD Payout Across Risk Levels",
    legend = :topleft,
    size = (1400, 800),
    titlefontsize = 14,
    xguidefontsize = 12,
    yguidefontsize = 12,
    tickfontsize = 11,
    legendfontsize = 10,
    grid = true,
    xflip = true,
    gridstyle = :dash,
    gridalpha = 0.3,
    fillalpha = 0.75,
    linewidth = 2,
    left_margin = 15Plots.mm,
    right_margin = 15Plots.mm,
    bottom_margin = 15Plots.mm,
    top_margin = 15Plots.mm
)

# Display the plot
display(p)

# Save the plot
output_dir = joinpath( "Analysis", "plots")
mkpath(output_dir)
output_file = joinpath(output_dir, "CfD_payout_all_risk_levels.png")
savefig(p, output_file)

println("\n" * "="^80)
println("Combined CfD payout bar chart saved to: $output_file")
println("="^80)