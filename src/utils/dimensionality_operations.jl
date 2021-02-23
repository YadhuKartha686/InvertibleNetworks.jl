# Dimensionality operations for 4D Tensors
# Author: Philipp Witte, pwitte3@gatech.edu
# Date: January 2020

export squeeze, unsqueeze, wavelet_squeeze, wavelet_unsqueeze, Haar_squeeze, invHaar_unsqueeze, tensor_split, tensor_cat

####################################################################################################
# Squeeze and unsqueeze

"""
    Y = squeeze(X; pattern="column")

 Reshape input image such that each spatial dimension is reduced by a factor
 of 2, while the number of channels is increased by a factor of 4.

 *Input*:

 - `X`: 4D input tensor of dimensions `nx` x `ny` x `n_channel` x `batchsize`

 - `pattern`: Squeezing pattern

        1 2 3 4        1 1 3 3        1 3 1 3
        1 2 3 4        1 1 3 3        2 4 2 4
        1 2 3 4        2 2 4 4        1 3 1 3
        1 2 3 4        2 2 4 4        2 4 2 4

        column          patch       checkerboard

 *Output*:

 - `Y`: Reshaped tensor of dimensions `nx/2` x `ny/2` x `n_channel*4` x `batchsize`

 See also: [`unsqueeze`](@ref), [`wavelet_squeeze`](@ref), [`wavelet_unsqueeze`](@ref)
"""
function squeeze(X::AbstractArray{T,4}; pattern="column") where T

    # Dimensions
    nx_in, ny_in, nc_in, batchsize = size(X)
    if mod(nx_in, 2) == 1 || mod(ny_in, 2) == 1
        throw("Input dimensions must be multiple of 2")
    end
    nx_out = Int(round(nx_in/2))
    ny_out = Int(round(ny_in/2))
    nc_out = Int(round(nc_in*4))
    Y = cuzeros(X, nx_out, ny_out, nc_out, batchsize)

    if pattern == "column"
        Y = reshape(X, nx_out, ny_out, nc_out, batchsize)
    elseif pattern == "patch"
        Y[:, :, 1: nc_in, :] = X[1:nx_out, 1:ny_out, :, :]
        Y[:, :, nc_in+1: 2*nc_in, :] = X[nx_out+1:end, 1:ny_out, :, :]
        Y[:, :, 2*nc_in+1: 3*nc_in, :] = X[1:nx_out, ny_out+1:end, :, :]
        Y[:, :, 3*nc_in+1: 4*nc_in, :] = X[nx_out+1:end, ny_out+1:end, :, :]
    elseif pattern == "checkerboard"
        Y[:, :, 1: nc_in, :] = X[1:2:nx_in, 1:2:ny_in, 1:nc_in, :]
        Y[:, :, nc_in+1: 2*nc_in, :] = X[2:2:nx_in, 1:2:ny_in, 1:nc_in, :]
        Y[:, :, 2*nc_in+1: 3*nc_in, :] = X[1:2:nx_in, 2:2:ny_in, 1:nc_in, :]
        Y[:, :, 3*nc_in+1: 4*nc_in, :] = X[2:2:nx_in, 2:2:ny_in, 1:nc_in, :]
    else
        throw("Specified pattern not defined.")
    end
    return Y
end

function squeeze(X::AbstractArray{T,5}; pattern="column") where T

    # Dimensions
    nx_in, ny_in, nz_in, nc_in, batchsize = size(X)
    if mod(nx_in, 2) == 1 || mod(ny_in, 2) == 1
        throw("Input dimensions must be multiple of 2")
    end
    nx_out = Int(round(nx_in/2))
    ny_out = Int(round(ny_in/2))
    nz_out = Int(round(nz_in/2))
    nc_out = Int(round(nc_in*8))
    Y = cuzeros(X, nx_out, ny_out, nz_out, nc_out, batchsize)

    if pattern == "column"
        Y = reshape(X, nx_out, ny_out, nz_out, nc_out, batchsize)
    elseif pattern == "patch"
        Y[:, :, :, 1: nc_in, :] = X[1:nx_out, 1:ny_out, 1:nz_out, :, :]
        Y[:, :, :, nc_in+1: 2*nc_in, :] = X[nx_out+1:end, 1:ny_out, 1:nz_out, :, :]
        Y[:, :, :, 2*nc_in+1: 3*nc_in, :] = X[1:nx_out, ny_out+1:end, 1:nz_out, :, :]
        Y[:, :, :, 3*nc_in+1: 4*nc_in, :] = X[nx_out+1:end, ny_out+1:end, 1:nz_out, :, :]
        Y[:, :, :, 4*nc_in+1: 5*nc_in, :] = X[1:nx_out, 1:ny_out, nz_out+1:end, :, :]
        Y[:, :, :, 5*nc_in+1: 6*nc_in, :] = X[nx_out+1:end, 1:ny_out, nz_out+1:end, :, :]
        Y[:, :, :, 6*nc_in+1: 7*nc_in, :] = X[1:nx_out, ny_out+1:end, nz_out+1:end, :, :]
        Y[:, :, :, 7*nc_in+1: 8*nc_in, :] = X[nx_out+1:end, ny_out+1:end, nz_out+1:end, :, :]
    elseif pattern == "checkerboard"
        throw("Currently not implemented for 5D tensors.")
    else
        throw("Specified pattern not defined.")
    end
    return Y
end


"""
    X = unsqueeze(Y; pattern="column")

 Undo squeezing operation by reshaping input image such that each spatial dimension is
 increased by a factor of 2, while the number of channels is decreased by a factor of 4.

 *Input*:

 - `Y`: 4D input tensor of dimensions `nx` x `ny` x `n_channel` x `batchsize`

 - `pattern`: Squeezing pattern

            1 2 3 4        1 1 3 3        1 3 1 3
            1 2 3 4        1 1 3 3        2 4 2 4
            1 2 3 4        2 2 4 4        1 3 1 3
            1 2 3 4        2 2 4 4        2 4 2 4

            column          patch       checkerboard

 *Output*:

 - `X`: Reshaped tensor of dimensions `nx*2` x `ny*2` x `n_channel/4` x `batchsize`

 See also: [`squeeze`](@ref), [`wavelet_squeeze`](@ref), [`wavelet_unsqueeze`](@ref)
"""
function unsqueeze(Y::AbstractArray{T,4}; pattern="column") where T

    # Dimensions
    nx_in, ny_in, nc_in, batchsize = size(Y)
    if mod(nx_in, 2) == 1 || mod(ny_in, 2) == 1
        throw("Input dimensions must be multiple of 2")
    end
    nx_out = Int(round(nx_in*2))
    ny_out = Int(round(ny_in*2))
    nc_out = Int(round(nc_in/4))
    X = cuzeros(Y, nx_out, ny_out, nc_out, batchsize)

    if pattern == "column"
        X = reshape(Y, nx_out, ny_out, nc_out, batchsize)
    elseif pattern == "patch"
        X[1:nx_in, 1:ny_in, :, :] = Y[:, :, 1: nc_out, :]
        X[nx_in+1:end, 1:ny_in, :, :] = Y[:, :, nc_out+1: 2*nc_out, :]
        X[1:nx_in, ny_in+1:end, :, :] = Y[:, :, 2*nc_out+1: 3*nc_out, :]
        X[nx_in+1:end, ny_in+1:end, :, :] = Y[:, :, 3*nc_out+1: 4*nc_out, :]
    elseif pattern == "checkerboard"
        X[1:2:nx_out, 1:2:ny_out, 1:nc_out, :] = Y[:, :, 1: nc_out, :]
        X[2:2:nx_out, 1:2:ny_out, 1:nc_out, :] = Y[:, :, nc_out+1: 2*nc_out, :]
        X[1:2:nx_out, 2:2:ny_out, 1:nc_out, :] = Y[:, :, 2*nc_out+1: 3*nc_out, :]
        X[2:2:nx_out, 2:2:ny_out, 1:nc_out, :] = Y[:, :, 3*nc_out+1: 4*nc_out, :]
    else
        throw("Specified pattern not defined.")
    end
    return X
end

function unsqueeze(Y::AbstractArray{T,5}; pattern="column") where T

    # Dimensions
    nx_in, ny_in, nz_in, nc_in, batchsize = size(Y)
    if mod(nx_in, 2) == 1 || mod(ny_in, 2) == 1
        throw("Input dimensions must be multiple of 2")
    end
    nx_out = Int(round(nx_in*2))
    ny_out = Int(round(ny_in*2))
    nz_out = Int(round(ny_in*2))
    nc_out = Int(round(nc_in/8))
    X = cuzeros(Y, nx_out, ny_out, nz_out, nc_out, batchsize)

    if pattern == "column"
        X = reshape(Y, nx_out, ny_out, nz_out, nc_out, batchsize)
    elseif pattern == "patch"
        X[1:nx_in, 1:ny_in, 1:nz_in, :, :] = Y[:, :, :, 1: nc_out, :]
        X[nx_in+1:end, 1:ny_in, 1:nz_in, :, :] = Y[:, :, :, nc_out+1: 2*nc_out, :]
        X[1:nx_in, ny_in+1:end, 1:nz_in, :, :] = Y[:, :, :, 2*nc_out+1: 3*nc_out, :]
        X[nx_in+1:end, ny_in+1:end, 1:nz_in, :, :] = Y[:, :, :, 3*nc_out+1: 4*nc_out, :]
        X[1:nx_in, 1:ny_in, nz_in+1:end, :, :] = Y[:, :, :, 4*nc_out+1: 5*nc_out, :]
        X[nx_in+1:end, 1:ny_in, nz_in+1:end, :, :] = Y[:, :, :, 5*nc_out+1: 6*nc_out, :]
        X[1:nx_in, ny_in+1:end, nz_in+1:end, :, :] = Y[:, :, :, 6*nc_out+1: 7*nc_out, :]
        X[nx_in+1:end, ny_in+1:end, nz_in+1:end, :, :] = Y[:, :, :, 7*nc_out+1: 8*nc_out, :]
    elseif pattern == "checkerboard"
        throw("Specified pattern not defined.")
    else
        throw("Specified pattern not defined.")
    end
    return X
end

function unsqueeze(X::AbstractArray{T,N}, Y::AbstractArray{T,4}; pattern="column") where {T,N}
    return unsqueeze(X; pattern=pattern), unsqueeze(Y; pattern=pattern)
end

####################################################################################################
# Squeeze and unsqueeze using the wavelet transform

"""
    Y = wavelet_squeeze(X; type=WT.db1)

 Perform a 1-level channelwise 2D wavelet transform of X and squeeze output of each
 transform into 4 channels (per 1 input channel).

 *Input*:

 - `X`: 4D input tensor of dimensions `nx` x `ny` x `n_channel` x `batchsize`

 - `type`: Wavelet filter type. Possible values are `WT.haar` for Haar wavelets,
    `WT.coif2`, `WT.coif4`, etc. for Coiflet wavelets, or `WT.db1`, `WT.db2`, etc.
    for Daubechies wavetlets. See *https://github.com/JuliaDSP/Wavelets.jl* for a
    full list.

 *Output*:

 - `Y`: Reshaped tensor of dimensions `nx/2` x `ny/2` x `n_channel*4` x `batchsize`

 See also: [`wavelet_unsqueeze`](@ref), [`squeeze`](@ref), [`unsqueeze`](@ref)
"""
function wavelet_squeeze(X::AbstractArray{T,4}; type=WT.db1) where T
    nx_in, ny_in, nc_in, batchsize = size(X)
    nx_out = Int(round(nx_in/2))
    ny_out = Int(round(ny_in/2))
    nc_out = Int(round(nc_in*4))
    Y = cuzeros(X, nx_out, ny_out, nc_out, batchsize)
    for i=1:batchsize
        for j=1:nc_in
            Ycurr = dwt(X[:,:,j,i], wavelet(type), 1)
            Y[:, :, (j-1)*4 + 1: j*4, i] = squeeze(reshape(Ycurr, nx_in, ny_in, 1, 1); pattern="patch")
        end
    end
    return Y
end

function wavelet_squeeze(X::AbstractArray{T,5}; type=WT.db1) where T
    nx_in, ny_in, nz_in, nc_in, batchsize = size(X)
    nx_out = Int(round(nx_in/2))
    ny_out = Int(round(ny_in/2))
    nz_out = Int(round(nz_in/2))
    nc_out = Int(round(nc_in*8))
    Y = cuzeros(X, nx_out, ny_out, nz_out, nc_out, batchsize)
    for i=1:batchsize
        for j=1:nc_in
            Ycurr = dwt(X[:,:,:,j,i], wavelet(type), 1)
            Y[:, :, :, (j-1)*8 + 1: j*8, i] = squeeze(reshape(Ycurr, nx_in, ny_in, nz_in, 1, 1); pattern="patch")
        end
    end
    return Y
end

"""
    X = wavelet_unsqueeze(Y; type=WT.db1)

 Perform a 1-level inverse 2D wavelet transform of Y and unsqueeze output.
 This reduces the number of channels by 4 and increases each spatial
 dimension by a factor of 2. Inverse operation of `wavelet_squeeze`.

 *Input*:

 - `Y`: 4D input tensor of dimensions `nx` x `ny` x `n_channel` x `batchsize`

 - `type`: Wavelet filter type. Possible values are `haar` for Haar wavelets,
  `coif2`, `coif4`, etc. for Coiflet wavelets, or `db1`, `db2`, etc. for Daubechies
  wavetlets. See *https://github.com/JuliaDSP/Wavelets.jl* for a full list.

 *Output*:

 - `X`: Reshaped tensor of dimenions `nx*2` x `ny*2` x `n_channel/4` x `batchsize`

 See also: [`wavelet_squeeze`](@ref), [`squeeze`](@ref), [`unsqueeze`](@ref)
"""
function wavelet_unsqueeze(Y::AbstractArray{T,4}; type=WT.db1) where T
    nx_in, ny_in, nc_in, batchsize = size(Y)
    nx_out = Int(round(nx_in*2))
    ny_out = Int(round(ny_in*2))
    nc_out = Int(round(nc_in/4))
    X = cuzeros(Y, nx_out, ny_out, nc_out, batchsize)
    for i=1:batchsize
        for j=1:nc_out
            Ycurr = unsqueeze(Y[:, :, (j-1)*4 + 1: j*4, i:i]; pattern="patch")[:, :, 1, 1]
            Xcurr = idwt(Ycurr, wavelet(type), 1)
            X[:, :, j, i] = reshape(Xcurr, nx_out, ny_out, 1, 1)
        end
    end
    return X
end

function wavelet_unsqueeze(Y::AbstractArray{T,5}; type=WT.db1) where T
    nx_in, ny_in, nz_in, nc_in, batchsize = size(Y)
    nx_out = Int(round(nx_in*2))
    ny_out = Int(round(ny_in*2))
    nz_out = Int(round(nz_in*2))
    nc_out = Int(round(nc_in/8))
    X = cuzeros(Y, nx_out, ny_out, nz_out, nc_out, batchsize)
    for i=1:batchsize
        for j=1:nc_out
            Ycurr = unsqueeze(Y[:, :, :, (j-1)*8 + 1: j*8, i:i]; pattern="patch")[:, :, :, 1, 1]
            Xcurr = idwt(Ycurr, wavelet(type), 1)
            X[:, :, :, j, i] = reshape(Xcurr, nx_out, ny_out, nz_out, 1, 1)
        end
    end
    return X
end

function HaarLift(x::AbstractArray{T,4},dim) where T
  #Haar lifting

  # Splitting
  if dim==1
    L = x[2:2:end, :, :, :]
    H = x[1:2:end, :, :, :]
  elseif dim==2
    L = x[:,2:2:end, :, :]
    H = x[:,1:2:end, :, :]
  else
    error("dimension for Haar lifting has to be 1 or 2 for a 4D input array")
  end

  # predict
  H .= H .- L

  #update
  L .= L .+ H ./ T(2.0)

  #normalize
  H .= H ./sqrt(T(2.0))
  L .= L.*sqrt(T(2.0))

  return L,H
end

function invHaarLift(L::AbstractArray{T,4},H::AbstractArray{T,4},dim) where T
  #inverse Haar lifting

  #inv normalize
  H .= H .*sqrt(T(2.0))
  L .= L./sqrt(T(2.0))

  #inv update & predict
  L .= L .- H ./ T(2.0)
  H .= L .+ H

  #allocate output:
  x = cat(cuzeros(L,size(L)...), cuzeros(H,size(H)...), dims=dim)

  # merging (inverse split)
  if dim==1
    x[2:2:end, :, :, :] .= L
    x[1:2:end, :, :, :] .= H
  elseif dim==2
    x[:,2:2:end, :, :] .= L
    x[:,1:2:end, :, :] .= H
  else
    error("dimension for Haar lifting has to be 1 or 2 for a 4D input array")
  end

  return x
end

function HaarLift(x::AbstractArray{T,5},dim) where T
  #Haar lifting

  # Splitting
  if dim==1
    L = x[2:2:end, :, :, :, :]
    H = x[1:2:end, :, :, :, :]
  elseif dim==2
    L = x[:,2:2:end, :, :, :]
    H = x[:,1:2:end, :, :, :]
  elseif dim==3
    L = x[:, :, 2:2:end, :, :]
    H = x[:, :, 1:2:end, :, :]
  else
    error("dimension for Haar lifting has to be 1, 2, or 3 for a 5D input array")
  end

  # predict
  H .= H .- L

  #update
  L .= L .+ H ./ T(2.0)

  #normalize
  H .= H ./sqrt(T(2.0))
  L .= L.*sqrt(T(2.0))

  return L,H
end

function invHaarLift(L::AbstractArray{T,5},H::AbstractArray{T,5},dim) where T
  #inverse Haar lifting

  #inv normalize
  H .= H .*sqrt(T(2.0))
  L .= L./sqrt(T(2.0))

  #inv update & predict
  L .= L .- H ./ T(2.0)
  H .= L .+ H

  #allocate output:
  x = cat(cuzeros(L,size(L)...), cuzeros(H,size(H)...), dims=dim)

  # merging (inverse split)
  if dim==1
    x[2:2:end, :, :, :, :] .= L
    x[1:2:end, :, :, :, :] .= H
  elseif dim==2
    x[:,2:2:end, :, :, :] .= L
    x[:,1:2:end, :, :, :] .= H
  elseif dim==3
    x[:, :, 2:2:end, :, :] .= L
    x[:, :, 1:2:end, :, :] .= H
  else
    error("dimension for Haar lifting has to be 1, 2, or 3 for a 5D input array")
  end

  return x
end

"""
    Y = Haar_squeeze(X)

 Perform a 1-level channelwise 2D (lifting) Haar transform of X and squeeze output of each
 transform into 4 channels (per 1 input channel).

 *Input*:

 - `X`: 4D input tensor of dimensions `nx` x `ny` x `n_channel` x `batchsize`

 *Output*:

 - `Y`: Reshaped tensor of dimensions `nx/2` x `ny/2` x `n_channel*4` x `batchsize`

 See also: [`wavelet_unsqueeze`](@ref), [`Haar_unsqueeze`](@ref), [`HaarLift`](@ref), [`squeeze`](@ref), [`unsqueeze`](@ref)
"""
function Haar_squeeze(x::AbstractArray{T,4}) where T

        L,H = HaarLift(x,2)

        a,h = HaarLift(L,1)
        v,d = HaarLift(H,1)

        return cat(a,v,h,d,dims=3)
end

"""
    Y = Haar_squeeze(X)

 Perform a 1-level channelwise 3D (lifting) Haar transform of X and squeeze output of each
 transform into 8 channels (per 1 input channel).

 *Input*:

 - `X`: 5D input tensor of dimensions `nx` x `ny` x `nz` x `n_channel` x `batchsize`

 *Output*:

 - `Y`: Reshaped tensor of dimensions `nx/2` x `ny/2` x `nz/2` x `n_channel*8` x `batchsize`

 See also: [`wavelet_unsqueeze`](@ref), [`Haar_unsqueeze`](@ref), [`HaarLift`](@ref), [`squeeze`](@ref), [`unsqueeze`](@ref)
"""
function Haar_squeeze(x::AbstractArray{T,5}) where T

        L,H = HaarLift(x,2)

        a,h = HaarLift(L,1)
        v,d = HaarLift(H,1)

        al,ah = HaarLift(a,3)
        vl,vh = HaarLift(v,3)
        hl,hh = HaarLift(h,3)
        dl,dh = HaarLift(d,3)

        return cat(ah,al,vh,vl,hh,hl,dh,dl,dims=4)
end

"""
    X = invHaar_unsqueeze(Y)

 Perform a 1-level inverse 2D Haar transform of Y and unsqueeze output.
 This reduces the number of channels by 4 and increases each spatial
 dimension by a factor of 2. Inverse operation of `Haar_squeeze`.

 *Input*:

 - `Y`: 4D input tensor of dimensions `nx` x `ny` x `n_channel` x `batchsize`

 *Output*:

 - `X`: Reshaped tensor of dimenions `nx*2` x `ny*2` x `n_channel/4` x `batchsize`

 See also: [`wavelet_unsqueeze`](@ref), [`Haar_squeeze`](@ref), [`HaarLift`](@ref), [`squeeze`](@ref), [`unsqueeze`](@ref)
"""
function invHaar_unsqueeze(x::AbstractArray{T,4}) where T

        s = size(x,3)

        a = x[:, :, 1:Int(s/4), :]
        v = x[:, :, Int(s/4+1):Int(s/2),:]
        h = x[:, :, Int(s/2+1):Int(3*s/4),:]
        d = x[:, :, Int(3*s/4+1):end,:]

        L = invHaarLift(a,h,1)
        H = invHaarLift(v,d,1)

        x = invHaarLift(L,H ,2)

        return x
end

"""
    X = invHaar_unsqueeze(Y)

 Perform a 1-level inverse 3D Haar transform of Y and unsqueeze output.
 This reduces the number of channels by 8 and increases each spatial
 dimension by a factor of 2. Inverse operation of `Haar_squeeze`.

 *Input*:

 - `Y`: 5D input tensor of dimensions `nx` x `ny` x `nz` x `n_channel` x `batchsize`

 *Output*:

 - `X`: Reshaped tensor of dimenions `nx*2` x `ny*2` x `nz*2` x `n_channel/8` x `batchsize`

 See also: [`wavelet_unsqueeze`](@ref), [`Haar_unsqueeze`](@ref), [`HaarLift`](@ref), [`squeeze`](@ref), [`unsqueeze`](@ref)
"""
function invHaar_unsqueeze(x::AbstractArray{T,5}) where T

        s = size(x,4)

        ah = x[:, :, :, 1:Int(s/8), :]
        al = x[:, :, :, Int(s/8+1):Int(2*s/8),:]
        vh = x[:, :, :, Int(2*s/8+1):Int(3*s/8),:]
        vl = x[:, :, :, Int(3*s/8+1):Int(4*s/8),:]
        hh = x[:, :, :, Int(4*s/8+1):Int(5*s/8),:]
        hl = x[:, :, :, Int(5*s/8+1):Int(6*s/8),:]
        dh = x[:, :, :, Int(6*s/8+1):Int(7*s/8),:]
        dl = x[:, :, :, Int(7*s/8+1):end,:]

        a = invHaarLift(al,ah,3)
        v = invHaarLift(vl,vh,3)
        h = invHaarLift(hl,hh,3)
        d = invHaarLift(dl,dh,3)

        L = invHaarLift(a,h,1)
        H = invHaarLift(v,d,1)

        x = invHaarLift(L,H ,2)

        return x
end

####################################################################################################
# Split and concatenate

"""
    Y, Z = tensor_split(X)

 Split ND input tensor in half along the channel dimension. Inverse operation
 of `tensor_cat`.

 *Input*:

 - `X`: ND input tensor of dimensions `nx` [x `ny` [x `nz`]] x `n_channel` x `batchsize`

 *Output*:

 - `Y`, `Z`: ND output tensors, each of dimensions `nx` [x `ny` [x `nz`]] x `n_channel/2` x `batchsize`

 See also: [`tensor_cat`](@ref)
"""
function tensor_split(X::AbstractArray{T,N}; split_index=nothing) where {T, N}
    d = max(1, N-1)
    if isnothing(split_index)
        k = Int(round(size(X, d)/2))
    else
        k = split_index
    end

    indsl = [i==d ? (1:k) : (:) for i=1:N]
    indsr = [i==d ? (k+1:size(X, d)) : (:) for i=1:N]

    return X[indsl...], X[indsr...]
end

"""
    X = tensor_cat(Y, Z)

 Concatenate ND input tensors along the channel dimension. Inverse operation
 of `tensor_split`.

 *Input*:

 - `Y`, `Z`: ND input tensors, each of dimensions `nx` [x `ny` [x `nz`]] x `n_channel` x `batchsize`

 *Output*:

 - `X`: ND output tensor of dimensions `nx` [x `ny` [x `nz`]] x `n_channel*2` x `batchsize`

 See also: [`tensor_split`](@ref)
"""
function tensor_cat(X::AbstractArray{T,N}, Y::AbstractArray{T,N}) where {T, N}
    d = max(1, N-1)
    if size(X, d) == 0
        return Y
    elseif size(Y, d) == 0
        return X
    else
        return cat(X, Y; dims=d)
    end
end

tensor_cat(X::Tuple{AbstractArray{T,N}, AbstractArray{T,N}}) where {T, N} = tensor_cat(X[1], X[2])
