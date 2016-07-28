
<a id='Introduction-1'></a>

# Introduction


While images can often be represented as plain `Array`s, sometimes additional information about the "meaning" of each axis of the array is needed.  For example, in a 3-dimensional MRI scan, the voxels may not have the same spacing along the z-axis that they do along the x- and y-axes, and this fact should be accounted for during the display and/or analysis of such images.  Likewise, a movie has two spatial axes and one temporal axis; this fact may be relevant for how one performs image processing.


This package combines features from [AxisArrays](https://github.com/mbauman/AxisArrays.jl) and [SimpleTraits](https://github.com/mauro3/SimpleTraits.jl) to provide a convenient representation and programming paradigm for dealing with such images.


<a id='Installation-1'></a>

# Installation


```jl
Pkg.add("ImagesAxes")
```


<a id='Usage-1'></a>

# Usage


<a id='Names-and-locations-1'></a>

## Names and locations


The simplest thing you can do is to provide names to your image axes:


```julia
using ImagesAxes
img = AxisArray(reshape(1:192, (8,8,3)), :x, :y, :z)
```

```
3-dimensional AxisArray{Int64,3,...} with axes:
    :x, 1:8
    :y, 1:8
    :z, 1:3
And data, a 8×8×3 Base.ReshapedArray{Int64,3,UnitRange{Int64},Tuple{}}:
[:, :, 1] =
 1   9  17  25  33  41  49  57
 2  10  18  26  34  42  50  58
 3  11  19  27  35  43  51  59
 4  12  20  28  36  44  52  60
 5  13  21  29  37  45  53  61
 6  14  22  30  38  46  54  62
 7  15  23  31  39  47  55  63
 8  16  24  32  40  48  56  64

[:, :, 2] =
 65  73  81  89   97  105  113  121
 66  74  82  90   98  106  114  122
 67  75  83  91   99  107  115  123
 68  76  84  92  100  108  116  124
 69  77  85  93  101  109  117  125
 70  78  86  94  102  110  118  126
 71  79  87  95  103  111  119  127
 72  80  88  96  104  112  120  128

[:, :, 3] =
 129  137  145  153  161  169  177  185
 130  138  146  154  162  170  178  186
 131  139  147  155  163  171  179  187
 132  140  148  156  164  172  180  188
 133  141  149  157  165  173  181  189
 134  142  150  158  166  174  182  190
 135  143  151  159  167  175  183  191
 136  144  152  160  168  176  184  192
```


As described in more detail in the [AxisArrays documentation](https://github.com/mbauman/AxisArrays.jl), you can now take slices like this:


```julia
sl = img[Axis{:z}(2)]
```

```
2-dimensional AxisArray{Int64,2,...} with axes:
    :x, 1:8
    :y, 1:8
And data, a 8×8 SubArray{Int64,2,Base.ReshapedArray{Int64,3,UnitRange{Int64},Tuple{}},Tuple{Colon,Colon,Int64},true}:
 65  73  81  89   97  105  113  121
 66  74  82  90   98  106  114  122
 67  75  83  91   99  107  115  123
 68  76  84  92  100  108  116  124
 69  77  85  93  101  109  117  125
 70  78  86  94  102  110  118  126
 71  79  87  95  103  111  119  127
 72  80  88  96  104  112  120  128
```


You can also give units to the axes:


```julia
using ImagesAxes, Unitful
img = AxisArray(reshape(1:192, (8,8,3)),
                Axis{:x}(1mm:1mm:8mm),
                Axis{:y}(1mm:1mm:8mm),
                Axis{:z}(2mm:3mm:8mm))
```

```
3-dimensional AxisArray{Int64,3,...} with axes:
    :x, 1 mm:1 mm:8 mm
    :y, 1 mm:1 mm:8 mm
    :z, 2 mm:3 mm:8 mm
And data, a 8×8×3 Base.ReshapedArray{Int64,3,UnitRange{Int64},Tuple{}}:
[:, :, 1] =
 1   9  17  25  33  41  49  57
 2  10  18  26  34  42  50  58
 3  11  19  27  35  43  51  59
 4  12  20  28  36  44  52  60
 5  13  21  29  37  45  53  61
 6  14  22  30  38  46  54  62
 7  15  23  31  39  47  55  63
 8  16  24  32  40  48  56  64

[:, :, 2] =
 65  73  81  89   97  105  113  121
 66  74  82  90   98  106  114  122
 67  75  83  91   99  107  115  123
 68  76  84  92  100  108  116  124
 69  77  85  93  101  109  117  125
 70  78  86  94  102  110  118  126
 71  79  87  95  103  111  119  127
 72  80  88  96  104  112  120  128

[:, :, 3] =
 129  137  145  153  161  169  177  185
 130  138  146  154  162  170  178  186
 131  139  147  155  163  171  179  187
 132  140  148  156  164  172  180  188
 133  141  149  157  165  173  181  189
 134  142  150  158  166  174  182  190
 135  143  151  159  167  175  183  191
 136  144  152  160  168  176  184  192
```


which specifies that `x` and `y` have spacing of 1mm and `z` has a spacing of 3mm, as well as the location of the center of each voxel.


<a id='Temporal-axes-1'></a>

## Temporal axes


(NOTE: portions of this don't work yet, but it illustrates what I'm aiming for.)


You can declare that an axis corresponds to time like this:


```julia
using ImagesAxes, SimpleTraits
@traitimpl TimeAxis{Axis{:time}}
```


Henceforth any array possessing an axis `Axis{:time}` will be recognized as having a temporal dimension. (You could alternatively have chosen `Axis{:t}` or `Axis{:scantime}` or any other name.) Note this declaration affects all arrays throughout your entire session. Moreover, it should be made before calling any functions on array-types that possess such axes; a convenient place to do this is right after you say `using ImagesAxes` in your top-level script.


Given an array `A`, you can retrieve its temporal axis with


```julia
using Unitful
img = AxisArray(reshape(1:9*300, (3,3,300)),
                Axis{:x}(1:3),
                Axis{:y}(1:3),
                Axis{:time}(1s/30:1s/30:10s))
ax = timeaxis(img)
```

```
AxisArrays.Axis{:time,StepRange{Unitful.FloatQuantity{Float64,Unitful.UnitData{(s,)}},Unitful.FloatQuantity{Float64,Unitful.UnitData{(s,)}}}}(0.03333333333333333 s:0.03333333333333333 s:10.0 s)
```


and index it like


```julia
# img[ax[3]]
```


Note that this requires that you've attached unique physical units to the time dimension.  Multiple time axes with different names in the same array are not supported.


You can also specialize methods like this:


```julia
using ImagesAxes, SimpleTraits
@traitfn nimages{AA<:AxisArray;  HasTimeAxis{AA}}(img::AA) = length(timeaxis(img))
@traitfn nimages{AA<:AxisArray; !HasTimeAxis{AA}}(img::AA) = 1
```

```
WARNING: Method definition nimages(#AA<:AxisArrays.AxisArray) in module ##ex-#273 at /home/tim/.julia/v0.5/SimpleTraits/src/SimpleTraits.jl:152 overwritten at /home/tim/.julia/v0.5/SimpleTraits/src/SimpleTraits.jl:152.
nimages (generic function with 3 methods)
```


where the pre-defined `HasTimeAxis` trait will restrict that method to arrays that have a timeaxis. A more complex example is


```julia
using ImagesAxes, SimpleTraits
@traitfn meanintensity{AA<:AxisArray; !HasTimeAxis{AA}}(img::AA) = mean(img)
@traitfn function meanintensity{AA<:AxisArray; HasTimeAxis{AA}}(img::AA)
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


and it will return the mean intensity at each timeslice, when appropriate.

