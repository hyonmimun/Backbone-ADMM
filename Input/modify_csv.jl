using CSV, DataFrames, Dates
const home_dir = @__DIR__

df = CSV.read(joinpath("Input","timeseries", "timeseries_2021.csv"), DataFrame)
#df_source = CSV.read(joinpath("Input","timeseries","timeseries.csv"), DataFrame)

@assert nrow(df) == 8760 "Verwacht 8760 uren"

# Constanten als voorbeeld
df.CONS_HIGH = fill(0.00005, nrow(df))  # dummy data
df.CONS_MEDIUM = fill(0.00002, nrow(df))   # dummy data
df.CONS_LOW = fill(0.00001, nrow(df))   # dummy data
#df.WIND_ONSHORE = 
#df.WIND_OFFSHORE =
df.SOLAR_SOUTH = fill(0.005, nrow(df))
df.SOLAR_WEST = fill(0.006, nrow(df))

# Wegschrijven
outpath = joinpath("Input","timeseries","timeseries_2021_mod.csv")
CSV.write(outpath, df)