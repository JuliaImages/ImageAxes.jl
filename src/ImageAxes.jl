__precompile__()

module ImageAxes

using Base: @pure, tail
using Reexport, Colors, SimpleTraits

@reexport using AxisArrays
@reexport using ImageCore

export timeaxis, istimeaxis, TimeAxis, HasTimeAxis
export timedim

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
# with extra dimension:
_channelview(A::AxisArray, Ac::AbstractArray) = AxisArray(Ac, Axis{:color}(indices(Ac,1)), axes(A)...)


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

### Low level utilities ###

filter_space_axes{N}(axes::NTuple{N,Axis}, items::NTuple{N}) =
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

include("deprecations.jl")

end # module
