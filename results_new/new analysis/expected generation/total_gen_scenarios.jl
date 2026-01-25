using CSV, DataFrames, Glob

function sum_generation_per_scenario_all(; 
    folder::String = "cfd_0.2", 
    market_design::String = "cfd",  # or "EOM"
    agent_type::String = "Gen",     # or "Cons" if needed
    output_file::String = "total_generation_per_scenario.csv"
)
    # Find all agent types in the folder
    base_dir = "results_new/$(folder)/generation/$(agent_type)/"
    agent_dirs = filter(isdir, Glob.glob("*", base_dir))
    println("Agent directories: ", agent_dirs)

    agents = map(basename, agent_dirs)
    scenarios = Set{String}()
    results = Dict{String, Dict{String, Float64}}()

for (i, agent_dir) in enumerate(agent_dirs)
    agent = agents[i]
    synth_dir = joinpath(agent_dir, "synthesized_timeseries")
    pattern = joinpath(synth_dir, "synthetic_*_generation_$(agent)_*_*.csv")
    pattern = replace(pattern, '\\' => '/')
    files = Glob.glob(pattern)
    println("Agent: $agent, Synth dir: $synth_dir, Files: ", files)
    results[agent] = Dict{String, Float64}()
for file in files
    println("Processing file: ", basename(file))
    # Use a more robust regex
    m = match(r"synthetic_.*_generation_.*_(\d+)_(\d{4})\.csv", basename(file))
    println("Regex match: ", m)
    scenario = m !== nothing ? m.captures[1] : basename(file)
   push!(scenarios, String(scenario))
    df = CSV.read(file, DataFrame)
    total_gen = sum(df[:, 2])
    
    results[agent][scenario] = total_gen
end

end

    scenarios = sort(collect(scenarios))
    out = DataFrame(agent = agents)
    for scenario in scenarios
        out[!, scenario] = [get(results[agent], scenario, missing) for agent in agents]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage:
sum_generation_per_scenario_all(
    folder="cfd_0.2", 
    market_design="cfd", 
    agent_type="Cons",
    output_file="results_new/new analysis/expected generation/consumer/cfd_0.2_cons_generation_totals.csv"
)