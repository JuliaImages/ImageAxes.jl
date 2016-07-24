module ImagesAxes

using Reexport, SimpleTraits

@reexport using AxisArrays

export @timeaxis, timeaxis, TimeAxis, HasTimeAxis

@traitdef TimeAxis{X}

"""
    timeaxis(A)

returns the time axis, if present, of the array `A`, and `nothing` otherwise.
"""
@inline timeaxis(A::AxisArray) = _timeaxis(A.axes...)
@traitfn _timeaxis{Ax<:Axis; !TimeAxis{Ax}}(ax::Ax, axes...) = _timeaxis(axes...)
@traitfn _timeaxis{Ax<:Axis;  TimeAxis{Ax}}(ax::Ax, axes...) = ax
_timeaxis() = nothing


@traitfn istimeaxis{Ax<:Axis; !TimeAxis{Ax}}(::Type{Ax}) = false
@traitfn istimeaxis{Ax<:Axis;  TimeAxis{Ax}}(::Type{Ax}) = true

@traitdef HasTimeAxis{X}

axtype{T,N,D,Ax}(::Type{AxisArray{T,N,D,Ax}}) = Ax
axtype(A::AxisArray) = axtype(typeof(A))

Base.@pure function SimpleTraits.trait{AA<:AxisArray}(t::Type{HasTimeAxis{AA}})
    axscan = map(S->istimeaxis(S), axtype(AA).parameters)
    any(axscan) ? HasTimeAxis{AA} : Not{HasTimeAxis{AA}}
end

end # module
