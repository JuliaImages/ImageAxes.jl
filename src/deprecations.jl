function Base.size(A::AxisArray, dim::AbstractString)
    Base.depwarn("size(A, ::AbstractString) is deprecated, use size(A, Ax{:$dim}) instead", :size)
    size(A, Axis{Symbol(dim)})
end

import AxisArrays.permutation
function permutation{S<:AbstractString}(to::Union{AbstractVector{S}, Tuple{S,Vararg{S}}}, from::AxisArrays.Symbols)
    Base.depwarn("permutations specified by strings is deprecated, use Symbols instead", :permutation)
    permutation((map(Symbol, to)...,), from)
end

export dimindex
function dimindex(A::AxisArray, dimname::AbstractString)
    sym = Symbol(dimname)
    Base.depwarn("dimindex(A, $dimname) is deprecated, use axisdim(A, Axis{:$sym}) instead", :dimindex)
    try
        return axisdim(A, Axis{sym})
    catch
        return 0
    end
end

function Base.getindex(img::AxisArray, dimname::AbstractString, ind::Base.ViewIndex, nameind...)
    axs = getaxes(dimname, ind, nameind...)
    Base.depwarn("indexing with strings is deprecated, use img[$(axs...)] instead", :setindex!)
    img[axs...]
end
Base.getindex(img::SparseMatrixCSC, dimname::AbstractString, ::Colon, nameind...) = error("for named dimensions, please switch to ImageAxes")  # resolves an ambiguity
Base.getindex(img::AbstractArray, dimname::AbstractString, ind::Base.ViewIndex, nameind...) = error("for named dimensions, please switch to ImageAxes")

function Base.setindex!(img::AxisArray, X, dimname::AbstractString, ind::Base.ViewIndex, nameind...)
    axs = getaxes(dimname, ind, nameind...)
    Base.depwarn("indexing with strings is deprecated, use img[$(axs...)] instead", :setindex!)
    setindex!(img, X, axs...)
end
Base.setindex!(img::AbstractArray, X, dimname::AbstractString, ind::Base.ViewIndex, nameind...) = error("for named dimensions, please switch to ImageAxes")

function Base.view(img::AxisArray, dimname::AbstractString, ind::Base.ViewIndex, args...)
    # Note this definition is problematic if one of the axes it categorical with strings
    # Delete this ASAP
    axs = getaxes(dimname, ind, args...)
    Base.depwarn("indexing with strings is deprecated, use view(img, $(axs...)) instead", :view!)
    view(img, axs...)
end
Base.view(img::AbstractArray, dimname::AbstractString, ind::Base.ViewIndex, args...) = error("for named dimensions, please switch to ImageAxes")

function getaxes(dimname::AbstractString, ind, nameind...)
    ax1 = Axis{Symbol(dimname)}(ind)
    axs = []
    for i = 1:2:length(nameind)
        push!(axs, Axis{Symbol(nameind[i])}(nameind[i+1]))
    end
    (ax1, axs...)
end
