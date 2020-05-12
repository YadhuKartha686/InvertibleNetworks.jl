# Invertible HINT coupling layer from Kruse et al. (2020)
# Author: Philipp Witte, pwitte3@gatech.edu
# Date: January 2020

export CouplingLayerHINT

"""
    H = CouplingLayerHINT(nx, ny, n_in, n_hidden, batchsize;
        logdet=false, permute="none", k1=3, k2=3, p1=1, p2=1, s1=1, s2=1) (2D)

    H = CouplingLayerHINT(nx, ny, nz, n_in, n_hidden, batchsize;
        logdet=false, permute="none", k1=3, k2=3, p1=1, p2=1, s1=1, s2=1) (3D)

 Create a recursive HINT-style invertible layer based on coupling blocks.

 *Input*:

 - `nx`, `ny`, `nz`: spatial dimensions of input

 - `n_in`, `n_hidden`: number of input and hidden channels

 - `logdet`: bool to indicate whether to return the log determinant. Default is `false`.

 - `permute`: string to specify permutation. Options are `"none"`, `"lower"`, `"both"` or `"full"`.

 - `k1`, `k2`: kernel size of convolutions in residual block. `k1` is the kernel of the first and third
    operator, `k2` is the kernel size of the second operator.

 - `p1`, `p2`: padding for the first and third convolution (`p1`) and the second convolution (`p2`)

 - `s1`, `s2`: stride for the first and third convolution (`s1`) and the second convolution (`s2`)

 *Output*:

 - `H`: Recursive invertible HINT coupling layer.

 *Usage:*

 - Forward mode: `Y = H.forward(X)`

 - Inverse mode: `X = H.inverse(Y)`

 - Backward mode: `ΔX, X = H.backward(ΔY, Y)`

 *Trainable parameters:*

 - None in `H` itself

 - Trainable parameters in coupling layers `H.CL`

 See also: [`CouplingLayerBasic`](@ref), [`ResidualBlock`](@ref), [`get_params`](@ref), [`clear_grad!`](@ref)
"""
struct CouplingLayerHINT <: NeuralNetLayer
    CL::AbstractArray{CouplingLayerBasic, 1}
    C::Union{Conv1x1, Nothing}
    logdet::Bool
    forward::Function
    inverse::Function
    backward::Function
    permute_type::String
    is_inverse::Bool
end

# Get layer depth for recursion
function get_depth(n_in)
    count = 0
    nc = n_in
    while nc > 4
        nc /= 2
        count += 1
    end
    return count +1
end

# 2D Constructor from input dimensions
function CouplingLayerHINT(nx::Int64, ny::Int64, n_in::Int64, n_hidden::Int64, batchsize::Int64;
    logdet=false, permute="none", k1=3, k2=3, p1=1, p2=1, s1=1, s2=1)

    # Create basic coupling layers
    n = get_depth(n_in)
    CL = Array{CouplingLayerBasic}(undef, n)
    for j=1:n
        CL[j] = CouplingLayerBasic(nx, ny, Int(n_in/2^j), n_hidden, batchsize;
            k1=k1, k2=k2, p1=p1, p2=p2, s1=s1, s2=s2, logdet=logdet)
    end

    # Permutation using 1x1 convolution
    if permute == "full" || permute == "both"
        C = Conv1x1(n_in)
    elseif permute == "lower"
        C = Conv1x1(Int(n_in/2))
    else
        C = nothing
    end

    return CouplingLayerHINT(CL, C, logdet,
        X -> forward_hint(X, CL, C; logdet=logdet, permute=permute),
        (Y; logdet=false) -> inverse_hint(Y, CL, C; logdet=logdet, permute=permute),
        (ΔY, Y) -> backward_hint(ΔY, Y, CL, C; permute=permute),
        permute,
        false
        )
end

# 3D Constructor from input dimensions
function CouplingLayerHINT(nx::Int64, ny::Int64, nz::Int64, n_in::Int64, n_hidden::Int64, batchsize::Int64;
    logdet=false, permute="none", k1=3, k2=3, p1=1, p2=1, s1=1, s2=1)

    # Create basic coupling layers
    n = get_depth(n_in)
    CL = Array{CouplingLayerBasic}(undef, n)
    for j=1:n
        CL[j] = CouplingLayerBasic(nx, ny, nz, Int(n_in/2^j), n_hidden, batchsize;
            k1=k1, k2=k2, p1=p1, p2=p2, s1=s1, s2=s2, logdet=logdet)
    end

    # Permutation using 1x1 convolution
    if permute == "full" || permute == "both"
        C = Conv1x1(n_in)
    elseif permute == "lower"
        C = Conv1x1(Int(n_in/2))
    else
        C = nothing
    end

    return CouplingLayerHINT(CL, C, logdet,
        X -> forward_hint(X, CL, C; logdet=logdet, permute=permute),
        (Y; logdet=false) -> inverse_hint(Y, CL, C; logdet=logdet, permute=permute),
        (ΔY, Y) -> backward_hint(ΔY, Y, CL, C; permute=permute),
        permute,
        false
        )
end

# Input is tensor X
function forward_hint(X, CL, C; scale=1, logdet=false, permute="none")
    permute == "full" || permute == "both" && (X = C.forward(X))
    Xa, Xb = tensor_split(X)
    permute == "lower" && (Xb = C.forward(Xb))

    recursive = false
    if typeof(X) == Array{Float32, 4} && size(X, 3) > 4
        recursive = true
    elseif typeof(X) == Array{Float32, 5} && size(X, 4) > 4
        recursive = true
    end

    if recursive
        # Call function recursively
        Ya, logdet1 = forward_hint(Xa, CL, C; scale=scale+1, logdet=logdet)
        Y_temp, logdet2 = forward_hint(Xb, CL, C; scale=scale+1, logdet=logdet)
        if logdet==false
            Yb = CL[scale].forward(Xa, Y_temp)[2]
            logdet3 = 0f0
        else
            Yb, logdet3 = CL[scale].forward(Xa, Y_temp)[[2,3]]
        end
        logdet_full = logdet1 + logdet2 + logdet3
    else
        # Finest layer
        Ya = copy(Xa)
        if logdet==false
            Yb = CL[scale].forward(Xa, Xb)[2]
            logdet_full = 0f0
        else
            Yb, logdet_full = CL[scale].forward(Xa, Xb)[[2,3]]
        end
    end
    Y = tensor_cat(Ya, Yb)
    permute == "both" && (Y = C.inverse(Y))
    if scale==1 && logdet==false
        return Y
    else
        return Y, logdet_full
    end
end

# Input is tensor Y
function inverse_hint(Y, CL, C; scale=1, logdet=false, permute="none")
    permute == "both" && (Y = C.forward(Y))
    Ya, Yb = tensor_split(Y)
    recursive = false
    if typeof(Y) == Array{Float32, 4} && size(Y, 3) > 4
        recursive = true
    elseif typeof(Y) == Array{Float32, 5} && size(Y, 4) > 4
        recursive = true
    end
    if recursive
        Xa, logdet1 = inverse_hint(Ya, CL, C; scale=scale+1, logdet=logdet)
        if logdet==false
            Y_temp = CL[scale].inverse(Xa, Yb)[2]
            logdet2 = 0f0
        else
            Y_temp, logdet2 = CL[scale].inverse(Xa, Yb; logdet=true)[[2,3]]
        end
        Xb, logdet3 = inverse_hint(Y_temp, CL, C; scale=scale+1, logdet=logdet)
        logdet_full = logdet1 + logdet2 + logdet3
    else
        Xa = copy(Ya)
        if logdet == false
            Xb = CL[scale].inverse(Ya, Yb)[2]
            logdet_full = 0f0
        else
            Xb, logdet_full = CL[scale].inverse(Ya, Yb; logdet=true)[[2,3]]
        end
    end
    permute == "lower" && (Xb = C.inverse(Xb))
    X = tensor_cat(Xa, Xb)
    permute == "full" || permute == "both" && (X = C.inverse(X))

    if scale==1 && logdet==false
        return X
    else
        return X, logdet_full
    end
end

# Input are two tensors ΔY, Y
function backward_hint(ΔY, Y, CL, C; scale=1, permute="none")
    permute == "both" && ((ΔY, Y) = C.forward((ΔY, Y)))
    Ya, Yb = tensor_split(Y)
    ΔYa, ΔYb = tensor_split(ΔY)
    recursive = false
    if typeof(Y) == Array{Float32, 4} && size(Y, 3) > 4
        recursive = true
    elseif typeof(Y) == Array{Float32, 5} && size(Y, 4) > 4
        recursive = true
    end
    if recursive
        ΔXa, Xa = backward_hint(ΔYa, Ya, CL, C; scale=scale+1)
        ΔXa_temp, ΔXb_temp, X_temp = CL[scale].backward(ΔXa.*0f0, ΔYb, Xa, Yb)[[1,2,4]]
        ΔXb, Xb = backward_hint(ΔXb_temp, X_temp, CL, C; scale=scale+1)
        ΔXa += ΔXa_temp
    else
        Xa = copy(Ya)
        ΔXa = copy(ΔYa)
        ΔXa_, ΔXb, Xb = CL[scale].backward(ΔYa.*0f0, ΔYb, Ya, Yb)[[1,2,4]]
        ΔXa += ΔXa_
    end
    permute == "lower" && ((ΔXb, Xb) = C.inverse((ΔXb, Xb)))
    ΔX = tensor_cat(ΔXa, ΔXb)
    X = tensor_cat(Xa, Xb)
    permute == "full" || permute == "both" && ((ΔX, X) = C.inverse((ΔX, X)))
    return ΔX, X
end

# Input are two tensors ΔX, X
function backward_hint_inv(ΔX, X, CL, C; scale=1, permute="none")

    permute == "full" || permute == "both" && ((ΔX, X) = C.forward((ΔX, X)))
    ΔXa, ΔXb = tensor_split(ΔX)
    Xa, Xb = tensor_split(X)
    permute == "lower" && ((ΔXb, Xb) = C.forward((ΔXb, Xb)))

    recursive = false
    if typeof(X) == Array{Float32, 4} && size(X, 3) > 4
        recursive = true
    elseif typeof(X) == Array{Float32, 5} && size(X, 4) > 4
        recursive = true
    end

    if recursive
        ΔY_temp, Y_temp = backward_hint_inv(ΔXb, Xb, CL, C; scale=scale+1)
        ΔYa_temp, ΔYb, Yb = coupling_layer_backward_inv(0f0.*ΔXa, ΔY_temp, Xa, Y_temp, CL[scale].RB, CL[scale].logdet)[[1,2,4]]
        ΔYa, Ya = backward_hint_inv(ΔXa+ΔYa_temp, Xa, CL, C; scale=scale+1)
    else
        ΔYa = copy(ΔXa)
        Ya = copy(Xa)
        ΔYa_temp, ΔYb, Yb = coupling_layer_backward_inv(0f0.*ΔYa, ΔXb, Xa, Xb, CL[scale].RB, CL[scale].logdet)[[1,2,4]]
        ΔYa += ΔYa_temp
    end
    ΔY = tensor_cat(ΔYa, ΔYb)
    Y = tensor_cat(Ya, Yb)
    permute == "both" && ((ΔY, Y) = C.inverse((ΔY, Y)))
    return ΔY, Y
end

# Clear gradients
function clear_grad!(H::CouplingLayerHINT)
    for j=1:length(H.CL)
        clear_grad!(H.CL[j])
    end
    ~isnothing(H.C) && clear_grad!(H.C)
end

# Get parameters
function get_params(H::CouplingLayerHINT)
    nlayers = length(H.CL)
    p = get_params(H.CL[1])
    if nlayers > 1
        for j=2:nlayers
            p = cat(p, get_params(H.CL[j]); dims=1)
        end
    end
    ~isnothing(H.C) && (p = cat(p, get_params(H.C); dims=1))
    return p
end

# Inverse network
function inverse(L::CouplingLayerHINT)
    if L.is_inverse == true
        return CouplingLayerHINT(L.CL, L.C, L.logdet,
            X -> forward_hint(X, L.CL, L.C; logdet=L.logdet, permute=L.permute_type),
            (Y; logdet=false) -> inverse_hint(Y, L.CL, L.C; logdet=logdet, permute=L.permute_type),
            (ΔY, Y) -> backward_hint(ΔY, Y, L.CL, L.C; permute=L.permute_type),
            L.permute_type,
            false
            )
    elseif L.is_inverse == false
        return CouplingLayerHINT(L.CL, L.C, L.logdet,
            Y -> inverse_hint(Y, L.CL, L.C; logdet=L.logdet, permute=L.permute_type),
            (X; logdet=false) -> forward_hint(X, L.CL, L.C; logdet=logdet, permute=L.permute_type),
            (ΔX, X) -> backward_hint_inv(ΔX, X, L.CL, L.C; permute=L.permute_type),
            L.permute_type,
            true
            )
    end
end
