module ImagesAxes

using Reexport

@reexport using AxisArrays

export @timeaxis, timeaxis
# export HasTimeAxis   # once traits are working

abstract AxisType
immutable TimeAxis <: AxisType end
immutable SpaceAxis <: AxisType end

# By default, axes are spatial
AxisType{T<:Axis}(::Type{T}) = SpaceAxis()

macro timeaxis(T)
    :(AxisType{T<:$T}(::Type{T}) = TimeAxis())
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
# Hope for a prettier implementation using Traitor (this doesn't work yet):
# @traitor _timeaxis(ax::Axis, axes...) = _timeaxis(axes...)
# @traitor _timeaxis(ax::Axis::TimeAxis, axes...) = ax
@inline _timeaxis(ax, axes...) = __timeaxis((ax, AxisType(typeof(ax))), axes...)
@inline __timeaxis(ax_trait::Tuple{Axis,TimeAxis}, axes...) = ax_trait[1]
@inline __timeaxis(ax_trait,                       axes...) = _timeaxis(axes...)
_timeaxis() = nothing

# Once traits are working
# abstract AbstractHasTimeAxis
# immutable HasTimeAxis <: AbstractHasTimeAxis end

# Base.@pure function AbstractHasTimeAxis{T,N,D,Ax}(::Type{AxisArray{T,N,D,Ax}})
#     any(S->isa(AxisType(S), TimeAxis), Ax.parameters) ? HasTimeAxis : Void
# end

end # module
