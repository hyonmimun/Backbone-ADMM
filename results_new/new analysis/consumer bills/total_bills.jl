using CSV, DataFrames, Glob

function sum_total_bills_pivot(; 
    folder::String = "cfd_0.2"
)
    bills_dir = "results_new/new analysis/consumer bills"
    pattern = bills_dir * "/bills_$(folder)_*_*.csv"  # <-- Use forward slash
    files = Glob.glob(pattern)

    println("Pattern: $pattern")
    println("Matched files: ", files)

    results = DataFrame(agent=String[], scenario=Int[], year=String[], total_bill=Float64[])

    folder_re = replace(folder, "." => "\\.")
    regex_str = "bills_$(folder_re)_(.*)_(\\d+)_(\\d{4})\\.csv"
    println("Regex: $regex_str")

    for file in files
        println("Testing file: ", basename(file))
        m = match(Regex(regex_str), basename(file))
        println("Match result: ", m)
        if m === nothing
            println("⚠ Could not parse filename: $file")
            continue
        end
        agent = m.captures[1]
        scenario = parse(Int, m.captures[2])
        year = m.captures[3]

        df = CSV.read(file, DataFrame)
        println("Columns in $(file): ", names(df))

        total = sum(df.value)
        push!(results, (agent, scenario, year, total))
    end

    if nrow(results) == 0
        println("No results found. Check your file patterns and regex.")
        return
    end

    # Pivot: rows=agent, columns=scenario, values=total_bill
    pivot = unstack(results, :agent, :scenario, :total_bill)
    CSV.write(joinpath(bills_dir, "total_bills_$(folder).csv"), pivot)
    println("✓ Wrote pivot table to total_bills_$(folder).csv")
    return pivot
end

sum_total_bills_pivot(folder="EOM_0.2")

