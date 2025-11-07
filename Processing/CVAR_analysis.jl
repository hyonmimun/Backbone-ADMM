using CSV, DataFrames, Plots, Statistics

println("\n" * "="^80)
println("CVaR Impact Diagnostic Analysis")
println("="^80)

# Configuration
scenarios = [
    ("Risk-neutral", "Results_8_repr_days/EOM"),
    ("CVaR 0.2", "Validation/risk_0.2_beta_EOM/EOM"),
    ("CVaR 0.4", "Validation/EOM_risk_0.4_beta")
]

generators = ["Baseload", "GasTurbine", "Peak", "WindOnshore", "WindOffshore", "SolarPanels"]
n_years = 9

# Analysis 1: Total Generation by Scenario
println("\n" * "="^80)
println("ANALYSIS 1: Total Generation Comparison")
println("="^80)

for (scenario_name, base_path) in scenarios
    println("\n$scenario_name:")
    
    for gen in generators
        total_gen = 0.0
        
        for year_idx in 1:n_years
            year_nr = "year$year_idx"
            gen_file = joinpath(base_path, "generation/Gen/$(gen)/synthesized timeseries/synthetic_EOM_generation_$(gen)_$(year_nr).csv")
            
            if !isfile(gen_file)
                continue
            end
            
            gen_df = CSV.read(gen_file, DataFrame, delim=";")
            total_gen += sum(gen_df.generation)
        end
        
        println("  $(rpad(gen, 15)): $(round(total_gen, digits=2)) GWh total")
    end
end

# Analysis 2: Generation Distribution (high vs low output hours)
println("\n\n" * "="^80)
println("ANALYSIS 2: Generation Intensity Distribution")
println("="^80)

for (scenario_name, base_path) in scenarios
    println("\n$scenario_name:")
    
    for gen in generators
        all_gen = Float64[]
        
        for year_idx in 1:n_years
            year_nr = "year$year_idx"
            gen_file = joinpath(base_path, "generation/Gen/$(gen)/synthesized timeseries/synthetic_EOM_generation_$(gen)_$(year_nr).csv")
            
            if !isfile(gen_file)
                continue
            end
            
            gen_df = CSV.read(gen_file, DataFrame, delim=";")
            append!(all_gen, gen_df.generation)
        end
        
        if length(all_gen) > 0
            # Calculate percentage of time at different output levels
            zero_hours = sum(all_gen .< 0.001) / length(all_gen) * 100
            high_hours = sum(all_gen .> quantile(all_gen, 0.9)) / length(all_gen) * 100
            
            println("  $(rpad(gen, 15)): $(round(zero_hours, digits=1))% zero, $(round(high_hours, digits=1))% high output")
        end
    end
end

# Analysis 3: Price-Generation Correlation
println("\n\n" * "="^80)
println("ANALYSIS 3: Correlation Between Price and Generation")
println("="^80)

for (scenario_name, base_path) in scenarios
    println("\n$scenario_name:")
    
    # Load prices
    all_prices = Float64[]
    for year_idx in 1:n_years
        year_nr = "year_$year_idx"
        price_file = joinpath(base_path, "electricity_price/synthesized timeseries/synthetic_EOM_electricity_price_$(year_nr).csv")
        
        if !isfile(price_file)
            continue
        end
        
        price_df = CSV.read(price_file, DataFrame, delim=";")
        append!(all_prices, price_df.electricity_price)
    end
    
    # Calculate correlation for each generator
    for gen in generators
        all_gen = Float64[]
        
        for year_idx in 1:n_years
            year_nr = "year$year_idx"
            gen_file = joinpath(base_path, "generation/Gen/$(gen)/synthesized timeseries/synthetic_EOM_generation_$(gen)_$(year_nr).csv")
            
            if !isfile(gen_file)
                continue
            end
            
            gen_df = CSV.read(gen_file, DataFrame, delim=";")
            append!(all_gen, gen_df.generation)
        end
        
        if length(all_gen) == length(all_prices) && length(all_gen) > 0
            corr = cor(all_prices, all_gen)
            println("  $(rpad(gen, 15)): correlation = $(round(corr, digits=3))")
        end
    end
end

# Analysis 4: Capacity Factor Comparison
println("\n\n" * "="^80)
println("ANALYSIS 4: Capacity Factors (if capacity data available)")
println("="^80)
println("Note: This would require installed capacity data from your model")

println("\n" * "="^80)
println("✓ Diagnostic analysis complete!")
println("="^80)