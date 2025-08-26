function define_common_parameters!(m::String,mod::Model, data::Dict, ts::Dict, agents::Dict, scenario_overview_row::DataFrameRow,market_design::AbstractString, repr_days::Dict)    # Solver settings
    # Define dictonaries for sets, parameters, timeseries, variables, constraints & expressions
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
    idx(jy, jd, jh) = nT * (repr_days[jy][!,:periods][jd] - 1) + jh

    # Parameters
    mod.ext[:parameters][:W] = [repr_days[jy][!, :weights][jd] for jd in mod.ext[:sets][:JD], jy in mod.ext[:sets][:JY]] # weights of each representative day
    #mod.ext[:parameters][:P] = ones(data["General"]["nYears"]) / data["General"]["nYears"] # probability of each scenario - uniform distribution
    #mod.ext[:parameters][:γ] = data["gamma"] # weight of expected revenues and CVAR
    #mod.ext[:parameters][:β] = data["beta"]  # beta: risk aversion parameter - represents the cumulative probability of worst-case scenarios
  
    # Parameters related to the EOM
    mod.ext[:parameters][:λ_EOM] = zeros(nT,nR,nY)   # Price structure
    mod.ext[:parameters][:g_bar] = zeros(nT,nR,nY)   # ADMM penalty term
    mod.ext[:parameters][:ρ_EOM] = data["ADMM"]["rho_EOM"]

    if market_design == "CfD"
    # Parameters related to the CfD
        mod.ext[:parameters][:ζ_cfd] = 0.0 # CfD premium
        mod.ext[:parameters][:Q_cfd_bar] = 0.0 # ADMM penalty term related to the CfD
        mod.ext[:parameters][:ρ_cfd] = data["CfD"]["rho_cfd"]
    end

    return mod, agents
end