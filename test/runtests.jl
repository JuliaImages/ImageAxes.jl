using ImagesAxes, SIUnits.ShortUnits, Base.Test

@timeaxis Axis{:time}

# using Traitor
# has_time_axis(A) = false
# @traitor has_time_axis(A::AxisArray::HasTimeAxis) = true
has_time_axis(A) = _has_time_axis(timeaxis(A), A)
_has_time_axis(::Void, ::Any) = false
_has_time_axis(::Axis, ::Any) = true

A = AxisArray(reshape(1:12, 3, 4), Axis{:x}(1:3), Axis{:y}(1:4))
@test timeaxis(A) == nothing
@test has_time_axis(A) == false
axt = Axis{:time}(1s:1s:4s)
A = AxisArray(reshape(1:12, 3, 4), Axis{:x}(1:3), axt)
@test timeaxis(A) === axt
@test has_time_axis(A) == true
