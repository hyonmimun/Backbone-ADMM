using CSV, DataFrames, Statistics

println("\n" * "="^80)
println("Market Value Calculation for All Generators")
println("="^80)

generators = ["Baseload", "GasTurbine", "Peak", "WindOnshore", "WindOffshore", "SolarPanels"]
market_design = "EOM"
n_years = 9

# Market Value Results
market_values = DataFrame(
    Generator = String[], 
    MV_M€_per_GWh = Float64[], 
    Total_Generation_GWh = Float64[], 
    Total_Revenue_M€ = Float64[]
)
# Market Value Results - Per Year
market_values_per_year = DataFrame(
    Generator = String[],
    Year = Int[],
    MV_M€_per_GWh = Float64[],
    Generation_GWh = Float64[],
    Revenue_M€ = Float64[]
)

for gen in generators
    println("\nProcessing: $gen")
    
    total_generation = 0.0
    total_revenue = 0.0

    for year_idx in 1:n_years
        year_nr = "year_$year_idx"
        
        # Load synthetic electricity prices (8760 hours)
        price_file = "Results_8_repr_days/$(market_design)/electricity_price/synthesized timeseries/synthetic_$(market_design)_electricity_price_$(year_nr).csv"
        
        if !isfile(price_file)
            @warn "  Year $year_idx: Price file not found"
            continue
        end
        
        prices_df = CSV.read(price_file, DataFrame, delim=";")
        prices = prices_df.electricity_price  # M€/GWh
        
        # Load synthetic generation (8760 hours)
        year_nr = "year$year_idx"

        gen_file = "Results_8_repr_days/$(market_design)/generation/Gen/$(gen)/synthesized timeseries/synthetic_$(market_design)_generation_$(gen)_$(year_nr).csv"
        
        if !isfile(gen_file)
            @warn "  Year $year_idx: Generation file not found"
            continue
        end
        
        gen_df = CSV.read(gen_file, DataFrame, delim=";")
        generation = gen_df.generation  # GWh
        
        # Calculate revenue: M€/GWh × GWh = M€
        year_revenue = sum(prices .* generation)
        year_generation = sum(generation)

        # Calculate market value for this year
        if year_generation > 0
            year_MV = year_revenue / year_generation
            
            # Store per-year results
            push!(market_values_per_year, (
                Generator = gen,
                Year = year_idx,
                MV_M€_per_GWh = year_MV,
                Generation_GWh = year_generation,
                Revenue_M€ = year_revenue
            ))
            
            println("  Year $year_idx: Gen = $(round(year_generation, digits=2)) GWh, Rev = $(round(year_revenue, digits=2)) M€, MV = $(round(year_MV, digits=5)) M€/GWh")
        else
            println("  Year $year_idx: No generation")
        end
        
        total_revenue += year_revenue # sum to total over 9 years
        total_generation += year_generation # sum to total over 9 years
    end
    
    # Calculate market value over all years
    if total_generation > 0
        MV = total_revenue / total_generation  # M€/GWh over all 9 years
        
        push!(market_values, (
            Generator = gen,
            MV_M€_per_GWh = MV,
            Total_Generation_GWh = total_generation,
            Total_Revenue_M€ = total_revenue
        ))
        
        println("  ✓ Market Value (over all 9 years): $(round(MV, digits=5)) M€/GWh")
    else
        println("  ⚠ No generation recorded")
    end
end

# Save results
output_file_total = "Results_8_repr_days/$(market_design)/market_values_total.csv"
CSV.write(output_file_total, market_values, delim=";")
println("\n✓ Total market values saved to: $output_file_total")

output_file_per_year = "Results_8_repr_days/$(market_design)/market_values_per_year.csv"
CSV.write(output_file_per_year, market_values_per_year, delim=";")
println("✓ Per-year market values saved to: $output_file_per_year")

