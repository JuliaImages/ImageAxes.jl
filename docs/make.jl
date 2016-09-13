using Documenter, ImageAxes

makedocs(modules  = [ImageAxes],
         format   = Documenter.Formats.HTML,
         sitename = "ImageAxes",
         pages    = ["index.md"])

deploydocs(
           repo = "github.com/JuliaImages/ImageAxes.jl.git"
           )
