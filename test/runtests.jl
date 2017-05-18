using Colors, FixedPointNumbers, ImageAxes, MappedArrays, Base.Test

if VERSION < v"0.6.0-dev"
    ambs = detect_ambiguities(ImageAxes,ImageCore,Base,Core)
    if !isempty(ambs)
        println("Ambiguities:")
        for a in ambs
            println(a)
        end
    end
    @test isempty(ambs)
end

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

    @test @inferred(timeaxis(rand(3,5))) == nothing
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

@testset "grayscale" begin
    A = AxisArray(rand(Gray{N0f8}, 4, 5), :y, :x)
    @test summary(A) == "2-dimensional AxisArray{Gray{N0f8},2,...} with axes:\n    :y, Base.OneTo(4)\n    :x, Base.OneTo(5)\nAnd data, a 4×5 Array{Gray{N0f8},2}"
    cv = channelview(A)
    @test axes(cv) == (Axis{:y}(1:4), Axis{:x}(1:5))
    @test spatialorder(cv) == (:y, :x)
    @test colordim(cv) == 0
end

@testset "color" begin
    A = AxisArray(rand(RGB{N0f8}, 4, 5), :y, :x)
    cv = channelview(A)
    @test axes(cv) == (Axis{:color}(1:3), Axis{:y}(1:4), Axis{:x}(1:5))
    @test spatialorder(cv) == (:y, :x)
    @test colordim(cv) == 1
    p = permuteddimsview(cv, (2,3,1))
    @test axes(p) == (Axis{:y}(1:4), Axis{:x}(1:5), Axis{:color}(1:3))
    @test colordim(p) == 3
end

@testset "nested" begin
    A = AxisArray(rand(RGB{N0f8}, 4, 5), (:y, :x), (2, 1))
    P = permuteddimsview(A, (2, 1))
    @test @inferred(pixelspacing(P)) == (1, 2)
    M = mappedarray(identity, A)
    @test @inferred(pixelspacing(M)) == (2, 1)
    const s = u"s"
    const μm = u"μm"
    tax = Axis{:time}(range(0.0s, 0.1s, 11))
    A = AxisArray(rand(N0f16, 4, 5, 11), (:y, :x, :time), (2μm, 1μm, 0.1s))
    P = permuteddimsview(A, (3, 1, 2))
    M = mappedarray(identity, A)
    @test @inferred(pixelspacing(P)) == @inferred(pixelspacing(M)) == (2μm, 1μm)
    @test @inferred(timeaxis(P)) == @inferred(timeaxis(M)) == tax
    @test has_time_axis(P)
    @test coords_spatial(P) == (2, 3)
    @test coords_spatial(M) == (1, 2)
    @test spatialorder(P) == spatialorder(M) == (:y, :x)
    @test @inferred(size_spatial(P)) == @inferred(size_spatial(M)) == (4, 5)
    @test_throws ErrorException assert_timedim_last(P)
    assert_timedim_last(M)
    A = AxisArray(rand(N0f16, 11, 5, 4), (:time, :x, :y), (0.1s, 1μm, 2μm))
    P = permuteddimsview(A, (3, 2, 1))
    M = mappedarray(identity, A)
    @test @inferred(pixelspacing(P)) == (2μm, 1μm)
    @test @inferred(pixelspacing(M)) == (1μm, 2μm)
    @test @inferred(timeaxis(P)) == @inferred(timeaxis(M)) == tax
    @test has_time_axis(P)
    @test coords_spatial(P) == (1, 2)
    @test coords_spatial(M) == (2, 3)
    @test spatialorder(P) == (:y, :x)
    @test spatialorder(M) == (:x, :y)
    @test @inferred(size_spatial(P)) == (4, 5)
    @test @inferred(size_spatial(M)) == (5, 4)
    assert_timedim_last(P)
    @test_throws ErrorException assert_timedim_last(M)
end

# Possibly-ambiguous functions
@testset "ambig" begin
    A = AxisArray(rand(RGB{N0f8},3,5), :x, :y)
    @test isa(convert(Array{RGB{N0f8},2}, A), Array{RGB{N0f8},2})
    @test isa(convert(Array{Gray{N0f8},2}, A), Array{Gray{N0f8},2})
end

@testset "internal" begin
    A = AxisArray(rand(RGB{N0f8},3,5), :x, :y)
    @test ImageAxes.axtype(A) == Tuple{Axis{:x,Base.OneTo{Int}}, Axis{:y,Base.OneTo{Int}}}
end

@testset "streaming" begin
    P = AxisArray([0 0 0 0;
                   1 2 3 4;
                   0 0 0 0], :x, :time)
    f!(dest, a) = (dest[1] = dest[3] = -0.2*a[2]; dest[2] = 0.6*a[2]; dest)
    S = @inferred(StreamingArray{Float64}(f!, P, Axis{:time}()))
    @test @inferred(indices(S)) === (Base.OneTo(3), Base.OneTo(4))
    @test @inferred(size(S)) == (3,4)
    @test @inferred(axisnames(S)) == (:x, :time)
    @test @inferred(axisvalues(S)) === (Base.OneTo(3), Base.OneTo(4))
    @test axisdim(S, Axis{:x}) == axisdim(S, Axis{:x}(1:2)) == axisdim(S, Axis{:x,UnitRange{Int}}) == 1
    @test axisdim(S, Axis{:time}) == 2
    @test_throws ErrorException axisdim(S, Axis{:y})
    @test axisdim(S, Axis{2}) == 2
    @test_throws ErrorException axisdim(S, Axis{3})
    @test @inferred(timeaxis(S)) === Axis{:time}(Base.OneTo(4))
    @test nimages(S) == 4
    @test @inferred(coords_spatial(S)) == (1,)
    @test @inferred(indices_spatial(S)) == (Base.OneTo(3),)
    @test @inferred(size_spatial(S)) == (3,)
    @test @inferred(spatialorder(S)) == (:x,)
    assert_timedim_last(S)
    for i = 1:4
        @test @inferred(S[:,i]) == [-0.2,0.6,-0.2]*i
        @test @inferred(S[2,i]) === 0.6*i
        @test @inferred(S[Axis{:time}(i)]) == [-0.2,0.6,-0.2]*i
        @test @inferred(S[Axis{:time}(i),Axis{:x}(2)]) === 0.6*i
        @test @inferred(S[Axis{:x}(2),Axis{:time}(i)]) === 0.6*i
    end
    buf = zeros(3)
    @test @inferred(getindex!(buf, S, :, 2)) == [-0.2,0.6,-0.2]*2
    @test StreamIndexStyle(S) === IndexAny()
    @test StreamIndexStyle(zeros(2,2)) === IndexAny()
    # internal
    @test ImageAxes.streamingaxisnames(S) == (:time,)
end

info("Beginning of tests with deprecation warnings")
include("deprecated.jl")

nothing
