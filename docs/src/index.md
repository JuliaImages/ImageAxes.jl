# Introduction

While images can often be represented as plain `Array`s, sometimes
additional information about the "meaning" of each axis of the array
is needed.  For example, in a 3-dimensional MRI scan, the voxels may
not have the same spacing along the z-axis that they do along the x-
and y-axes, and this fact should be accounted for during the display
and/or analysis of such images.  Likewise, a movie has two spatial
axes and one temporal axis; this fact may be relevant for how one
performs image processing.

This package combines features from
[AxisArrays](https://github.com/mbauman/AxisArrays.jl) and
[Traitor](https://github.com/andyferris/Traitor.jl) to provide a
convenient representation and programming paradigm for dealing with
such images.

# Installation

```jl
Pkg.add("ImagesAxes")
```

# Usage

## Names and locations

The simplest thing you can do is to provide names to your image axes:

```@example 1
using ImagesAxes
img = AxisArray(reshape(1:192, (8,8,3)), :x, :y, :z)
```

As described in more detail in the [AxisArrays documentation](https://github.com/mbauman/AxisArrays.jl), you can now take slices like this:

```@example 1
sl = img[Axis{:z}(2)]
```

You can also give units to the axes:

```@example
using ImagesAxes, SIUnits.ShortUnits
img = AxisArray(reshape(1:192, (8,8,3)),
                Axis{:x}(1mm:1mm:8mm),
                Axis{:y}(1mm:1mm:8mm),
                Axis{:z}(2mm:3mm:8mm))
```

which specifies that `x` and `y` have spacing of 1mm and `z` has a
spacing of 3mm, as well as the location of the center of each voxel.

## Temporal axes

You can declare that an axis corresponds to time like this:

```@example 2
using ImagesAxes
@timeaxis Axis{:time}
```

Henceforth any array possessing an axis `Axis{:time}` will be
recognized as having a temporal dimension. (You could alternatively
have chosen `Axis{:t}` or `Axis{:scantime}` or any other name.) Note
this declaration affects all arrays throughout your entire session.
Moreover, it should be made before calling any functions on
array-types that possess such axes; a convenient place to do this is
right after you say `using ImagesAxes` in your top-level script.

Given an array `A`, you can retrieve its temporal axis with

```@example 2
using SIUnits.ShortUnits
img = AxisArray(reshape(1:9*300, (3,3,300)),
                Axis{:x}(1:3),
                Axis{:y}(1:3),
                Axis{:time}(1s/30:1s/30:10s))
ax = timeaxis(img)
```

and index it like (NOTE: the rest of this illustrates what we're aiming for, and doesn't work yet)

```@example 2
img[ax[3]]
```

Note that this requires that you've attached unique physical units to the time dimension.  Multiple time axes with different names in the same array are not supported.

You can also specialize methods like this:

```@example
nimages(img) = 1
@traitor nimages(img::AxisArray::HasTimeAxis) = length(timeaxis(img))
```

where the pre-defined `HasTimeAxis` trait will restrict that method to
arrays that have a timeaxis. This makes it easy to write methods like this:

```julia
meanintensity(img) = mean(img)
@traitor function meanintensity(img::AxisArray::HasTimeAxis)
    ax = timeaxis(img)
    n = length(x)
    intensity = zeros(eltype(img), n)
    for ti = 1:n
        sl = img[ax[ti]]  # the image slice at time ax[ti]
        intensity[ti] = mean(sl)
    end
    intensity
end
```
