using Colors, ImageAxes, Base.Test

ambs = detect_ambiguities(ImageAxes,ImageCore,Base,Core)
if !isempty(ambs)
    println("Ambiguities:")
    for a in ambs
        println(a)
    end
end
@test isempty(ambs)

using SimpleTraits, Unitful

@traitfn has_time_axis{AA<:AxisArray;  HasTimeAxis{AA}}(::AA) = true
@traitfn has_time_axis{AA<:AxisArray; !HasTimeAxis{AA}}(::AA) = false

@testset "no units, no time" begin
    A = AxisArray(reshape(1:12, 3, 4), Axis{:x}(1:3), Axis{:y}(1:4))
    @test @inferred(timeaxis(A)) === nothing
    @test !has_time_axis(A)
    @test timedim(A) == 0
    @test nimages(A) == 1
    @test @inferred(pixelspacing(A)) === (1,1)
    @test @inferred(spacedirections(A)) === ((1,0),(0,1))
    @test @inferred(coords_spatial(A)) === (1,2)
    @test spatialorder(A) === (:x, :y)  # TODO: make this inferrable
    @test @inferred(size_spatial(A)) === (3,4)
    @test @inferred(indices_spatial(A)) === (Base.OneTo(3), Base.OneTo(4))
    assert_timedim_last(A)
    @test map(istimeaxis, axes(A)) == (false,false)
end

@testset "units, no time" begin
    const mm = u"mm"
    const m = u"m"
    A = AxisArray(reshape(1:12, 3, 4), Axis{:x}(1mm:1mm:3mm), Axis{:y}(1m:2m:7m))
    @test @inferred(timeaxis(A)) === nothing
    @test !has_time_axis(A)
    @test timedim(A) == 0
    @test nimages(A) == 1
    @test @inferred(pixelspacing(A)) === (1mm,2m)
    @test spacedirections(A) === ((1mm,0m),(0mm,2m))   # TODO: make this inferrable
    @test @inferred(coords_spatial(A)) === (1,2)
    @test spatialorder(A) === (:x,:y)
    @test @inferred(size_spatial(A)) === (3,4)
    @test @inferred(indices_spatial(A)) === (Base.OneTo(3),Base.OneTo(4))
    assert_timedim_last(A)
    @test map(istimeaxis, axes(A)) == (false,false)
end

@testset "units, time" begin
    const s = u"s"
    axt = Axis{:time}(1s:1s:4s)
    A = AxisArray(reshape(1:12, 3, 4), Axis{:x}(1:3), axt)
    @test @inferred(timeaxis(A)) === axt
    @test has_time_axis(A)
    @test timedim(A) == 2
    @test nimages(A) == 4
    @test @inferred(pixelspacing(A)) === (1,)
    @test @inferred(spacedirections(A)) === ((1,),)
    @test @inferred(coords_spatial(A)) === (1,)
    @test spatialorder(A) === (:x,)
    @test @inferred(size_spatial(A)) === (3,)
    @test @inferred(indices_spatial(A)) === (Base.OneTo(3),)
    assert_timedim_last(A)
    @test map(istimeaxis, axes(A)) == (false,true)
end

@testset "units, time first" begin
    const s = u"s"
    axt = Axis{:time}(1s:1s:4s)
    A = AxisArray(reshape(1:12, 4, 3), axt, Axis{:x}(1:3))
    @test @inferred(timeaxis(A)) === axt
    @test has_time_axis(A)
    @test timedim(A) == 1
    @test nimages(A) == 4
    @test @inferred(pixelspacing(A)) === (1,)
    @test @inferred(spacedirections(A)) === ((1,),)
    @test @inferred(coords_spatial(A)) === (2,)
    @test spatialorder(A) === (:x,)
    @test @inferred(size_spatial(A)) === (3,)
    @test @inferred(indices_spatial(A)) === (Base.OneTo(3),)
    @test_throws ErrorException assert_timedim_last(A)
    @test map(istimeaxis, axes(A)) == (true,false)
end

@testset "color" begin
    A = AxisArray(rand(RGB{U8}, 4, 5), :y, :x)
    cv = channelview(A)
    @test axes(cv) == (Axis{:color}(1:3), Axis{:y}(1:4), Axis{:x}(1:5))
    @test spatialorder(cv) == (:y, :x)
    @test colordim(cv) == 1
    p = permuteddimsview(cv, (2,3,1))
    @test axes(p) == (Axis{:y}(1:4), Axis{:x}(1:5), Axis{:color}(1:3))
    @test colordim(p) == 3
end

# Possibly-ambiguous functions
@testset "ambig" begin
    A = AxisArray(rand(RGB{U8},3,5), :x, :y)
    @test isa(convert(Array{RGB{U8},2}, A), Array{RGB{U8},2})
    @test isa(convert(Array{Gray{U8},2}, A), Array{Gray{U8},2})
end

@testset "internal" begin
    A = AxisArray(rand(RGB{U8},3,5), :x, :y)
    @test ImageAxes.axtype(A) == Tuple{Axis{:x,Base.OneTo{Int}}, Axis{:y,Base.OneTo{Int}}}
end

include("deprecated.jl")

nothing
