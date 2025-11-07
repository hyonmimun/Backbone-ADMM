using CSV
using DataFrames
using Plots

# Read the data
data_path = joinpath(@__DIR__, "..", "Results", "Analysis", "consumer_risk_adjusted_cost.csv")
df = CSV.read(data_path, DataFrame; delim=';')

# Set up plot output directory
output_dir = joinpath(@__DIR__, "..", "Results", "Analysis", "plots")
mkpath(output_dir)

# Risk levels for x-axis
risk_levels = [0.2, 1.0]

# Create plots for each consumer
consumer_types = ["TypeA", "TypeB", "TypeC", "TypeD"]

# Define colors for each consumer type
colors = Dict("TypeA" => :blue, "TypeB" => :red, "TypeC" => :green, "TypeD" => :purple)

# Create a single plot
p = plot(
    size = (1000, 700),
    xlabel = "Risk Aversion Parameter [β]",
    ylabel = "Risk-Adjusted Cost [€/MWh]",
    title = "Risk-Adjusted Costs: All Consumer Types",
    legend = :outerright,
    legendfontsize = 9,
    titlefontsize = 12,
    grid = true,
    xticks = risk_levels,
    xflip = true,
    left_margin = 5Plots.mm,
    right_margin = 15Plots.mm,
    bottom_margin = 5Plots.mm,
    top_margin = 5Plots.mm
)

for consumer in consumer_types
    # Get the row for this consumer
    row = df[df.Consumer .== consumer, :]
    
    # Extract EOM values
    eom_values = [row[1, Symbol("EOM_0.2")], row[1, Symbol("EOM_1")]]
    
    # Extract CfD values
    cfd_values = [row[1, Symbol("cfd_0.2")], row[1, Symbol("cfd_1")]]
    
    # Plot EOM line
    plot!(
        p,
        risk_levels,
        eom_values,
        marker=:circle,
        markersize=7,
        linewidth=2,
        linestyle=:solid,
        label="$consumer - EOM",
        color=colors[consumer]
    )
    
    # Plot CfD line
    plot!(
        p,
        risk_levels,
        cfd_values,
        marker=:square,
        markersize=7,
        linewidth=2,
        linestyle=:dash,
        label="$consumer - CfD",
        color=colors[consumer]
    )
end

# Display the plot
display(p)

# Save the combined plot
savefig(p, joinpath(output_dir, "all_consumers_single_plot.png"))

println("\n" * "="^60)
println("Combined plot saved to: $(joinpath(output_dir, "all_consumers_single_plot.png"))")
println("="^60)