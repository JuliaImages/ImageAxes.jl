using ImagesAxes, SIUnits.ShortUnits, Base.Test
using SimpleTraits

@traitimpl TimeAxis{Axis{:time}}

@traitfn has_time_axis{AA<:AxisArray;  HasTimeAxis{AA}}(::AA) = true
@traitfn has_time_axis{AA<:AxisArray; !HasTimeAxis{AA}}(::AA) = false
# has_time_axis{AA<:AxisArray}(::AA) = false

A = AxisArray(reshape(1:12, 3, 4), Axis{:x}(1:3), Axis{:y}(1:4))
@test timeaxis(A) == nothing
@test has_time_axis(A) == false
axt = Axis{:time}(1s:1s:4s)
A = AxisArray(reshape(1:12, 3, 4), Axis{:x}(1:3), axt)
@test timeaxis(A) === axt
@test has_time_axis(A) == true

@test isempty(detect_ambiguities(ImagesAxes,ImagesCore,Base,Core))
