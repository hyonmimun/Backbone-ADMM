using CSV, DataFrames, Dates, Statistics
year = 2018
# ========= IN/OUT =========
input_path  = joinpath("Input","timeseries","$(year)", "timeseries_$(year).csv")
output_path = joinpath("Input","timeseries","$(year)","timeseries_$(year)_low.csv")

# Kolomnamen in jouw CSV
col_timestamp   = :times          # je timestampkolom
col_system_load = :LOAD           # systeemload in MW

# ========= TARGET GEMIDDELDES (MW per consument) =========
target_avg_MW_per_cons_low    = 0.000413
target_avg_MW_per_cons_medium = 0.000592
target_avg_MW_per_cons_high   = 0.000671  # jouw aangepaste high

# ========= 24-uurs vormcurves =========
daily_shape_high(h) = 0.9 - 0.2 * cos(2π * (h - 12) / 24)                       # vlakker/basislast
daily_shape_med(h)  = 0.7 + 0.4 * exp(-0.5 * ((h - 14) / 3)^2)                  # kantooruren
daily_shape_low(h)  = 0.6 + 0.5 * exp(-0.5 * ((h - 20) / 3)^2) +
                      0.2 * exp(-0.5 * ((h - 7) / 2)^2)                         # huishouden
safe_div(x,y) = y == 0 ? 0.0 : x / y

# ========= LOAD CSV =========
df = CSV.read(input_path, DataFrame)

# -- Parse 'times' naar DateTime (zonder aparte kolom) --
#    Voorbeeldvorm in jouw file: 2018-01-01T00:00:00.000+01:00
df.times = DateTime.(
    replace.(String.(df.times), r"(Z|[+-]\d{2}:\d{2})$" => ""),
    dateformat"yyyy-mm-ddTHH:MM:SS.sss"
)

# Sorteer op tijd
sort!(df, :times)

# (Optioneel) sanity check
if nrow(df) != 8760
    @warn "Aantal rijen is $(nrow(df)), geen 8760. Controleer DST/leap of harmoniseer tijd."
end

# ========= VARIATIE-DRAAGGOLF UIT SYSTEM LOAD =========
@assert hasproperty(df, col_system_load) "Kolom '$(col_system_load)' ontbreekt."
system_MW = Float64.(coalesce.(df[!, col_system_load], 0.0))
base_shape = system_MW ./ (mean(system_MW) + eps())    # dimensieloos, mean ≈ 1

# ========= UURVORM PER SEGMENT =========
hrs = hour.(df.times)

sh_high = [daily_shape_high(h) for h in hrs]; sh_high ./= (mean(sh_high) + eps())
sh_med  = [daily_shape_med(h)  for h in hrs]; sh_med  ./= (mean(sh_med)  + eps())
sh_low  = [daily_shape_low(h)  for h in hrs]; sh_low  ./= (mean(sh_low)  + eps())

# Combineer jaar- en dagvorm (nog dimensieloos)
curve_high = base_shape .* sh_high
curve_med  = base_shape .* sh_med
curve_low  = base_shape .* sh_low

# ========= SCHALEN NAAR DOELGEMIDDELDE (MW/cons) =========
scale_high = target_avg_MW_per_cons_high   / (mean(curve_high) + eps())
scale_med  = target_avg_MW_per_cons_medium / (mean(curve_med)  + eps())
scale_low  = target_avg_MW_per_cons_low    / (mean(curve_low)  + eps())

df.CONS_HIGH   = curve_high .* scale_high      # MW per consument
df.CONS_MEDIUM = curve_med  .* scale_med       # MW per consument
df.CONS_LOW    = curve_low  .* scale_low       # MW per consument

# ========= SOLAR-SEGMENTATIE =========
if hasproperty(df, :SOLAR)
    # 1) Hernoem bestaande kolom
    rename!(df, :SOLAR => :SOLAR_SOUTH)

    hrs = hour.(df.times)
    west_factor = 0.8 .+ 0.4 .* exp.(-0.5 .* ((hrs .- 16) ./ 3).^2)
    df.SOLAR_WEST = df.SOLAR_SOUTH .* (west_factor ./ mean(west_factor))
end

# ========= VERWIJDER ONGEWENSTE KOLOMMEN =========
deletecols = [:DA_PRICES, :LOAD_H2, :ELASTICITY_EL]
for c in deletecols
    if hasproperty(df, c)
        select!(df, Not(c))
    end
end


# ========= SAVE =========
CSV.write(output_path, df)
println("✅ Klaar → $(output_path)")
println("Toegevoegd (MW/cons): CONS_LOW, CONS_MEDIUM, CONS_HIGH")

"""
    make_res_scenario_gamma(df; cols, scenario=:high, gamma_high=0.85, gamma_low=1.20)

Maakt een *kopie* van `df` en vervangt in `cols` de AF-waarden met een gamma-transformatie:
- :high  -> base.^gamma_high (γ<1 duwt omhoog)
- :low   -> base.^gamma_low  (γ>1 duwt omlaag)
Alle overige kolommen (incl. cons_low/med/high) blijven ongewijzigd.
Waarden worden geclamped naar [0,1].
"""
function make_res_scenario_gamma(df;
    cols = [:WIND_ONSHORE, :WIND_OFFSHORE, :SOLAR_SOUTH, :SOLAR_WEST],
    scenario::Symbol = :high,
    gamma_high::Float64 = 0.85,
    gamma_low::Float64  = 1.20
)
    df_new = deepcopy(df)
    for c in cols
        @assert hasproperty(df, c) "Kolom '$(c)' ontbreekt."
        base = Float64.(coalesce.(df[!, c], 0.0))
        arr = scenario === :high ? base .^ gamma_high :
              scenario === :low  ? base .^ gamma_low  :
              error("scenario moet :high of :low zijn")
        df_new[!, c] = clamp.(arr, 0.0, 1.0)
    end
    return df_new
end

# ====== SCENARIO’S AANMAKEN EN WEGSCHRIJVEN ======
af_cols = [:WIND_ONSHORE, :WIND_OFFSHORE, :SOLAR_SOUTH, :SOLAR_WEST]

# Pas gamma-waardes aan naar wens:
γ_high = 0.85   # gunstig RES-jaar (omhoog)
γ_low  = 1.20   # ongunstig RES-jaar (omlaag)

df_high = make_res_scenario_gamma(df; cols=af_cols, scenario=:high, gamma_high=γ_high, gamma_low=γ_low)
df_low  = make_res_scenario_gamma(df; cols=af_cols, scenario=:low,  gamma_high=γ_high, gamma_low=γ_low)

CSV.write(joinpath("Input","timeseries","$(year)","timeseries_$(year)_high.csv"), df_high)
CSV.write(joinpath("Input","timeseries","$(year)","timeseries_$(year)_low.csv"),  df_low)

println("✅ Gamma-scenario’s geschreven:")
println(" - Input/timeseries/$(year)/timeseries_$(year)_high.csv   (γ_high = ", γ_high, ")")
println(" - Input/timeseries/$(year)/timeseries_$(year)_low.csv    (γ_low  = ", γ_low,  ")")

