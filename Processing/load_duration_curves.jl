using CSV, DataFrames, Plots, Statistics

println("\n" * "="^80)
println("Load Duration Curves - All Generators (Average Across Scenarios)")
println("="^80)

# Configuration
market_design = "EOM"
n_years = 9
generators = ["Baseload", "GasTurbine", "Peak", "WindOnshore", "WindOffshore", "SolarPanels"]
colors = [:red, :orange, :yellow, :green, :blue, :purple]

# Initialize storage for all generators
all_generation = Dict{String, Vector{Float64}}()

for gen in generators
    println("\nProcessing: $gen")
    
    # Collect all generation from all years
    gen_data = Float64[]
    
    for year_idx in 1:n_years
        year_nr = "year$year_idx"
        
        # Load synthetic generation (8760 hours)
        #################################################################################################

        #gen_file = "Results_8_repr_days/$(market_design)/generation/Gen/$(gen)/synthesized timeseries/synthetic_$(market_design)_generation_$(gen)_$(year_nr).csv"

        #gen_file = "Validation/EOM_risk_0.4_beta/generation/Gen/$(gen)/synthesized timeseries/synthetic_$(market_design)_generation_$(gen)_$(year_nr).csv"

        gen_file = "Validation/risk_0.2_beta_EOM/EOM/generation/Gen/$(gen)/synthesized timeseries/synthetic_$(market_design)_generation_$(gen)_$(year_nr).csv"


        if !isfile(gen_file)
            @warn "  Year $year_idx: File not found - $(basename(gen_file))"
            continue
        end
        
        gen_df = CSV.read(gen_file, DataFrame, delim=";")
        generation = gen_df.generation  # GWh
        
        # Add to collection
        append!(gen_data, generation)
        
        println("  Year $year_idx: Min = $(round(minimum(generation), digits=2)), Max = $(round(maximum(generation), digits=2)), Mean = $(round(mean(generation), digits=2)) GWh")
    end
    
    # Store sorted generation (descending order)
    all_generation[gen] = sort(gen_data, rev=true)
    
    # Print overall statistics
    println("  Overall: Total hours = $(length(gen_data)), Mean = $(round(mean(gen_data), digits=2)) GWh, Max = $(round(maximum(gen_data), digits=2)) GWh")
end

# Create single plot with all generators
println("\n" * "="^80)
println("Creating Combined Load Duration Curves Plot")
println("="^80)

hours = 1:length(all_generation[generators[1]])

p = plot(
    xlabel = "Hours",
    ylabel = "Generation [GWh]",
    title = "Load Duration Curves - (Risk β 0.2 CVAR) All Generators ($n_years Years Average)",
    legend = :topright,
    size = (1400, 900),
    linewidth = 2.5,
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3,
    xguidefontsize = 14,
    yguidefontsize = 14,
    titlefontsize = 16,
    tickfontsize = 12,
    legendfontsize = 11,
    bottom_margin = 5Plots.mm,
    left_margin = 5Plots.mm,
    xformatter = x -> string(Int(round(x/1000))) * "k",
    xticks = 0:10000:maximum(hours)
)

# Plot each generator
for (idx, gen) in enumerate(generators)
    plot!(p, hours, all_generation[gen],
          label = gen,
          color = colors[idx],
          alpha = 0.8,
          linewidth = 2.5
    )
end

# Save plot
#output_file = "Results_8_repr_days/$(market_design)/load_duration_curves_all_generators.png"
#output_file = "Validation/EOM_risk_0.4_beta/load_duration_curves_CVAR_0.4.png"
output_file = "Validation/risk_0.2_beta_EOM/EOM/load_duration_curves_CVAR_0.2.png"

savefig(p, output_file)
println("\n✓ Load duration curves saved to: $output_file")

# Print summary statistics table
println("\n" * "="^80)
println("Summary Statistics - All Generators")
println("="^80)
println(rpad("Generator", 20) * rpad("Mean [GWh]", 15) * rpad("Max [GWh]", 15) * rpad("Min [GWh]", 15) * "Median [GWh]")
println("-"^80)
for gen in generators
    gen_stats = all_generation[gen]
    println(rpad(gen, 20) * 
            rpad(string(round(mean(gen_stats), digits=2)), 15) * 
            rpad(string(round(maximum(gen_stats), digits=2)), 15) * 
            rpad(string(round(minimum(gen_stats), digits=2)), 15) * 
            string(round(median(gen_stats), digits=2)))
end

println("\n" * "="^80)
println("✓ Load duration curve creation complete!")
println("="^80)