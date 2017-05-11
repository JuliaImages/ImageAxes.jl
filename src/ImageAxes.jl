__precompile__()

module ImageAxes

using Base: @pure, tail
using Reexport, Colors, SimpleTraits, MappedArrays
using Compat

@reexport using AxisArrays
@reexport using ImageCore

export # types
    HasTimeAxis,
    IndexTimeAny,
    IndexTimeIncremental,
    ReadOnlyArray,
    StreamingTimeArray,
    TimeAxis,
    TimeIndexStyle,
    # functions
    istimeaxis,
    timeaxis,
    timedim

"""
    TimeAxis{Ax}

A trait (from SimpleTraits) indicating whether axis `Ax` corresponds
to time. This decision is based on the symbol-name given to `Ax`. For
example, the following declares that all `Axis{:time}` objects
correspond to time:

    @traitimpl TimeAxis{Axis{:time}}

This definition has already been made in ImageAxes, but you can add
new names as well.
"""
@traitdef TimeAxis{X}

@traitimpl TimeAxis{Axis{:time}}

# Note: any axis not marked as a TimeAxis is assumed to correspond to
# space. It might be useful to allow users to add other possibilities,
# but this is not currently possible with SimpleTraits.

"""
    timeaxis(A)

Return the time axis, if present, of the array `A`, and `nothing` otherwise.
"""
@inline timeaxis(A::AxisArray) = _timeaxis(A.axes...)
timeaxis(A::AbstractArray) = nothing
timeaxis(A::AbstractMappedArray) = timeaxis(parent(A))
@traitfn _timeaxis{Ax<:Axis; !TimeAxis{Ax}}(ax::Ax, axes...) = _timeaxis(axes...)
@traitfn _timeaxis{Ax<:Axis;  TimeAxis{Ax}}(ax::Ax, axes...) = ax
_timeaxis() = nothing


"""
    istimeaxis(ax)

Test whether the axis `ax` corresponds to time.
"""
istimeaxis(ax::Axis) = istimeaxis(typeof(ax))
@traitfn istimeaxis{Ax<:Axis; !TimeAxis{Ax}}(::Type{Ax}) = false
@traitfn istimeaxis{Ax<:Axis;  TimeAxis{Ax}}(::Type{Ax}) = true

@traitdef HasTimeAxis{X}
"""
    HasTimeAxis{AA}

A trait for testing whether type `AA` has a time axis. Time axes must
be declared before use.

# Examples

```julia
using ImageAxes, SimpleTraits

# Declare that all axes named `:time` are time axes
@traitimpl TimeAxis{Axis{:time}}

# Define functions that dispatch on AxisArrays that may or may not have time axes
@traitfn got_time{AA<:AxisArray;  HasTimeAxis{AA}}(img::AA) = "yep, I've got time"
@traitfn got_time{AA<:AxisArray; !HasTimeAxis{AA}}(img::AA) = "no, I'm too busy"

julia> A = AxisArray(1:5, Axis{:time}(1:5));

julia> got_time(A)
"yep, I've got time"

julia> A = AxisArray(1:5, Axis{:x}(1:5));

julia> got_time(A)
"no, I'm too busy"
```
"""
HasTimeAxis

axtype{T,N,D,Ax}(::Type{AxisArray{T,N,D,Ax}}) = Ax
axtype(A::AxisArray) = axtype(typeof(A))

Base.@pure function SimpleTraits.trait{AA<:AxisArray}(t::Type{HasTimeAxis{AA}})
    axscan = map(S->istimeaxis(S), axtype(AA).parameters)
    any(axscan) ? HasTimeAxis{AA} : Not{HasTimeAxis{AA}}
end

# Specializations to preserve the AxisArray wrapper
function ImageCore.permuteddimsview(A::AxisArray, perm)
    axs = axes(A)
    AxisArray(permuteddimsview(A.data, perm), axs[[perm...]]...)
end
function ImageCore.channelview(A::AxisArray)
    Ac = channelview(A.data)
    _channelview(A, Ac)
end
# without extra dimension:
_channelview{C,T,N}(A::AxisArray{C,N}, Ac::AbstractArray{T,N}) = AxisArray(Ac, axes(A)...)
# with extra dimension: (bug: the type parameters shouldn't be necessary, but julia 0.5 dispatches incorrectly without them)
_channelview{C,T,M,N}(A::AxisArray{C,M}, Ac::AbstractArray{T,N}) = AxisArray(Ac, Axis{:color}(indices(Ac,1)), axes(A)...)


### Image properties based on traits ###

"""
    timedim(img) -> d::Int

Return the dimension of the array used for encoding time, or 0 if not
using an axis for this purpose.

Note: if you want to recover information about the time axis, it is
generally better to use `timeaxis`.
"""
ImageCore.timedim{T,N}(img::AxisArray{T,N}) = _timedim(filter_time_axis(axes(img), ntuple(identity, Val{N})))
_timedim(dim::Tuple{Int}) = dim[1]
_timedim(::Tuple{}) = 0

ImageCore.nimages(img::AxisArray) = _nimages(timeaxis(img))
_nimages(::Void) = 1
_nimages(ax::Axis) = length(ax)

function ImageCore.colordim(img::AxisArray)
    d = _colordim(1, axes(img))
    d > ndims(img) ? 0 : d
end
_colordim{Ax<:Axis{:color}}(d, ax::Tuple{Ax,Vararg{Any}}) = d
_colordim(d, ax::Tuple{Any,Vararg{Any}}) = _colordim(d+1, tail(ax))
_colordim(d, ax::Tuple{}) = d+1

ImageCore.pixelspacing(img::AxisArray) = map(step, filter_space_axes(axes(img), axisvalues(img)))

ImageCore.spacedirections(img::AxisArray) = ImageCore._spacedirections(pixelspacing(img))

ImageCore.coords_spatial{T,N}(img::AxisArray{T,N}) = filter_space_axes(axes(img), ntuple(identity, Val{N}))

ImageCore.spatialorder(img::AxisArray) = filter_space_axes(axes(img), axisnames(img))

ImageCore.size_spatial(img::AxisArray)    = filter_space_axes(axes(img), size(img))
ImageCore.indices_spatial(img::AxisArray) = filter_space_axes(axes(img), indices(img))

### Utilities for writing "simple algorithms" safely ###

# Check that the time dimension, if present, is last
@traitfn function ImageCore.assert_timedim_last{AA<:AxisArray; HasTimeAxis{AA}}(img::AA)
    ax = axes(img)[end]
    istimeaxis(ax) || error("time dimension is not last")
    nothing
end
@traitfn ImageCore.assert_timedim_last{AA<:AxisArray; !HasTimeAxis{AA}}(img::AA) = nothing

### Convert ###
function Base.convert{C<:Colorant,n}(::Type{Array{C,n}},
                                     img::AxisArray{C,n})
    copy!(Array{C}(size(img)), img)
end
function Base.convert{Cdest<:Colorant,n,Csrc<:Colorant}(::Type{Array{Cdest,n}},
                                                        img::AxisArray{Csrc,n})
    copy!(Array{ccolor(Cdest, Csrc)}(size(img)), img)
end

### StreamingTimeArray ###

"""
    StreamingTimeArray{T,N}

An abstract type possessing a time axis but for which changing time
"slices" may be expensive or subject to restrictions.

In addition to core array traits (e.g., `indices`), subtypes of
StreamingTimeArray should implement the following:

- `axes` (returning a tuple of `AxisArray.Axis`; one should be an `Axis{:time}`)
- `view(A, axt::Axis{:time})` (for creating/selecting a specific temporal slice)
- optionally, [`TimeIndexStyle`](@ref)

Note that StreamingTimeArrays are not guaranteed to implement
`setindex!`, and in such cases the object returned by `view` should
also not implement it. See [`ReadOnlyArray`](@ref).
"""
@compat abstract type StreamingTimeArray{T,N} <: AbstractArray{T,N} end

Base.eltype{T}(::Type{StreamingTimeArray{T}}) = T
Base.eltype{T,N}(::Type{StreamingTimeArray{T,N}}) = T
Base.eltype{S<:StreamingTimeArray}(::Type{S}) = eltype(supertype(S))
Base.eltype(S::StreamingTimeArray) = eltype(typeof(S))

Base.ndims{T,N}(::Type{StreamingTimeArray{T,N}}) = N
Base.ndims{S<:StreamingTimeArray}(::Type{S}) = ndims(supertype(S))
Base.ndims(S::StreamingTimeArray) = ndims(typeof(S))

AxisArrays.axisnames(S::StreamingTimeArray)  = axisnames(axes(S)...)
AxisArrays.axisvalues(S::StreamingTimeArray) = axisvalues(axes(S)...)
function AxisArrays.axisdim{name}(S::StreamingTimeArray, ::Type{Axis{name}})
    isa(name, Int) && return name <= N ? name : error("axis $name greater than array dimensionality $N")
    names = axisnames(S)
    idx = findfirst(names, name)
    idx == 0 && error("axis $name not found in array axes $names")
    idx
end
AxisArrays.axisdim(S::StreamingTimeArray, ax::Axis) = axisdim(S, typeof(ax))
AxisArrays.axisdim{name,T}(S::StreamingTimeArray, ::Type{Axis{name,T}}) = axisdim(S, Axis{name})

ImageCore.nimages(S::StreamingTimeArray) = _nimages(timeaxis(S))
ImageCore.coords_spatial{T,N}(S::StreamingTimeArray{T,N}) =
    filter_space_axes(axes(S), ntuple(identity, Val{N}))
ImageCore.spatialorder(S::StreamingTimeArray) = filter_space_axes(axes(S), axisnames())
ImageCore.size_spatial(img::StreamingTimeArray)    = filter_space_axes(axes(img), size(img))
ImageCore.indices_spatial(img::StreamingTimeArray) = filter_space_axes(axes(img), indices(img))
function ImageCore.assert_timedim_last(S::StreamingTimeArray)
    istimeaxis(axes(S)[end]) || error("time dimension is not last")
    nothing
end

timeaxis(S::StreamingTimeArray) = _timeaxis(axes(S)...)


"""
    style = TimeIndexStyle(A)

A trait that indicates the degree of support for indexing the time
axis of `A`. Choices are [`IndexTimeAny()`](@ref) and
[`IndexTimeIncremental()`](@ref) (for arrays that only permit advancing
the time axis, e.g., a video stream from a webcam). The default value
is `IndexTimeAny()`.

This should be specialized for the type rather than the instance, for example:

```julia
(::Type{TimeIndexStyle}){A<:MyArrayType}(::Type{A}) = IndexTimeIncremental()
```
"""
@compat abstract type TimeIndexStyle end
immutable IndexTimeAny <: TimeIndexStyle end
immutable IndexTimeIncremental <: TimeIndexStyle end

(::Type{TimeIndexStyle}){A<:AbstractArray}(::Type{A}) = IndexTimeAny()
(::Type{TimeIndexStyle})(A::AbstractArray) = TimeIndexStyle(typeof(A))

immutable ReadOnlyArray{T,N,A<:AbstractArray} <: AbstractArray{T,N}
    parent::A
end
(::Type{ReadOnlyArray}){T,N}(A::AbstractArray{T,N}) = ReadOnlyArray{T,N,typeof(A)}(A)

# don't implement parent because that makes it too easy to violate the read-only promise
Base.size(A::ReadOnlyArray) = size(A.parent)
Base.size(A::ReadOnlyArray, d) = size(A.parent, d)
Base.indices(A::ReadOnlyArray) = indices(A.parent)
Base.indices(A::ReadOnlyArray, d) = indices(A.parent, d)

@compat Base.IndexStyle{T,N,A}(::Type{ReadOnlyArray{T,N,A}}) = IndexStyle(A)
Base.similar{S,N}(A::ReadOnlyArray, ::Type{S}, dims::Dims{N}) = similar(A.parent, S, dims)
@inline Base.getindex(A::ReadOnlyArray, I...) = getindex(A.parent, I...)

### Low level utilities ###

filter_space_axes{N}(axes::NTuple{N,Axis}, items::NTuple{N,Any}) =
    _filter_space_axes(axes, items)
@inline @traitfn _filter_space_axes{Ax<:Axis;  TimeAxis{Ax}}(axes::Tuple{Ax,Vararg{Any}}, items) =
    _filter_space_axes(tail(axes), tail(items))
@inline @traitfn _filter_space_axes{Ax<:Axis; !TimeAxis{Ax}}(axes::Tuple{Ax,Vararg{Any}}, items) =
    (items[1], _filter_space_axes(tail(axes), tail(items))...)
_filter_space_axes(::Tuple{}, ::Tuple{}) = ()
@inline _filter_space_axes{Ax<:Axis{:color}}(axes::Tuple{Ax,Vararg{Any}}, items) =
    _filter_space_axes(tail(axes), tail(items))

filter_time_axis{N}(axes::NTuple{N,Axis}, items::NTuple{N}) =
    _filter_time_axis(axes, items)
@inline @traitfn _filter_time_axis{Ax<:Axis; !TimeAxis{Ax}}(axes::Tuple{Ax,Vararg{Any}}, items) =
    _filter_time_axis(tail(axes), tail(items))
@inline @traitfn _filter_time_axis{Ax<:Axis;  TimeAxis{Ax}}(axes::Tuple{Ax,Vararg{Any}}, items) =
    (items[1], _filter_time_axis(tail(axes), tail(items))...)
_filter_time_axis(::Tuple{}, ::Tuple{}) = ()

# summary: print color types & fixed-point types compactly
function AxisArrays._summary{T<:Union{Fractional,Colorant},N}(io, A::AxisArray{T,N})
    print(io, "$N-dimensional AxisArray{")
    ImageCore.showcoloranttype(io, T)
    println(io, ",$N,...} with axes:")
end

include("deprecations.jl")

end # module
