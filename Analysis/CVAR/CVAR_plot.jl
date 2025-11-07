using CSV
using DataFrames
using Plots
using Statistics

println("\n" * "="^80)
println("Creating Combined VAR Bar Charts for All Consumer Types")
println("="^80)

# Configuration
data_dir = joinpath("Analysis", "VAR")

# Read both files
eom_path = joinpath(data_dir, "VAR_consumers_EOM.csv")
cfd_path = joinpath(data_dir, "VAR_CfD_consumers.csv")

eom_df = CSV.read(eom_path, DataFrame)
cfd_df = CSV.read(cfd_path, DataFrame)

println("Loaded VAR data:")
println("  EOM columns: ", names(eom_df))
println("  CfD columns: ", names(cfd_df))

# Get risk levels from the 'risk' column
risk_levels = eom_df.risk
println("\nRisk levels: $risk_levels")

# Get consumer types from column names (skip first column which is 'risk')
consumer_types = names(eom_df)[2:end]
println("Consumer types: $consumer_types")

# Create risk labels for x-axis
risk_labels = ["β=$r" for r in risk_levels]
n_risks = length(risk_levels)

# Set up output directory
output_dir = joinpath("Results", "Analysis", "plots")
mkpath(output_dir)

# Create array to store individual plots
plots_array = []

# Create a plot for each consumer
for consumer in consumer_types
    println("\nCreating plot for $consumer:")
    
    # Extract data for this consumer
    eom_values = eom_df[!, consumer]
    cfd_values = cfd_df[!, consumer]
    
    # Create data matrix: rows = risk levels, columns = [EOM, CfD]
    data_matrix = hcat(eom_values, cfd_values)
    
    # Print values
    for (j, risk) in enumerate(risk_levels)
        println("  β=$risk: EOM = $(round(eom_values[j], digits=4)) M€, CfD = $(round(cfd_values[j], digits=4)) M€")
    end
    
    # Create grouped bar chart
    p = groupedbar(
        data_matrix,
        bar_position = :dodge,
        bar_width = 0.7,
        xticks = (1:n_risks, risk_labels),
        labels = ["EOM" "CfD"],
        ylabel = "VAR (M€)",
        xlabel = "Risk Aversion Parameter (β)",
        title = "$consumer",
        legend = :topright,
        titlefontsize = 12,
        xguidefontsize = 10,
        yguidefontsize = 10,
        tickfontsize = 9,
        legendfontsize = 9,
        grid = true,
        gridstyle = :dash,
        gridalpha = 0.3,
        fillalpha = 0.75,
        linewidth = 1.5
    )
    
    push!(plots_array, p)
    println("  ✓ Created subplot for $consumer")
end

# Combine all plots into one figure (2x2 grid)
combined_plot = plot(
    plots_array...,
    layout = (2, 2),
    size = (1400, 1000),
    plot_title = "Value at Risk (VAR) - All Consumer Types",
    plot_titlefontsize = 16,
    left_margin = 5Plots.mm,
    right_margin = 5Plots.mm,
    bottom_margin = 5Plots.mm,
    top_margin = 10Plots.mm
)

# Display the combined plot
display(combined_plot)

# Save the combined plot
output_file = joinpath(output_dir, "VAR_all_consumers_combined.png")
savefig(combined_plot, output_file)

println("\n" * "="^80)
println("Combined VAR bar chart saved to: $output_file")
println("="^80)