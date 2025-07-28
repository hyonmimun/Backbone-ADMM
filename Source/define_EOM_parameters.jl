function define_EOM_parameters!(EOM::Dict,data::Dict,ts::DataFrame,scenario_overview_row::DataFrameRow,market_design::AbstractString)
    # timeseries
    EOM["D"] = ts[!,:LOAD][1:data["General"]["nTimesteps"]] # MWh

    return EOM
end