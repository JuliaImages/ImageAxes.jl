__precompile__()

module ImageAxes

using Base: @pure, tail
using Reexport, Colors, SimpleTraits, MappedArrays
using Compat

@reexport using AxisArrays
@reexport using ImageCore

export # types
    HasTimeAxis,
    ReadOnlyArray,
    IndexAny,
    IndexIncremental,
    StreamingArray,
    TimeAxis,
    StreamIndexStyle,
    # functions
    getindex!,
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

### StreamingArray ###

"""
    A = StreamingArray{T}(f!, parent, streamingaxes...)

An array possessing one or more axes for which changing "slices" may
be expensive or subject to restrictions. A canonical example would be
an AVI stream, where addressing pixels within the same frame is fast
but jumping between frames might be slow.

A StreamingArray `A` is built from an AxisArray and supports the standard
AxisArray interface. Additionally, it supports

    getindex!(dest, A, axt::Axis{:time}, ...)

to obtain slices along the streamed axes. You can implement this
directly (dispatching on the parameters of `A`), or rely on the fallback

    A.getindex!(dest, view(parent, axs...))

where `A.getindex! = f!` as passed as an argument at construction. `dest` should
have dimensionality `ndims(parent)-length(streamingaxes)`.

Optionally, define [`StreamIndexStyle(typeof(parent),typeof(f!))`](@ref).
"""
immutable StreamingArray{T,N,streamingaxisnames,P,GetIndex} <: AbstractArray{T,N}
    getindex!::GetIndex
    parent::P
end
@generated function (::Type{StreamingArray{T}}){T}(f!::Function, parent, axs::Axis...)
    N = ndims(parent)
    axnames = axisnames(axs...)
    checknames(axnames, parent)
    :(StreamingArray{T,$N,$axnames,typeof(parent),typeof(f!)}(f!, parent))
end
checknames(axnames, ::Any) = nothing
checknames{AA<:AxisArray}(axnames, ::Type{AA}) = checknames(axnames, axisnames(AA))
@noinline function checknames(axnames, parentnames::Tuple{Symbol,Vararg{Symbol}})
    mapreduce(x->in(x, parentnames), &, axnames) || throw(DimensionMismatch("names $axnames are not included among $parentnames"))
    nothing
end

@compat Base.IndexStyle{S<:StreamingArray}(::Type{S}) = IndexCartesian()
Base.parent(S::StreamingArray) = S.parent
Base.indices(S::StreamingArray) = indices(S.parent)
Base.size(S::StreamingArray)    = size(S.parent)

AxisArrays.axes(S::StreamingArray) = axes(parent(S))
AxisArrays.axisnames(S::StreamingArray)  = axisnames(axes(S)...)
AxisArrays.axisvalues(S::StreamingArray) = axisvalues(axes(S)...)
function AxisArrays.axisdim{name}(S::StreamingArray, ::Type{Axis{name}})
    isa(name, Int) && return name <= ndims(S) ? name : error("axis $name greater than array dimensionality $(ndims(S))")
    names = axisnames(S)
    idx = findfirst(names, name)
    idx == 0 && error("axis $name not found in array axes $names")
    idx
end
AxisArrays.axisdim(S::StreamingArray, ax::Axis) = axisdim(S, typeof(ax))
AxisArrays.axisdim{name,T}(S::StreamingArray, ::Type{Axis{name,T}}) = axisdim(S, Axis{name})

ImageCore.nimages(S::StreamingArray) = _nimages(timeaxis(S))
ImageCore.coords_spatial{T,N}(S::StreamingArray{T,N}) =
    filter_space_axes(axes(S), ntuple(identity, Val{N}))
ImageCore.spatialorder(S::StreamingArray) = filter_space_axes(axes(S), axisnames(S))
ImageCore.size_spatial(img::StreamingArray)    = filter_space_axes(axes(img), size(img))
ImageCore.indices_spatial(img::StreamingArray) = filter_space_axes(axes(img), indices(img))
function ImageCore.assert_timedim_last(S::StreamingArray)
    istimeaxis(axes(S)[end]) || error("time dimension is not last")
    nothing
end

streamingaxisnames{T,N,names,P,GetIndex}(::Type{StreamingArray{T,N,names,P,GetIndex}}) =
    names
streamingaxisnames(S::StreamingArray) = streamingaxisnames(typeof(S))

timeaxis(S::StreamingArray) = _timeaxis(axes(S)...)

@inline function getindex!(dest, S::StreamingArray, axs::Axis...)
    all(ax->isstreamedaxis(ax,S), axs) || throw(ArgumentError("$axs do not coincide with the streaming axes $(streamingaxisnames(S))"))
    _getindex!(dest, S.getindex!, parent(S), axs...)
end

@inline function getindex!(dest, S::StreamingArray, I...)
    axs = getslicedindices(S, I)
    all(x->isa(x, Colon), filter_notstreamed(I, S)) || throw(ArgumentError("positional indices must use `:` for any non-streaming axes"))
    _getindex!(dest, S.getindex!, parent(S), axs...)
end

# _getindex! just makes it easy to specialize for particular parent or function types
@inline function _getindex!(dest, f!, P::AbstractArray, axs::Axis...)
    v = view(P, axs...)
    f!(dest, v)
end

function isstreamedaxis{name,T,N,saxnames}(ax::Axis{name},
                                           S::StreamingArray{T,N,saxnames})
    in(name, saxnames)
end

sliceindices(S::StreamingArray) = filter_notstreamed(indices(S), S)
sliceaxes(S::StreamingArray) = filter_notstreamed(axes(S), S)
getslicedindices(S::StreamingArray, I) = filter_streamed(map((ax, i) -> ax(i), axes(S), I), S)

filter_streamed(inds, S)    = _filter_streamed(inds, axes(S), S)
filter_notstreamed(inds, S) = _filter_notstreamed(inds, axes(S), S)
filter_streamed(inds::Tuple{Axis,Vararg{Axis}}, S)    = _filter_streamed(inds, inds, S)
filter_notstreamed(inds::Tuple{Axis,Vararg{Axis}}, S) = _filter_notstreamed(inds, inds, S)

@generated function _filter_streamed{N}(a, axs::NTuple{N,Axis}, S::StreamingArray)
    inds = findin(axisnames(axs.parameters...), streamingaxisnames(S))
    Expr(:tuple, Expr[:(a[$i]) for i in inds]...)
end
@generated function _filter_notstreamed{N}(a, axs::NTuple{N,Axis}, S::StreamingArray)
    inds = findin(axisnames(axs.parameters...), streamingaxisnames(S))
    inds = setdiff(1:N, inds)
    Expr(:tuple, Expr[:(a[$i]) for i in inds]...)
end

@inline function Base.getindex{T,N}(S::StreamingArray{T,N}, inds::Vararg{Base.ViewIndex,N})
    tmp = similar(Array{T}, sliceindices(S))
    getindex!(tmp, S, getslicedindices(S, inds)...)
    tmp[filter_notstreamed(inds, S)...]
end
@inline function Base.getindex(S::StreamingArray, ind1::Axis, inds_rest::Axis...)
    axs = sliceaxes(S)
    tmp = AxisArray(Array{eltype(S)}(map(length, axs)), axs)
    inds = (ind1, inds_rest...)
    getindex!(tmp, S, _filter_streamed(inds, inds, S)...)
    getindex_rest(tmp, _filter_notstreamed(inds, inds, S))
end
getindex_rest(tmp, ::Tuple{}) = tmp
getindex_rest(tmp, inds) = tmp[inds...]

"""
    style = StreamIndexStyle(A)

A trait that indicates the degree of support for indexing the streaming axes
of `A`. Choices are [`IndexAny()`](@ref) and
[`IndexIncremental()`](@ref) (for arrays that only permit advancing
the time axis, e.g., a video stream from a webcam). The default value
is `IndexAny()`.

This should be specialized for the type rather than the instance. For
a StreamingArray `S`, you can define this trait via

```julia
(::Type{StreamIndexStyle})(::Type{P}, ::typeof(f!)) = IndexIncremental()
```

where `P = typeof(parent(S))`.
"""
@compat abstract type StreamIndexStyle end
immutable IndexAny <: StreamIndexStyle end
immutable IndexIncremental <: StreamIndexStyle end

(::Type{StreamIndexStyle}){A<:AbstractArray}(::Type{A}) = IndexAny()
(::Type{StreamIndexStyle})(A::AbstractArray) = StreamIndexStyle(typeof(A))

(::Type{StreamIndexStyle}){T,N,axnames,P,GetIndex}(::Type{StreamingArray{T,N,axnames,P,GetIndex}}) = StreamIndexStyle(P, GetIndex)
StreamIndexStyle{P,GetIndex}(::Type{P},::Type{GetIndex}) = IndexAny()

## ReadOnlyArray ##

# needed to support `view` for StreamingArray

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
