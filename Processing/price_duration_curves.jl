#=
using CSV
using DataFrames
using Plots
using Statistics
using Dates

println("\n" * "="^80)
println("Creating Price Timeseries for All Market Designs and Risk Levels")
println("="^80)

# Directory with the mean price files
price_dir = joinpath("Results", "Analysis", "electricity_price")

# Define the files and their labels
files_config = [

    #("mean_price_all_scenarios_EOM_0.2.csv", "EOM β=0.2", :blue, :solid),
    #("mean_price_all_scenarios_EOM_1.csv", "EOM β=1.0", :blue, :dash),
    #("mean_price_all_scenarios_cfd_0.2.csv", "CfD β=0.2", :red, :solid),
    #("mean_price_all_scenarios_cfd_1.csv", "CfD β=1.0", :red, :dash)
]

# Create the plot
p = plot(
    size = (1400, 900),
    xlabel = "Time (hours)",
    ylabel = "Electricity Price [€/MWh]",
    title = "Electricity Price Timeseries - Temporal Variation",
    legend = :topright,
    legendfontsize = 12,
    titlefontsize = 16,
    xguidefontsize = 14,
    yguidefontsize = 14,
    tickfontsize = 12,
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3,
    left_margin = 5Plots.mm,
    right_margin = 5Plots.mm,
    bottom_margin = 5Plots.mm,
    top_margin = 5Plots.mm
)

# Process each file
for (filename, label, color, linestyle) in files_config
    filepath = joinpath(price_dir, filename)
    
    if !isfile(filepath)
        @warn "File not found: $filename"
        continue
    end
    
    # Read the CSV file
    df = CSV.read(filepath, DataFrame; delim=';')
    
    # Get timestamp and price columns
    timestamps = df[!, 1]  # First column (timestamp)
    price_col = names(df)[2]  # Second column (price)
    prices = df[!, price_col]
    
    # Convert from M€/GWh to €/MWh (multiply by 1000)
    prices_eur_mwh = prices .* 1000
    
    # Create hour index (1 to 8760)
    hours = 1:length(prices_eur_mwh)
    
    # Plot the timeseries
    plot!(
        p,
        hours,
        prices_eur_mwh,
        linewidth = 1.5,
        label = label,
        color = color,
        linestyle = linestyle,
        alpha = 0.7
    )
    
    # Print statistics
    println("\n$label:")
    println("  Min price: $(round(minimum(prices_eur_mwh), digits=2)) €/MWh")
    println("  Max price: $(round(maximum(prices_eur_mwh), digits=2)) €/MWh")
    println("  Mean price: $(round(mean(prices_eur_mwh), digits=2)) €/MWh")
    println("  Median price: $(round(median(prices_eur_mwh), digits=2)) €/MWh")
    println("  Std dev: $(round(std(prices_eur_mwh), digits=2)) €/MWh")
    println("✓ Added to plot")
end

# Save the plot
output_dir = joinpath("Results", "Analysis", "plots")
mkpath(output_dir)
output_file = joinpath(output_dir, "price_timeseries_EOM_high_var.png")
savefig(p, output_file)

println("\n" * "="^80)
println("✓ Price timeseries saved to: $output_file")
println("="^80)
=#

using CSV
using DataFrames
using Plots
using Statistics

println("\n" * "="^80)
println("Creating Load Duration Curves for All Market Designs and Risk Levels")
println("="^80)

# Directory with the mean price files
price_dir = joinpath("Results", "Analysis", "D_ELA")

# Define the files and their labels
files_config = [
    ("TypeA_mean_D_ELA_all_scenarios_EOM_0.2.csv", "TypeA EOM β=0.2", :blue, :solid),
    ("TypeB_mean_D_ELA_all_scenarios_EOM_0.2.csv", "TypeB EOM β=0.2", :red, :solid),
    ("TypeC_mean_D_ELA_all_scenarios_EOM_0.2.csv", "TypeC EOM β=0.2", :yellow, :solid),
    ("TypeD_mean_D_ELA_all_scenarios_EOM_0.2.csv", "TypeD EOM β=0.2", :green, :solid),

    ("TypeA_mean_D_ELA_all_scenarios_EOM_1.csv", "TypeA EOM β=1", :blue, :dash),
    ("TypeB_mean_D_ELA_all_scenarios_EOM_1.csv", "TypeB EOM β=1", :red, :dash),
    ("TypeC_mean_D_ELA_all_scenarios_EOM_1.csv", "TypeC EOM β=1", :yellow, :dash),
    ("TypeD_mean_D_ELA_all_scenarios_EOM_1.csv", "TypeD EOM β=1", :green, :dash),
    #("mean_price_all_scenarios_EOM_0.2_high_var.csv", "EOM β=0.2", :blue, :solid),
    #("mean_price_all_scenarios_EOM_risk_1_high_var.csv", "EOM β=1", :red, :solid)
    #("mean_price_all_scenarios_EOM_0.2.csv", "EOM β=0.2", :blue, :solid),
    #("mean_price_all_scenarios_EOM_1.csv", "EOM β=1.0", :blue, :dash),
    #("mean_price_all_scenarios_cfd_0.2.csv", "CfD β=0.2", :red, :solid),
    #("mean_price_all_scenarios_cfd_1.csv", "CfD β=1.0", :red, :dash)
]

# Create the plot
p = plot(
    size = (1400, 900),
    xlabel = "Hours (sorted)",
    ylabel = "Elastic demand [MWh]",
    title = "Risk-adjusted Elastic Demand",
    legend = :topright,
    legendfontsize = 12,
    titlefontsize = 16,
    xguidefontsize = 14,
    yguidefontsize = 14,
    tickfontsize = 12,
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3,
    left_margin = 5Plots.mm,
    right_margin = 5Plots.mm,
    bottom_margin = 5Plots.mm,
    top_margin = 5Plots.mm
)

# Process each file
for (filename, label, color, linestyle) in files_config
    filepath = joinpath(price_dir, filename)
    
    if !isfile(filepath)
        @warn "File not found: $filename"
        continue
    end
    
    # Read the CSV file
    df = CSV.read(filepath, DataFrame; delim=';')
    
    # Get price column (second column)
    price_col = names(df)[2]
    prices = df[!, price_col]
    
    # Convert from M€/GWh to €/MWh (multiply by 1000)
    prices_eur_mwh = prices .* 1000
    
    # Sort prices in descending order for duration curve
    sorted_prices = sort(prices_eur_mwh, rev=true)
    hours = 1:length(sorted_prices)
    
    # Plot the duration curve
    plot!(
        p,
        hours,
        sorted_prices,
        linewidth = 2.5,
        label = label,
        color = color,
        linestyle = linestyle,
        alpha = 0.8
    )
    end


# Save the plot
output_dir = joinpath("Results", "Analysis", "D_ELA")
mkpath(output_dir)
output_file = joinpath(output_dir, "D_ELA_EOM_high_var.png")
savefig(p, output_file)

println("\n" * "="^80)
println("✓ Elastic Demand duration curve saved to: $output_file")
println("="^80)

#=
ALL INDIVIDUAL PLOTS IN 1 GRAPH
println("\n" * "="^80)
println("✓ Price duration curve plotting complete!")
println("="^80)

# Add code for individual price duration curves in one plot
println("\n" * "="^80)
println("Creating Individual Price Duration Curves Plot")
println("="^80)

# Define colors for different year groups
colors_2018 = [:blue, :lightblue, :dodgerblue]
colors_2021 = [:red, :lightcoral, :indianred]
colors_2022 = [:green, :lightgreen, :limegreen]

# Create combined plot with all individual curves
p_individual = plot(
    size = (1400, 900),
    xlabel = "Hours (sorted)",
    ylabel = "Electricity Price [M€/GWh]",
    title = "Price Duration Curves - All Individual Scenarios (EOM, β=0.2)",
    legend = :topright,
    legendfontsize = 8,
    titlefontsize = 16,
    xguidefontsize = 14,
    yguidefontsize = 14,
    tickfontsize = 12,
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3,
    bottom_margin = 5Plots.mm,
    left_margin = 5Plots.mm,
    right_margin = 5Plots.mm
)

for year_idx in 1:n_years
    year_nr = "year_$year_idx"
    order_year = year_mapping[year_idx]
    
    # Load synthetic electricity prices
    price_file = "Results/EOM_risk_0.2/electricity_price/synthesized timeseries/synthetic_$(market_design)_electricity_price_$(year_nr)_$(order_year).csv"
    
    if !isfile(price_file)
        @warn "Year $year_idx: File not found - $(basename(price_file))"
        continue
    end
    
    prices_df = CSV.read(price_file, DataFrame, delim=";")
    prices = prices_df.electricity_price
    
    # Sort prices in descending order for duration curve
    sorted_individual_prices = sort(prices, rev=true)
    hours_individual = 1:length(sorted_individual_prices)
    
    # Determine color based on year group
    if year_idx <= 3
        color = colors_2018[year_idx]
        year_label = "2018"
    elseif year_idx <= 6
        color = colors_2021[year_idx - 3]
        year_label = "2021"
    else
        color = colors_2022[year_idx - 6]
        year_label = "2022"
    end
    
    # Plot the duration curve
    plot!(
        p_individual,
        hours_individual,
        sorted_individual_prices,
        linewidth = 2,
        label = "Scenario $year_idx ($year_label)",
        color = color,
        alpha = 0.7
    )
    
    println("✓ Added Scenario $year_idx to combined plot")
end

# Save the combined individual curves plot
output_file_individual = "Results/EOM_risk_0.2/electricity_price/synthesized timeseries/pdc_eom_risk_0.2_all_scenarios.png"
savefig(p_individual, output_file_individual)
println("\n✓ Individual price duration curves saved to: $output_file_individual")

println("\n" * "="^80)
println("✓ All plotting complete!")
println("="^80)
=#
#=
PLOT 3 SCENARIOS IN 1 GRAPH (2018,2021,2022)
using CSV
using DataFrames
using Plots
using Statistics

# Directory with the 9 price files
price_dir = joinpath("Results", "EOM_risk_1", "electricity_price", "synthesized timeseries")
#price_dir = joinpath("Results", "CfD_risk_0.2_strike_0.07", "electricity_price", "synthesized timeseries")

# Collect CSV files
files = sort(filter(f -> endswith(lowercase(f), ".csv"), readdir(price_dir; join=true)))
@assert length(files) == 9 "Expected 9 CSV files in: $price_dir (got $(length(files)))"

# Output directory
output_dir = joinpath("Results", "Analysis", "plots")
mkpath(output_dir)

# Define scenario labels
scenario_labels = Dict(
    1 => "Base RES AF",
    2 => "High RES AF",
    3 => "Low RES AF"
)

# Define year groups
year_groups = [
    (1:3, "2018", [:blue, :lightblue, :dodgerblue]),
    (4:6, "2021", [:red, :lightcoral, :indianred]),
    (7:9, "2022", [:green, :lightgreen, :limegreen])
]

# Create 3 separate plots
for (range, year_label, colors) in year_groups
    p = plot(
        size = (1200, 700),
        xlabel = "Hours (sorted)",
        ylabel = "Electricity Price [€/MWh]",
        title = "Price Duration Curves - EOM β=1 ($year_label)",
        legend = :topright,
        legendfontsize = 10,
        titlefontsize = 12,
        grid = true,
        left_margin = 5Plots.mm,
        right_margin = 5Plots.mm,
        bottom_margin = 5Plots.mm,
        top_margin = 5Plots.mm
    )
    
    for (local_idx, scenario_idx) in enumerate(range)
        f = files[scenario_idx]
        
        # Read the CSV file
        df = CSV.read(f, DataFrame; delim=';')
        
        # Get price column (second column after timestamp)
        price_col = names(df)[2]
        prices = df[!, price_col]
        
        # Sort prices in descending order for duration curve
        sorted_prices = sort(prices, rev=true)
        
        # Create x-axis (hours from 1 to 8760)
        hours = 1:length(sorted_prices)

        # Get the label for this scenario (cycles through 1, 2, 3)
        label_idx = ((scenario_idx - 1) % 3) + 1
        scenario_label = scenario_labels[label_idx]
        
        # Plot the duration curve
        plot!(
            p,
            hours,
            sorted_prices,
            linewidth = 2,
            label = "$scenario_label ($year_label)",
            color = colors[local_idx],
            alpha = 0.8
        )
        
        println("✓ Processed Scenario $scenario_idx ($(basename(f))) - $scenario_label")
    end
    
    # Display the plot
    display(p)
    
    # Save the plot
    savefig(p, joinpath(output_dir, "price_duration_curves_scenarios_$(first(range))_$(last(range)).png"))
    
    println("  → Saved: price_duration_curves_scenarios_$(first(range))_$(last(range)).png\n")
end

println("="^60)
println("All 3 price duration curve plots saved to: $output_dir")
println("="^60)
=#