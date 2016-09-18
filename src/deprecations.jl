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
