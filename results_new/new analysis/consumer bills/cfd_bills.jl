using CSV, DataFrames

function add_payout_to_bills(bills_file, payout_file, out_file)
    # Read the bills and payout data
    bills = CSV.read(bills_file, DataFrame)
    payout = CSV.read(payout_file, DataFrame; delim=';')

    # Map payout columns to scenario numbers
    payout_map = Dict(
        1 => "2018_base", 2 => "2018_high", 3 => "2018_low",
        4 => "2021_base", 5 => "2021_high", 6 => "2021_low",
        7 => "2022_base", 8 => "2022_high", 9 => "2022_low"
    )

    # Prepare output DataFrame
    out = deepcopy(bills)
    for row in 1:size(bills, 1)
        agent = bills.agent[row]
        payout_row = payout[payout.Consumer .== agent, :]
        for scenario in 1:9
            payout_col = payout_map[scenario]
            if nrow(payout_row) == 1
                out[row, string(scenario)] += payout_row[1, payout_col]
            else
                println("⚠ No payout found for agent $agent")
            end
        end
    end

    CSV.write(out_file, out)
    println("✓ Wrote merged file to $out_file")
    return out
end

# Example usage:
add_payout_to_bills(
    "results_new/new analysis/consumer bills/total_bills_cfd_1.csv",
    "results_new/cfd_0.2/expressions/Cons/cfd_payout_cons.csv",
    "results_new/new analysis/consumer bills/cfd_bills_cfd_1.csv"
)