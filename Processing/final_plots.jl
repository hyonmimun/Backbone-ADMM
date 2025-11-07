using CSV, DataFrames, Plots

# Read both CSV files
df_eom = CSV.read("Results/Weighted Objectives/eom_weighted_objectives/eom weighted objectives.csv", DataFrame)
df_cfd = CSV.read("Results/Weighted Objectives/cfd_weighted_objectives/CfD weighted objectives.csv", DataFrame)

# Print column names to debug
println("EOM Column names: ", names(df_eom))
println("CfD Column names: ", names(df_cfd))

# Extract risk parameter values (columns 3 onward: "0.2", "0.4", "0.6", "0.8", "1.0")
col_names = names(df_eom)
risk_params = parse.(Float64, col_names[3:end])

# Filter for consumer types only
consumer_types = ["TypeA", "TypeB", "TypeC", "TypeD"]

# Create a combined plot for consumer types
p = plot(
    size = (1000, 700),
    legend = :outerright,
    xlabel = "Risk Parameter (β)",
    ylabel = "Weighted Objective [M€]",
    title = "Consumer Agents - Weighted Objectives Comparison (EOM vs CfD)",
    xflip = true,  # This reverses the x-axis
    legendfontsize = 9,
    right_margin = 15Plots.mm,  # Add extra margin on the right for legend
    bottom_margin = 5Plots.mm,
    left_margin = 5Plots.mm,
    top_margin = 5Plots.mm
)

# Define colors and markers for each consumer type
colors = Dict("TypeA" => :blue, "TypeB" => :red, "TypeC" => :green, "TypeD" => :purple)
markers_eom = :circle
markers_cfd = :square

# Plot each consumer type
for row_eom in eachrow(df_eom)
    agent = row_eom[2]  # Agent name is in column "Agent"
    
    # Only plot if it's one of the consumer types
    if agent in consumer_types
        # Get EOM values for this agent
        values_eom = Vector{Float64}(row_eom[3:end])
        
        # Get CfD values for this agent
        row_cfd = df_cfd[df_cfd[!, 2] .== agent, :]
        values_cfd = Vector{Float64}(row_cfd[1, 3:end])
        
        # Plot EOM (solid line)
        plot!(
            p,
            risk_params,
            values_eom,
            label = "$agent - EOM",
            marker = markers_eom,
            linewidth = 2,
            color = colors[agent],
            linestyle = :solid
        )
        
        # Plot CfD (dashed line)
        plot!(
            p,
            risk_params,
            values_cfd,
            label = "$agent - CfD",
            marker = markers_cfd,
            linewidth = 2,
            color = colors[agent],
            linestyle = :dash
        )
    end
end

# Display the plot
display(p)

# Save the combined plot
savefig(p, "Results/Weighted Objectives/consumer_types_comparison.png")

println("Combined consumer types plot saved!")



#= using CSV, DataFrames, Plots

# Read both CSV files
df_eom = CSV.read("Results/Weighted Objectives/eom_weighted_objectives/eom weighted objectives.csv", DataFrame)
df_cfd = CSV.read("Results/Weighted Objectives/cfd_weighted_objectives/CfD weighted objectives.csv", DataFrame)

# Print column names to debug
println("EOM Column names: ", names(df_eom))
println("CfD Column names: ", names(df_cfd))

# Extract risk parameter values (columns 3 onward: "0.2", "0.4", "0.6", "0.8", "1.0")
col_names = names(df_eom)
risk_params = parse.(Float64, col_names[3:end])

# Create directory for individual plots if it doesn't exist
mkpath("Results/Weighted Objectives/individual_plots")

# Plot each agent separately
for (idx, row_eom) in enumerate(eachrow(df_eom))
    agent = row_eom[2]  # Agent name is in column "Agent"
    
    # Get EOM values for this agent
    values_eom = Vector{Float64}(row_eom[3:end])  # Data values start from column "0.2" onward
    
    # Get CfD values for this agent
    row_cfd = df_cfd[df_cfd[!, 2] .== agent, :]
    values_cfd = Vector{Float64}(row_cfd[1, 3:end])
    
    # Create individual plot for this agent
    p = plot(
        size = (800, 600),
        legend = :outerright,
        xlabel = "Risk Parameter (β)",
        ylabel = "Weighted Objective [M€]",
        title = "$agent - Weighted Objectives Comparison",
        xflip = true  # This reverses the x-axis
    )
    
    # Plot EOM
    plot!(
        p,
        risk_params,
        values_eom,
        label = "EOM",
        marker = :circle,
        linewidth = 2,
        color = :blue
    )
    
    # Plot CfD
    plot!(
        p,
        risk_params,
        values_cfd,
        label = "CfD",
        marker = :square,
        linewidth = 2,
        color = :red,
        linestyle = :dash
    )
    
    # Display the plot
    display(p)
    
    # Save individual plot
    savefig(p, "Results/Weighted Objectives/individual_plots/$(agent)_weighted_objectives.png")
end

println("All individual plots saved!")
=#



#= using CSV, DataFrames, Plots

# Read the CSV file
df = CSV.read("Results/Weighted Objectives/eom_weighted_objectives/eom weighted objectives.csv", DataFrame)

# Print column names to debug
println("Column names: ", names(df))

# Extract risk parameter values (columns 3 onward: "0.2", "0.4", "0.6", "0.8", "1.0")
col_names = names(df)
risk_params = parse.(Float64, col_names[3:end])
# Reverse the risk_params to go from 1.0 to 0.2
risk_params = reverse(risk_params)

# Create a plot for each agent
p = plot(
    layout = (5, 2),  # 10 agents in 5 rows, 2 columns
    size = (1200, 1400),
    legend = :bottomleft,
    xlabel = "Risk Parameter (β)",
    ylabel = "Weighted Objective [M€]",
    xflip = true  # This reverses the x-axis
)

# Plot each agent
for (idx, row) in enumerate(eachrow(df))
    agent = row[2]  # Agent name is in column "Agent"
    values = Vector{Float64}(row[3:end])  # Data values start from column "0.2" onward
    values = reverse(values)
    
    plot!(
        p[idx],
        risk_params,
        values,
        label = agent,
        marker = :circle,
        linewidth = 2,
        title = agent,
        xlabel = "Risk Parameter (β)",
        ylabel = "Objective Value [M€]"
    )
end

# Display the plot
display(p)

# Save the plot
savefig(p, "Results/Weighted Objectives/eom_weighted_objectives/eom_weighted_objectives_by_agent.png") =#

#=
using CSV, DataFrames

# Read the CSV file
df = CSV.read("Results/Weighted Objectives/cfd_weighted_objectives/CfD weighted objectives.csv", DataFrame)

# Multiply all columns except "Column1" and "Agent" by -1
for col in names(df)[3:end]  # Skip "Column1" and "Agent"
    df[!, col] = -1 .* df[!, col]
end

# Save the modified dataframe back to CSV
CSV.write("Results/Weighted Objectives/cfd_weighted_objectives/CfD weighted objectives.csv", df)

println("Values multiplied by -1 successfully!")

=#