function define_common_parameters!(m::String,mod::Model, data::Dict, ts::Dict, agents::Dict, scenario_overview_row::DataFrameRow,market_design::AbstractString, repr_days::Dict)    # Solver settings
    # Define dictionaries for sets, parameters, timeseries, variables, constraints & expressions
    mod.ext[:sets] = Dict()
    mod.ext[:parameters] = Dict()
    mod.ext[:timeseries] = Dict()
    mod.ext[:variables] = Dict()
    mod.ext[:constraints] = Dict()
    mod.ext[:expressions] = Dict()

    # Sets
    mod.ext[:sets][:JY] = 1:data["General"]["nYears"]
    mod.ext[:sets][:JD] = 1:data["General"]["nReprDays"]
    mod.ext[:sets][:JH] = 1:data["General"]["nTimesteps"]

    nT = data["General"]["nTimesteps"]
    nR = data["General"]["nReprDays"]
    nY = data["General"]["nYears"]
    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh # get absolute timestep in repr days in year

    # Parameters
    mod.ext[:parameters][:W] = [repr_days[jy][!, :weights][jd] for jd in mod.ext[:sets][:JD], jy in mod.ext[:sets][:JY]] # weights of each representative day
    mod.ext[:parameters][:P] = ones(data["General"]["nYears"]) / data["General"]["nYears"] # probability of each scenario - uniform distribution
    mod.ext[:parameters][:β] = data["General"]["beta"] # risk aversion parameter - represents the cumulative probability of worst-case scenarios
    mod.ext[:parameters][:γ] = data["General"]["gamma"]     # weight of expected revenues and CVAR
    
    # Parameters related to the EOM
    mod.ext[:parameters][:λ_EOM] = zeros(nT,nR,nY)   # Price structure
    mod.ext[:parameters][:g_bar] = zeros(nT,nR,nY)   # ADMM penalty term
    mod.ext[:parameters][:ρ_EOM] = data["ADMM"]["rho_EOM"]
    
    if market_design == "cfd"
    # Parameters related to the cfd
        mod.ext[:parameters][:ζ_cfd] = 0 # 10^6€/GW/year
        mod.ext[:parameters][:λ_cfd] = data["cfd"]["lambda_cfd"] # 10^6 €/GWh (strike price)
        mod.ext[:parameters][:Q_cfd_bar] = 0 #  GW/year
        mod.ext[:parameters][:ρ_cfd] = data["cfd"]["rho_cfd"] # 10^6 €/GW
    end

    return mod, agents
end