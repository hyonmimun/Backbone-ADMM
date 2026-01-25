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
get_year_suffix(year_idx) = year_idx <= 3 ? "2018" :
                            year_idx <= 6 ? "2021" : "2022"
for gen in generators
    println("\nProcessing: $gen")
    
    total_generation = 0.0
    total_revenue = 0.0

    for year_idx in 1:n_years
        # Logical year index (1–9)
        year_nr = "year$year_idx"
        # Physical year tag in the filename
        year_tag = get_year_suffix(year_idx)

        # ----- PRICES -----
        # e.g.: synthetic_EOM_electricity_price_year_1_2018.csv
        price_file = "Results/$(market_design)_risk_1/electricity_price/synthesized timeseries/" *
                     "synthetic_$(market_design)_electricity_price_$(year_nr)_$(year_tag).csv"
        
        if !isfile(price_file)
            @warn "  Year $year_idx: Price file not found: $price_file"
            continue
        end
        
        prices_df = CSV.read(price_file, DataFrame, delim=";")
        prices = prices_df.electricity_price  # M€/GWh
        
        # ----- GENERATION -----
        # e.g.: synthetic_EOM_generation_Baseload_year_1_2018.csv
        gen_file = "Results/$(market_design)_risk_1/generation/Gen/$(gen)/synthesized timeseries/" *
                   "synthetic_generation_$(gen)_$(year_nr)_$(year_tag).csv"
        
        if !isfile(gen_file)
            @warn "  Year $year_idx: Generation file not found: $gen_file"
            continue
        end
        
        gen_df = CSV.read(gen_file, DataFrame, delim=";")
        generation = gen_df.generation  # GWh
        
        # Calculate revenue: M€/GWh × GWh = M€
        year_revenue = sum(prices .* generation)
        year_generation = sum(generation)

        if year_generation > 0
            year_MV = year_revenue / year_generation
            
            push!(market_values_per_year, (
                Generator = gen,
                Year = year_idx,
                MV_M€_per_GWh = year_MV,
                Generation_GWh = year_generation,
                Revenue_M€ = year_revenue
            ))
            
            println("  Year $year_idx ($(year_tag)): Gen = $(round(year_generation, digits=2)) GWh, " *
                    "Rev = $(round(year_revenue, digits=2)) M€, MV = $(round(year_MV, digits=5)) M€/GWh")
        else
            println("  Year $year_idx ($(year_tag)): No generation")
        end
        
        total_revenue += year_revenue
        total_generation += year_generation
    end
    
    if total_generation > 0
        MV = total_revenue / total_generation
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
output_file_total = "Results/$(market_design)_risk_1/market_values_total.csv"
CSV.write(output_file_total, market_values, delim=";")
println("\n✓ Total market values saved to: $output_file_total")

output_file_per_year = "Results/$(market_design)_risk_1/market_values_per_year.csv"
CSV.write(output_file_per_year, market_values_per_year, delim=";")
println("✓ Per-year market values saved to: $output_file_per_year")

