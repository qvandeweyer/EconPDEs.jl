##############################################################################
##
## Type
##
##############################################################################

type BansalYaronModel  <: EconPDEModel
    # consumption process parameters
    μbar::Float64 
    νD::Float64
    κμ::Float64 
    κσ::Float64 
    νμ::Float64 
    νσ::Float64 

    # utility parameters
    ρ::Float64  
    γ::Float64 
    ψ::Float64
end

function BansalYaronModel(;μbar = 0.018, νD = 0.025, κμ = 0.3, κσ = 0.012, νμ = 0.0114, νσ = 0.189, ρ = 0.0132, γ = 7.5, ψ = 1.5)
    BansalYaronModel(μbar, νD, κμ, κσ, νμ, νσ, ρ, γ, ψ)
end

function StateGrid(apm::BansalYaronModel; μn = 30, σn = 30)
    μbar = apm.μbar ; νD = apm.νD ; κμ = apm.κμ ; κσ = apm.κσ ; νμ = apm.νμ ; νσ = apm.νσ ; ρ = apm.ρ ; γ = apm.γ ; ψ = apm.ψ

    σ = sqrt(νσ^2 / (2 * κσ))
    σmin = max(0.01, quantile(Normal(1.0, σ), 0.001))
    σmax = quantile(Normal(1.0, σ), 0.999)
    σs = collect(linspace(σmin, σmax, σn))

    σ = sqrt(νμ^2 / (2 * κμ))
    μmin = quantile(Normal(μbar, σ), 0.001)
    μmax = quantile(Normal(μbar, σ), 0.999)
    μs = collect(linspace(μmin, μmax, μn))

    StateGrid(μ = μs, σ = σs)
end

function initialize(apm::BansalYaronModel, grid::StateGrid)
    fill(1.0, size(grid)...)
end
	
function derive(apm::BansalYaronModel, stategrid::StateGrid, y::ReflectingArray, ituple, drifti = (0.0, 0.0))
    iμ, iσ = ituple[1], ituple[2]
    μμ, μσ = drifti
    Δμ, Δσ = stategrid.Δx
    p = y[iμ, iσ]
    if μμ >= 0.0
        pμ = (y[iμ + 1, iσ] - y[iμ, iσ]) / Δμ[iμ]
    else
        pμ = (y[iμ, iσ] - y[iμ - 1, iσ]) / Δμ[iμ]
    end
    if μσ >= 0.0
        pσ = (y[iμ, iσ + 1] - y[iμ, iσ]) / Δσ[iσ]
    else
        pσ = (y[iμ, iσ] - y[iμ, iσ - 1]) / Δσ[iσ]
    end
    pμμ =  (y[iμ + 1, iσ] + y[iμ - 1, iσ] - 2 * y[iμ, iσ]) / Δμ[iμ]^2
    pσσ =  (y[iμ, iσ + 1] + y[iμ, iσ - 1] - 2 * y[iμ, iσ]) / Δσ[iσ]^2
    return p, pμ, pσ, pμμ, pσσ
end

function pde(apm::BansalYaronModel, gridi, functionsi)
    μbar = apm.μbar ; νD = apm.νD ; κμ = apm.κμ ; κσ = apm.κσ ; νμ = apm.νμ ; νσ = apm.νσ ; ρ = apm.ρ ; γ = apm.γ ; ψ = apm.ψ
    μ, σ = gridi
    p, pμ, pσ, pμμ, pσσ = functionsi
    μC = μ
    σC = νD * sqrt(σ)
    μμ = κμ * (μbar - μ)
    σμ = νμ * sqrt(σ)
    μσ = κσ * (1 - σ)
    σσ = νσ 
    σpμ = pμ / p * σμ
    σpσ = pσ / p * σσ
    σp2 = σpμ^2 + σpσ^2
    μp = pμ / p * μμ + pσ / p * μσ + 0.5 * pμμ / p * σμ^2 + 0.5 * pσσ / p * σσ^2
    out = p * (1 / p - ρ + (1 - 1 / ψ) * (μC - 0.5 * γ * σC^2) + μp + 0.5 * (1 / ψ - γ) / (1 - 1 / ψ) * σp2)
    return out, (μμ, μσ), (:p => p,)
end
