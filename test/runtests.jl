using Compat.Test
using Quadmath
using SpecialFunctions
using Compat.MathConstants

@testset "Quadmath tests" begin

    for T in (Float64, Int32, Int64)
        @test Float128(T(1)) + Float128(T(2)) == Float128(T(3))
        @test Float128(T(1)) + Float128(T(2)) <= Float128(T(3))
        @test Float128(T(1)) + Float128(T(2)) != Float128(T(4))
        @test Float128(T(1)) + Float128(T(2)) < Float128(T(4))
        @test convert(T, Float128(T(1)) + Float128(T(2))) === T(3)
    end

    for constant in (π, ℯ, γ, catalan, φ)
        @test convert(Float128, constant) == convert(Float128, big(constant))
    end

    @test Base.exponent_one(Float128) == reinterpret(UInt128, Float128(1.0))

    for f in (sin, cos, exp, sqrt, cbrt, erf, besselj0)
        for y in [Float128(1), Float128(13), Float128(200)]
            @test isapprox(convert(Float64, f(y)), f(convert(Float64, y)))
        end
    end

end
