using CSV, DataFrames, Dates, LinearAlgebra, Statistics

"""
Create synthetic full-year timeseries from representative day results
for all scenarios and all years.
"""
function create_synthetic_timeseries(;
    years::Vector{String} = ["2018", "2021", "2022"],
    market_design::String = ["cfd","EOM"], 
    n_repr_days::Int = 8,
    n_years::Int = 9,
    variables::Vector{String} = ["electricity_price", "generation", "D_ELA"],
    agents::Dict = Dict(
        "Gen" => ["Baseload", "GasTurbine", "Peak", "WindOnshore", "WindOffshore", "SolarPanels"],
        "Cons" => ["TypeA", "TypeB", "TypeC", "TypeD"])
)

# Map scenario years to calendar years
# Years 1-3 use 2018, years 4-6 use 2021, years 7-9 use 2022
year_mapping = Dict(
    1 => years[1], 2 => years[1], 3 => years[1],
    4 => years[2], 5 => years[2], 6 => years[2],
    7 => years[3], 8 => years[3], 9 => years[3]
)

# Load all ordering variable files once
weights_dict = Dict{String, Matrix{Float64}}()
for year in years
    weights_path = "Input/output_$(year)_base/ordering_variable.csv"
    weights_df = CSV.read(weights_path, DataFrame, delim=",", header=1)
    weights_dict[year] = Matrix{Float64}(weights_df)
    println("Loaded ordering variable for year $year")
end

for variable in variables
    println("\nVariable: $variable")

    if variable == "electricity_price"
        for year_idx in 1:n_years
            year_nr = "year_$year_idx"
            year = year_mapping[year_idx]  # Get the appropriate year
            weights_mat = weights_dict[year]  # Get corresponding weights 

            results_path = joinpath("Results","new_timeseries","EOM_1_risk","$variable") ########################## change file name ###############################################
            synthetic_results_path = joinpath(results_path,"$(market_design)_$(variable)_$(year_nr).csv") # input file
            out_path = joinpath(results_path,"synthesized timeseries","synthetic_$(market_design)_$(variable)_$(year_nr)_$(year).csv")

            """ Load results which are ordered as 24 hours x 8 repr days """
            repr_results = CSV.read(synthetic_results_path, DataFrame, delim=";", header=1)
            rep_mat = Matrix{Float64}(repr_results) # (24 x 8)
            
            year_24x365 = rep_mat * permutedims(weights_mat)  # (24 x 8) * (365 x 8) = 24x365
            year_hours_8760 = vec(year_24x365)

            """ Create timestamps for the new file """
            t_start = DateTime(parse(Int, year), 1, 1, 0, 0, 0)
            t_end   = DateTime(parse(Int, year), 12, 31, 23, 0, 0)
            timestamps = collect(t_start:Hour(1):t_end)

            @assert length(timestamps) == 8760 "Aantal timestamps is niet 8760; check schrikkeljaar of inputs."

            """ Save results """
            out_df = DataFrame(timestamp = timestamps)
            out_df[!, variable] = year_hours_8760
            mkpath(dirname(out_path))
            CSV.write(out_path, out_df, delim=";")
            println("Klaar! Weggeschreven naar: $out_path")
        end

    elseif variable == "generation"
        for agent_type in ["Gen", "Cons"]
            println("\n  Agent type: $agent_type")
            
            for agent_name in agents[agent_type]
                println("    Agent: $agent_name")
                
                for year_idx in 1:n_years
                    year_nr = "year$year_idx"
                    year = year_mapping[year_idx]  # Get the appropriate year
                    weights_mat = weights_dict[year]  # Get corresponding weights
                    ###################################################################
                    #results_path = "Results/EOM_risk_1/generation/$(agent_type)/$(agent_name)"
                    results_path = "Results/CfD_risk_1_strike_0.07/generation/$(agent_type)/$(agent_name)"
                    #################################################################
                    synthetic_results_path = joinpath(results_path, "$(market_design)_generation_$(agent_name)_$(year_nr).csv")
                    ###################################################################
                    out_path = joinpath(results_path, "synthesized timeseries", "synthetic_generation_$(agent_name)_$(year_nr)_$(year).csv")
                    
                    if !isfile(synthetic_results_path)
                        println("      ⚠ Year $year_idx: File not found - $(basename(synthetic_results_path))")
                        continue
                    end
                    
                    # Load representative day results
                    repr_results = CSV.read(synthetic_results_path, DataFrame, delim=";", header=1)
                    rep_mat = Matrix{Float64}(repr_results)
                    
                    # Create full year using the correct weights
                    year_24x365 = rep_mat * permutedims(weights_mat)
                    year_hours_8760 = vec(year_24x365)
                    
                    # Create timestamps
                    t_start = DateTime(parse(Int, year), 1, 1, 0, 0, 0)
                    t_end = DateTime(parse(Int, year), 12, 31, 23, 0, 0)
                    timestamps = collect(t_start:Hour(1):t_end)
                    
                    @assert length(timestamps) == 8760 "Expected 8760 timestamps"
                    
                    # Save results
                    mkpath(dirname(out_path))
                    out_df = DataFrame(timestamp = timestamps)
                    out_df[!, "generation"] = year_hours_8760
                    CSV.write(out_path, out_df, delim=";")
                    println("      ✓ Year $year_idx (using $year weights)")
                end
            end
        end
        elseif variable == "D_ELA"
            for agent_type in ["Cons"]
            println("\n  Agent type: $agent_type")
            
            for agent_name in agents[agent_type]
                println("    Agent: $agent_name")
                
                for year_idx in 1:n_years
                    year_nr = "year$year_idx"
                    year = year_mapping[year_idx]  # Get the appropriate year
                    weights_mat = weights_dict[year]  # Get corresponding weights
                    ###################################################################
                    #results_path = "Results/EOM_risk_0.2/D_ELA/$(agent_name)"
                    results_path = "Results/new_timeseries/EOM_0.2_risk/D_ELA/$(agent_name)"
                    #################################################################
                    synthetic_results_path = joinpath(results_path, "$(market_design)_elastic_demand_$(agent_name)_$(year_nr).csv")
                    ###################################################################
                    out_path = joinpath(results_path, "synthesized timeseries", "synthetic_D_ELA_$(agent_name)_$(year_nr)_$(year).csv")
                    
                    if !isfile(synthetic_results_path)
                        println("      ⚠ Year $year_idx: File not found - $(basename(synthetic_results_path))")
                        continue
                    end
                    
                    # Load representative day results
                    repr_results = CSV.read(synthetic_results_path, DataFrame, delim=";", header=1)
                    rep_mat = Matrix{Float64}(repr_results)
                    
                    # Create full year using the correct weights
                    year_24x365 = rep_mat * permutedims(weights_mat)
                    year_hours_8760 = vec(year_24x365)
                    
                    # Create timestamps
                    t_start = DateTime(parse(Int, year), 1, 1, 0, 0, 0)
                    t_end = DateTime(parse(Int, year), 12, 31, 23, 0, 0)
                    timestamps = collect(t_start:Hour(1):t_end)
                    
                    @assert length(timestamps) == 8760 "Expected 8760 timestamps"
                    
                    # Save results
                    mkpath(dirname(out_path))
                    out_df = DataFrame(timestamp = timestamps)
                    out_df[!, "elastic demand"] = year_hours_8760
                    CSV.write(out_path, out_df, delim=";")
                    println("      ✓ Year $year_idx (using $year weights)")
                end
            end
        end
    end
end
end
# Call the function
create_synthetic_timeseries(
    years = ["2018", "2021", "2022"],
    market_design = "EOM",
    n_repr_days = 8,
    n_years = 9,
    variables = ["D_ELA"],
    agents = Dict(
        "Gen" => ["Baseload", "GasTurbine", "Peak", "WindOnshore", "WindOffshore", "SolarPanels"],
        "Cons" => ["TypeA", "TypeB", "TypeC", "TypeD"]
    )
)