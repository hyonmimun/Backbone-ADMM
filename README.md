This code is developed to investigate whether consumer-side hedging through a pooled Contracts-for-Difference (CfDs) provides efficient protection for residential electricity consumers facing price volatility. In this approach, risk-averse households can financially hedge against high electricity prices by entering into a pooled CfD contract with a pool of RES generators. To assess the effectiveness of the pooled CfD instrument, a stylized long-term equilibrium model is developed that captures the interaction between risk-averse consumer and generator agents under uncertainty. The model adopts a non-cooperative game-theoretic framework, where the equilibrium is formulated as a Nash equilibrium. The system is solved using the Alternating Direction Method of Multipliers (ADMM), an iterative optimization algorithm suited for decomposing large-scale optimization problems and enabling parallel computation. The model allows for the evaluation of how financial instruments like pooled CfDs affect agent behavior. A simple capability-based CfD is designed and assessed on its effectiveness in mitigating consumer price risk. Agent risk-aversion is quantified by the CVAR metric, which measures consumer and generator downside risk. Stochasticity is introduced by testing the model on 9 discrete scenarios. These scenarios reflect different years with high and low solar radiation and wind availability. The fluctuations in RES availability reflect the weather-driven variability in RES output that induces electricity price volatility. Computing the equilibrium problem by the application of the ADMM is performed in programming language Julia and using the JuMP library. The subproblems are solved iteratively using Gurobi optimizer. The model is built and expanded on an existing backbone model by Dr.Ir. K. Bruninx. The backbone code includes the set-up for the ADMM algorithm for a stylized Energy-Only-Market. The model has been extended to a stochastic model with risk averse agents and a market for pooled CfDs.

The code accompanies the following thesis: "Hedging the Household: Pooled Contracts-for-Differences".

_**Abstract:**
This thesis investigates whether hedging price risk through pooled Contracts-for-Differences (CfDs) can provide efficient consumer protection. The study focuses on financial risk stemming from weather-induced RES variability that drives price volatility in decarbonizing electricity markets. A stylized long-term equilibrium model is developed to study the interactions between risk-averse household consumers and renewable energy generators under uncertainty. The model adopts a non-cooperative game-theoretic framework of which the solution is a Nash equilibrium and is solved using the Alternating Direction Method of Multipliers (ADMM). The pooled CfD is evaluated against five key performance indicators (KPIs): Market Efficiency, Risk Allocation, Targeting of Vulnerable Consumers, Energy Savings and Fiscal Sustainability. These KPIs are derived from examining the implications of past protection policies in light of the recent energy crisis. The modeling results show how pooled CfDs significantly reduce downside risk for household consumers and provide revenue stability for generators. Household consumers see reduced risk and increased expected values, whilst the RES pool generators see lowered expected returns. Pooling RES generation reduces volume and profile risks, improving hedge effectiveness to the household consumer. The findings of this study suggest that well-designed pooled CfDs can support consumer protection in liberalized electricity markets, but real-world implementation must consider the equity and design challenges._

## Installation, hardware & software requirements
### Installation
After downloading the repository, no specific installation is required. The user should, however, have the following software installed to be able to execute the program:
- Julia (https://julialang.org/downloads/)
- Gurobi (https://www.gurobi.com/) and have a license for this solver. If the user doesn't have access to Gurobi, any alternative (open source) solver capable of solving quadratic programming problems can be used. 

The program can be executed in the Julia terminal. Any text editor can be used to modify the code. However, it may be more convenient to use an IDE such as Visual Studio Code (https://code.visualstudio.com/).

### Software requirements: 
This code has been developed using Julia v1.11.6 The solver used is Gurobi v.12.0

The following Julia packages are required:
- JuMP
- Gurobi
- DataFrames
- CSV
- YAML
- DataStructures
- ProgressBars
- Printf
- TimerOutputs
- ArgParse

### Hardware requirements 
No specific hardware is required. Depending on the configuration (number of agents and markets considered), computational effort may significantly increase.

## Running the program
### Input
The file "config.yaml" contains a number of input parameters that are common to all scenarios. These includes general parameters for the simulation, for the algorithm and technologies parameters.

In particular, to obtain the results presented in the thesis the user can modify:
1. The weight of risk measure "gamma", in order to choose between the risk-averse (gamma = 0.5) and risk-neutral (gamma = 1) setups.
2. The risk aversion parametrization "beta", in order to set the degree of risk aversion considered by the CVAR measure (0.2 <= beta <= 1).

The ADMM parameters may require tuning depending on the degree of risk aversion chosen.

### Executing the code
The code can be run by executing the "MAIN.jl" file.