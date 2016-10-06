using Documenter, ImageAxes

makedocs(modules  = [ImageAxes],
         format   = Documenter.Formats.HTML,
         sitename = "ImageAxes",
         pages    = ["index.md"])

deploydocs(
           repo   = "github.com/JuliaImages/ImageAxes.jl.git",
           julia  = "0.5",
           target = "build",
           deps   = nothing,
           make   = nothing
           )
