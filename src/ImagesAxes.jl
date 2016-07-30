# Currently we can't do this because of julia #17648
# __precompile__()

module ImagesAxes

using Base: @pure, tail
using Reexport, Colors, SimpleTraits

@reexport using AxisArrays

function Base.convert{C<:Colorant,n}(::Type{Array{C,n}},
                                     img::AxisArray{C,n})
    copy!(Array{C}(size(img)), img)
end
function Base.convert{Cdest<:Colorant,n,Csrc<:Colorant}(::Type{Array{Cdest,n}},
                                                        img::AxisArray{Csrc,n})
    copy!(Array{ccolor(Cdest, Csrc)}(size(img)), img)
end

@reexport using ImagesCore  # This has to come after the convert definitions (see julia #17648)


export @timeaxis, timeaxis, istimeaxis, TimeAxis, HasTimeAxis
export timedim

"""
    TimeAxis{Ax}

A trait (from SimpleTraits) indicating whether axis `Ax` corresponds
to time. This decision is based on the symbol-name given to `Ax`. For
example, the following declares that all `Axis{:time}` objects
correspond to time:

    @traitimpl TimeAxis{Axis{:time}}

This definition has already been made in ImagesAxes, but you can add
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
using ImagesAxes, SimpleTraits

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

### Image properties based on traits ###

"""
    timedim(img) -> d::Int

Return the dimension of the array used for encoding time, or 0 if not
using an axis for this purpose.

Note: if you want to recover information about the time axis, it is
generally better to use `timeaxis`.
"""
ImagesCore.timedim{T,N}(img::AxisArray{T,N}) = _timedim(filter_time_axis(axes(img), ntuple(identity, Val{N})))
_timedim(dim::Tuple{Int}) = dim[1]
_timedim(::Tuple{}) = 0

ImagesCore.nimages(img::AxisArray) = _nimages(timeaxis(img))
_nimages(::Void) = 1
_nimages(ax::Axis) = length(ax)

ImagesCore.pixelspacing(img::AxisArray) = map(step, axisvalues(img))

ImagesCore.spacedirections(img::AxisArray) = ImagesCore._spacedirections(filter_space_axes(axes(img), pixelspacing(img)))

ImagesCore.coords_spatial{T,N}(img::AxisArray{T,N}) = filter_space_axes(axes(img), ntuple(identity, Val{N}))

ImagesCore.spatialorder(img::AxisArray) = filter_space_axes(axes(img), axisnames(img))

ImagesCore.size_spatial(img::AxisArray)    = filter_space_axes(axes(img), size(img))
ImagesCore.indices_spatial(img::AxisArray) = filter_space_axes(axes(img), indices(img))

#### Utilities for writing "simple algorithms" safely ####

# Check that the time dimension, if present, is last
@traitfn function ImagesCore.assert_timedim_last{AA<:AxisArray; HasTimeAxis{AA}}(img::AA)
    ax = axes(img)[end]
    istimeaxis(ax) || error("time dimension is not last")
    nothing
end
@traitfn ImagesCore.assert_timedim_last{AA<:AxisArray; !HasTimeAxis{AA}}(img::AA) = nothing

### Low level utilities ###

filter_space_axes{N}(axes::NTuple{N,Axis}, items::NTuple{N}) =
    _filter_space_axes(axes, items)
@inline @traitfn _filter_space_axes{Ax<:Axis;  TimeAxis{Ax}}(axes::Tuple{Ax,Vararg{Any}}, items) =
    _filter_space_axes(tail(axes), tail(items))
@inline @traitfn _filter_space_axes{Ax<:Axis; !TimeAxis{Ax}}(axes::Tuple{Ax,Vararg{Any}}, items) =
    (items[1], _filter_space_axes(tail(axes), tail(items))...)
_filter_space_axes(::Tuple{}, ::Tuple{}) = ()

filter_time_axis{N}(axes::NTuple{N,Axis}, items::NTuple{N}) =
    _filter_time_axis(axes, items)
@inline @traitfn _filter_time_axis{Ax<:Axis; !TimeAxis{Ax}}(axes::Tuple{Ax,Vararg{Any}}, items) =
    _filter_time_axis(tail(axes), tail(items))
@inline @traitfn _filter_time_axis{Ax<:Axis;  TimeAxis{Ax}}(axes::Tuple{Ax,Vararg{Any}}, items) =
    (items[1], _filter_time_axis(tail(axes), tail(items))...)
_filter_time_axis(::Tuple{}, ::Tuple{}) = ()

end # module
