using CSV, DataFrames

function normalize_cvar_by_generation(cvar_file, gen_file, output_file; agent_col="agent")
    cvar_df = CSV.read(cvar_file, DataFrame)
    gen_df = CSV.read(gen_file, DataFrame)

    agents = intersect(cvar_df[!, agent_col], gen_df[!, agent_col])
    risk_levels = names(cvar_df)[2:end]

    out = DataFrame(agent = agents)
    for col in risk_levels
        out[!, col] = [
            (cvar_df[cvar_df[!, agent_col] .== agent, col][1] / gen_df[gen_df[!, agent_col] .== agent, col][1])
            for agent in agents
        ]
    end

    CSV.write(output_file, out)
    println("✓ Wrote $output_file")
    return out
end

# Example usage for CfD consumers:
normalize_cvar_by_generation(
    "results_new/new analysis/CVAR/cfd_CVAR_gen.csv",
    "results_new/new analysis/expected generation/mean_cfd_generation.csv",
    "results_new/new analysis/CVAR/normalized_cfd_CVAR_gen.csv",
    agent_col="agent"
)