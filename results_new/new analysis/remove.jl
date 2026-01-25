
using Glob, FilePathsBase

# List of scenario folders
folders = [
    "results_new/EOM_1", "results_new/EOM_0.8", "results_new/EOM_0.6", "results_new/EOM_0.4", "results_new/EOM_0.2",
    "results_new/cfd_1", "results_new/cfd_0.8", "results_new/cfd_0.6", "results_new/cfd_0.4", "results_new/cfd_0.2"
]

for folder in folders
    for agent_type in ["Cons", "Gen"]
        agent_root = joinpath(folder, "generation", agent_type)
        if isdir(agent_root)
            agents = filter(isdir, Glob.glob("*", agent_root))
            for agent in agents
                synth_dir = joinpath(agent, "synthesized_timeseries")
                if isdir(synth_dir)
                    println("Removing: $synth_dir")
                    rm(synth_dir; force=true, recursive=true)
                end
            end
        end
    end
end