using CSV, DataFrames, Statistics, Plots

market_design = "EOM"
scenario = "base"
variable = "electricity_price"
#agent_type = Cons #Gen
#agent = "TypeA"

#results_path = joinpath("Results_8_repr_days","$market_design","$variable","$agent")
results_path = joinpath("Results_8_repr_days","$market_design","$variable")

#year1      = joinpath(results_path,"synthetic_$(scenario)_$(market_design)_$(variable)_$(agent)_year1.csv")
#year2      = joinpath(results_path,"synthetic_$(scenario)_$(market_design)_$(variable)_$(agent)_year2.csv")
#year3      = joinpath(results_path,"synthetic_$(scenario)_$(market_design)_$(variable)_$(agent)_year3.csv")

year1      = joinpath(results_path,"synthetic_$(scenario)_$(market_design)_$(variable)_year_1.csv")
year2      = joinpath(results_path,"synthetic_$(scenario)_$(market_design)_$(variable)_year_2.csv")
year3      = joinpath(results_path,"synthetic_$(scenario)_$(market_design)_$(variable)_year_3.csv")

files  = [year1, year2,year3]
labels = ["2018", "2021", "2022"]
out_dir = joinpath("Results","figures")
mkpath(out_dir)

p_sorted_list = Vector{Vector{Float64}}()
lengths = Int[]

for f in files
    dataf = CSV.read(f, DataFrame)
    results = collect(skipmissing(dataf.electricity_price)) #variable name!!!!!!!!
    push!(p_sorted_list, sort(results; rev=true))
    push!(lengths, length(results))
end

n_common = minimum(lengths)
hours = 1:n_common

# plot
default(fmt=:png)
plt = plot(xlabel="Aantal uren",
           ylabel="€/GWh",
           title="EOM PDC",
           yticks = :auto,                         # laat ticks genereren
           yformatter = y -> @sprintf("%.0f", y),   # ✅ zorg dat het hele getallen zijn
           legend=:topright, lw=2)

for (i, p_sorted) in enumerate(p_sorted_list)
    plot!(hours, p_sorted[1:n_common], label=labels[i])
end

savefig(joinpath(out_dir, "$(scenario)_$(market_design)_$(variable).png")) # aanpassen
println("Opgeslagen")