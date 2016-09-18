using ImageAxes, AxisArrays, Base.Test

@testset "Deprecated" begin
    @testset "indexing" begin
        A = AxisArray(collect(reshape(1:15, 3, 5)), :x, :y)
        @test dimindex(A, "x") == 1
        @test dimindex(A, "y") == 2
        @test size(A, "x") == 3
        @test size(A, "y") == 5
        @test A["x", 2, "y", 3] == 8
        @test A["x", 2] == collect(2:3:15)
        A["x", 2, "y", 3] = -1
        @test A["x", 2, "y", 3] == -1
        v = view(A, "y", 2)
        @test v == [4,5,6]
    end

    @testset "permutedims" begin
        A = AxisArray(collect(reshape(1:15, 3, 5)), :x, :y)
        @test permutedims(A, ("y", "x")) == A'
        @test permutedims(A, ["y", "x"]) == A'
    end
end
