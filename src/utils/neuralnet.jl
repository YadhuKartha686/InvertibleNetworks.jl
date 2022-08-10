export NeuralNetLayer, InvertibleNetwork, ReverseLayer, ReverseNetwork
export get_grads

# Base Layer and network types with property getters

abstract type NeuralNetLayer end

abstract type InvertibleNetwork end

function Base.show(io::IO, m::Union{NeuralNetLayer, InvertibleNetwork}) 
    println(typeof(m))
end

function convert_params!(::Type{T}, obj::Union{NeuralNetLayer, InvertibleNetwork}) where T
    for p ∈ get_params(obj)
        convert_param!(T, p)
    end
end

input_type(x::AbstractArray) = eltype(x)
input_type(x::Tuple) = eltype(x[1])

function _predefined_mode(obj, sym::Symbol, args...; kwargs...)
    convert_params!(input_type(args[1]), obj)
    eval(sym)(args..., obj; kwargs...)
end

_INet_modes = [:forward, :inverse, :backward, :inverse_Y, :forward_Y,
               :jacobian, :jacobianInverse, :adjointJacobian, :adjointJacobianInverse]

function Base.getproperty(obj::Union{InvertibleNetwork,NeuralNetLayer}, sym::Symbol)
    if sym ∈ _INet_modes
        return (args...; kwargs...) -> _predefined_mode(obj, sym, args...; kwargs...)
    else
         # fallback to getfield
        return getfield(obj, sym)
    end
end

abstract type ReverseLayer end

_RNet_modes = Dict(:forward=>:inverse, :inverse=>:forward,
                   :backward=>:backward_inv,
                   :inverse_Y=>:forward_Y, :forward_Y=>:inverse_Y)

function Base.getproperty(obj::ReverseLayer, sym::Symbol)
    if sym ∈ keys(_RNet_modes)
        return (args...; kwargs...) -> _predefined_mode(obj.layer, _RNet_modes[sym], args...; kwargs...)
    elseif sym == :layer
        return getfield(obj, sym)
    else
         # fallback to getfield
        return getfield(obj.layer, sym)
    end
end


struct Reverse <: ReverseLayer
    layer::NeuralNetLayer
end

function reverse(L::NeuralNetLayer)
    L_rev = deepcopy(L)
    tag_as_reversed!(L_rev, true)
    return Reverse(L_rev)
end

function reverse(RL::ReverseLayer)
    R = deepcopy(RL)
    tag_as_reversed!(R.layer, false)
    return R.layer
end

abstract type ReverseNetwork end

function Base.getproperty(obj::ReverseNetwork, sym::Symbol)
    if sym ∈ keys(_RNet_modes)
        return (args...; kwargs...) -> _predefined_mode(obj.network, _RNet_modes[sym], args...; kwargs...)
    elseif sym == :network
        return getfield(obj, sym)
    else
         # fallback to getfield
        return getfield(obj.network, sym)
    end
end


struct ReverseNet <: ReverseNetwork
    network::InvertibleNetwork
end

using Zygote: @adjoint
(G::ReverseNet)(z::Vector) = G.network.inverse(z)
@adjoint function(G::ReverseNet)(z::Vector)
    x = G.network.inverse(z)
    return x, Δ -> (nothing, reverse(G.network).backward(Δ,x)[1])
end

function reverse(N::InvertibleNetwork)
    N_rev = deepcopy(N)
    tag_as_reversed!(N_rev, true)
    return ReverseNet(N_rev)
end

function reverse(RN::ReverseNetwork)
    R = deepcopy(RN)
    tag_as_reversed!(R.network, false)
    return R.network
end

# Clear grad functionality for reversed layers/networks

function clear_grad!(RL::ReverseLayer)
    clear_grad!(RL.layer)
end


function clear_grad!(RN::ReverseNetwork)
    clear_grad!(RN.network)
end

# Get params for reversed layers/networks

function get_params(RL::ReverseLayer)
    return get_params(RL.layer)
end

function get_params(RN::ReverseNetwork)
    return get_params(RN.network)
end

function get_grads(N::Union{NeuralNetLayer, InvertibleNetwork})
    return get_grads(get_params(N))
end

function get_grads(RL::ReverseLayer)
    return get_grads(RL.layer)
end

function get_grads(RN::ReverseNetwork)
    return get_grads(RN.network)
end

# Set parameters

function set_params!(N::Union{NeuralNetLayer, InvertibleNetwork}, θnew::Array{Parameter, 1})
    set_params!(get_params(N), θnew)
end

# Set params for reversed layers/networks

function set_params!(RL::ReverseLayer, θ::Array{Parameter, 1})
    return set_params!(RL.layer, θ)
end

function set_params!(RN::ReverseNetwork, θ::Array{Parameter, 1})
    return set_params!(RN.network, θ)
end

# Make invertible nets callable objects
(N::Union{NeuralNetLayer,InvertibleNetwork,Reverse,ReverseNet})(X::AbstractArray{T,N} where {T, N}) = N.forward(X)
