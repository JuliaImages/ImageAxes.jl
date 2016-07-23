module ImagesAxes

using Reexport

@reexport using AxisArrays
# @reexport using Traitor

export @timeaxis, timeaxis, HasTimeAxis

abstract AxisType
immutable TimeAxis <: AxisType end
immutable SpaceAxis <: AxisType end

# By default, axes are spatial
AxisType{T<:Axis}(::Type{T}) = SpaceAxis

macro timeaxis(T)
    :(AxisType{T<:$T}(::Type{T}) = TimeAxis)
end

"""
    @timeaxis Axis{:axname}

declares that any `Axis` with name `:axname` is a temporal axis. This
declaration must be made before you call functions on such arrays.
"""
:@timeaxis

"""
    timeaxis(A)

returns the time axis, if present, of the array `A`, and `nothing` otherwise.
"""
@inline timeaxis(A::AxisArray) = _timeaxis(A.axes...)
# A prettier implementation using Traitor:
# @inline _timeaxis(ax, axes...) = _timeaxis(axes...)
# @traitor _timeaxis(ax::Axis::TimeAxis, axes...) = ax
@inline _timeaxis(ax, axes...) = __timeaxis(AxisType(typeof(ax)), ax, axes...)
@inline __timeaxis(::Type{TimeAxis}, ax, axes...) = ax
@inline __timeaxis(::Type,           ax, axes...) = _timeaxis(axes...)
_timeaxis() = nothing

abstract AbstractHasTimeAxis
immutable HasTimeAxis <: AbstractHasTimeAxis end

Base.@pure AbstractHasTimeAxis{T,N,D,Ax}(::Type{AxisArray{T,N,D,Ax}}) = any(S->S<:TimeAxis, Ax.parameters)

end # module
