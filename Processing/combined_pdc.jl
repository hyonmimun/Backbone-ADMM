using CSV, DataFrames, Statistics, Plots

files  = ["Input/output_2018/EOM_Generation_TypeA_year1.csv",
          "Input/output_2021/EOM_Generation_TypeA_year2.csv",
          "Input/output_2022/EOM_Generation_TypeA_year3.csv"]   # voorbeeld met schrikkeljaar
labels = ["2018", "2021", "2022"]
out_dir = joinpath("Results","figures")
mkpath(out_dir)

p_sorted_list = Vector{Vector{Float64}}()
lengths = Int[]

for f in files
    dataf = CSV.read(f, DataFrame)
    results = collect(skipmissing(dataf.eom_price))
    push!(p_sorted_list, sort(results; rev=true))
    push!(lengths, length(results))
end

n_common = minimum(lengths)
hours = 1:n_common

# plot
default(fmt=:png)
plt = plot(xlabel="Aantal uren",
           ylabel="GW",
           title="EOM Type A LDC 2018,2021,2022",
           legend=:topright, lw=2)

for (i, p_sorted) in enumerate(p_sorted_list)
    plot!(hours, p_sorted[1:n_common], label=labels[i])
end

savefig(joinpath(out_dir, "EOM_typeA_LDC.png"))
println("Opgeslagen")