using ImageAxes, AxisArrays, Base.Test

@testset "Deprecated" begin
    @testset "indexing" begin
        B = collect(reshape(1:15, 3, 5))
        A = AxisArray(B, :x, :y)
        @test dimindex(A, "x") == 1
        @test dimindex(A, "y") == 2
        @test dimindex(A, "t") == 0
        @test size(A, "x") == 3
        @test size(A, "y") == 5
        @test A["x", 2, "y", 3] == 8
        @test A["x", 2] == collect(2:3:15)
        A["x", 2, "y", 3] = -1
        @test A["x", 2, "y", 3] == -1
        v = view(A, "y", 2)
        @test v == [4,5,6]
        # non-AxisArrays
        C = sprand(5, 5, 0.5)  # for coverage (ambiguity resolution)
        @test_throws ErrorException B["x", 2, "y", 3]
        @test_throws ErrorException C["x", :, "y", 3]
        @test_throws ErrorException view(B, "y", 2)
        @test_throws ErrorException B["x", 2, "y", 3] = -1
    end

    @testset "permutedims" begin
        A = AxisArray(collect(reshape(1:15, 3, 5)), :x, :y)
        @test permutedims(A, ("y", "x")) == A'
        @test permutedims(A, ["y", "x"]) == A'
    end
end
