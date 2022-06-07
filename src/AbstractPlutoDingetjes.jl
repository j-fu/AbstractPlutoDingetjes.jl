
"""
An abstract package to be implemented by packages/people who create widgets/*dingetjes* for Pluto. If you are just happy using Pluto to make cool stuff, you probably don't want to use this package directly.

Take a look at [`AbstractPlutoDingetjes.Bonds`](@ref).
"""
module AbstractPlutoDingetjes

export Bonds, is_inside_pluto, is_supported_by_display


include_dependency("../Project.toml")

import Pkg
project_relative_path(xs...) = normpath(joinpath(dirname(dirname(pathof(@__MODULE__))), xs...))
p = Pkg.TOML.parsefile(project_relative_path("Project.toml"))

const MY_VERSION = VersionNumber(p["version"])


const _loaded_ref = Ref(false)
function __init__()
    _loaded_ref[] = true
end


"""
```julia
is_supported_by_display(io::IO, f::Union{Function,Module})::Bool
```

Check whether the current runtime/display (Pluto) supports a given feature from `AbstractPlutoDingetjes` (i.e. is the Pluto version new enough). This function should be used inside a `Base.show` method. The first argument should be the `io` provided to the `Base.show` method, and the second argument is the feature to check.

You can use this information to:
- Error the show method of your widget if the runtime/display does not support the required features, or
- Render a simpler version of your widget that does not depend on the advanced Pluto features.

# Example
```julia
import AbstractPlutoDingetjes: is_supported_by_display, Bonds

struct MyCoolDingetje
    values::Vector
end

function Base.show(io::IO, m::MIME"text/html", d::MyCoolDingetje)
    if !(is_supported_by_display(io, Bonds.initial_value) && is_supported_by_display(io, Bonds.transform_value))
        error("This widget does not work in the current version of Pluto.")
    end

    write(io, html"...")
end

```

See also: [`is_inside_pluto`](@ref).
"""
is_supported_by_display(io::IO, x::Any) =
    if !_loaded_ref[]
        error("`is_supported_by_display` can only be called inside a function, **after** your package has been imported. You can not call the function at top-level.")
    else
        features = get(io, :pluto_supported_integration_features, [])
        x ∈ features
    end


"""
```julia
is_inside_pluto()::Bool
```

Are we running inside a Pluto notebook?
"""
is_inside_pluto()::Bool =
    if !_loaded_ref[]
        error("`is_inside_pluto` can only be called inside a function, **after** your package has been imported. You can not call the function at top-level.")
    else
        isdefined(Main, :PlutoRunner)
    end
"""
```julia
is_inside_pluto(io::IO)::Bool
```

Are we rendering inside a Pluto notebook?

This function should be used inside a `Base.show` method, and the first argument should be the `io` provided to the `Base.show` method.
"""
is_inside_pluto(io::IO)::Bool =
    if !_loaded_ref[]
        error("`is_inside_pluto` can only be called inside a function, **after** your package has been imported. You can not call the function at top-level.")
    else
        get(io, :is_pluto, false)
    end


module Bonds
import ..AbstractPlutoDingetjes

export initial_value, transform_value, possible_values, validate_value
export NotGiven, InfinitePossibilities

"""
The initial value of a bond. In a notebook containing `@bind x my_widget`, this will be used in two cases:
1. The value of `x` will be set to `x = AbstractPlutoDingetjes.Bonds.initial_value(my_widget)` during the `@bind` call. This initial value will be used in cells that use `x`, until the widget is rendered in the browser and the first value is received.
2. When running a notebook file without Pluto, e.g. `shell> julia my_notebook.jl`, this value will be used for `x`.

When not overloaded for your widget, it defaults to returning `missing`.

# Example
```julia
struct MySlider
    range::AbstractRange{<:Real}
end

Base.show(io::IO, m::MIME"text/html", s::MySlider) = show(io, m, HTML("<input type=range min=\$(first(s.values)) step=\$(step(s.values)) max=\$(last(s.values))>"))

AbstractPlutoDingetjes.Bonds.initial_value(s::MySlider) = first(s.range)

# Add the following for the same functionality on Pluto versions 0.17.0 and below. Will be ignored in future Pluto versions. See the compat info below.
Base.get(s::MySlider) = first(s.range)

```

!!! info "Note about `transform_value`"
    If you are also using [`transform_value`](@ref) for your widget, then the value returned by `initial_value` should be the value **after** transformation.


!!! compat "Pluto 0.17.1"
    This feature only works in Pluto version 0.17.1 or above.

    Older versions of Pluto used a `Base.get` overload for this (to avoid the need for the `AbstractPlutoDingetjes` package, but we changed our minds 💕). To support all versions of Pluto, use both methods of declaring the initial value.

    Use [`AbstractPlutoDingetjes.is_supported_by_display`](@ref) if you want to check support inside your widget.

"""
initial_value(bond::Any) = missing




"""
Transform a value received from the browser before assigning it to the bound julia variable. In a notebook containing `@bind x my_widget`, Pluto will run `x = AbstractPlutoDingetjes.Bonds.transform_value(my_widget, \$value_from_javascript)`. Without this hook, widgets in JavaScript can only return simple types (numbers, dictionaries, vectors) into bound variables.

When not overloaded for your widget, it defaults to returning the value unchanged, i.e. `x = \$value_from_javascript`.

# Example
```julia
struct MyVectorSlider
    values::Vector{<:Any} # note! a vector of arbitrary objects, not just numbers
end

Base.show(io::IO, m::MIME"text/html", s::MyVectorSlider) = show(io, m, HTML("<input type=range min=1 max=\$(length(s.values))>"))

AbstractPlutoDingetjes.Bonds.transform_value(s::MySlider, value_from_javascript::Int) = s.values[value_from_javascript]
```

!!! compat "Pluto 0.17.1"
    This feature only works in Pluto version 0.17.1 or above. Values are not transformed in older versions.

    Use [`AbstractPlutoDingetjes.is_supported_by_display`](@ref) if you want to check support inside your widget.

"""
transform_value(bond::Any, value_from_javascript::Any) = value_from_javascript




"`NotGiven()` is the default return value of `possible_values(::Any)`."
struct NotGiven end
"Return `InfinitePossibilities()` from your overload of [`possible_values`](@ref) to signify that your bond has no finite set of possible values."
struct InfinitePossibilities end


"""
The possible values of a bond. This is used when generating precomputed PlutoSliderServer states, see [https://github.com/JuliaPluto/PlutoSliderServer.jl/pull/29](https://github.com/JuliaPluto/PlutoSliderServer.jl/pull/29). Not relevant outside of this use (for now...).

The returned value should be an iterable object that you can call `length` on (like a `Vector` or a `Generator` without filter) or return [`InfinitePossibilities()`](@ref) if this set is inifinite.

# Examples
```julia
struct MySlider
    range::AbstractRange{<:Real}
end

Base.show(io::IO, m::MIME"text/html", s::MySlider) = show(io, m, HTML("<input type=range min=\$(first(s.values)) step=\$(step(s.values)) max=\$(last(s.values))>"))

AbstractPlutoDingetjes.Bonds.possible_values(s::MySlider) = s.range
```

```julia
struct MyTextBox end

Base.show(io::IO, m::MIME"text/html", s::MyTextBox) = show(io, m, HTML("<input type=text>"))

AbstractPlutoDingetjes.Bonds.possible_values(s::MySlider) = AbstractPlutoDingetjes.Bonds.InfinitePossibilities()
```

!!! info "Note about `transform_value`"
    If you are also using [`transform_value`](@ref) for your widget, then the values returned by `possible_values` should be the values **before** transformation.

!!! compat "Pluto 0.17.3"
    This feature only works in Pluto version 0.17.3 or above.

"""
possible_values(bond::Any) = NotGiven()


"""
Validate a value received from the browser before "doing the pluto thing". In a notebook containing `@bind x my_widget`, Pluto will run `AbstractPlutoDingetjes.Bonds.validate_value(my_widget, \$value_from_javascript)`. If the result is `false`, then the value from JavaScript is considered "invalid" or "insecure", and no further code will be executed.

This is a protection measure when using your widget on a public PlutoSliderServer, where people could write fake requests that set bonds to arbitrary values.

The returned value should be a `Boolean`.

# Example
```julia
struct MySlider
    range::AbstractRange{<:Real}
end

Base.show(io::IO, m::MIME"text/html", s::MySlider) = show(io, m, HTML("<input type=range min=\$(first(s.values)) step=\$(step(s.values)) max=\$(last(s.values))>"))

AbstractPlutoDingetjes.Bonds.validate_value(s::MySlider, from_browser::Real) = first(s.range) <= from_browser <= last(s.range)
```

!!! info "Note about `transform_value`"
    If you are also using [`transform_value`](@ref) for your widget, then the value validated by `validate_value` will be the value **before** transformation.

!!! info
    The fallback method is `validate_value(::Any, ::Any) = false`. In the example above, this means that if the value is not a `Real`, it is automatically considered invalid.

!!! compat "Pluto TODO"
    This feature only works in Pluto version TODO: NOT RELEASED YET or above.

"""
validate_value(bond::Any, input::Any) = false


end


###########################



module Display
import ..AbstractPlutoDingetjes
export published_to_js


struct _PublishToJS
    x
end
function Base.show(io::IO, ::MIME"text/javascript", ptj::_PublishToJS)
    core_published_to_js = get(io, :pluto_published_to_js, nothing)
    @assert core_published_to_js !== nothing """
    `AbstractPlutoDingetjes.Display.published_to_js` is not supported by this `IO` display. Currently, only Pluto.jl is supported.

    If you are not using `published_to_js` (or you do not know what it is), then please report this error to the package that you are using.

    If you are trying to use `published_to_js` but it is not working, please make sure that:
    - Pluto is up to date.
    - The original IO context is used to render the widget, see the documentation for `published_to_js` to learn more.
    """

    core_published_to_js(io, ptj.x)
end
Base.show(io::IO, ::MIME"text/plain", ptj::_PublishToJS) = show(io, MIME"text/javascript"(), ptj)
Base.show(io::IO, ptj::_PublishToJS) = show(io, MIME"text/javascript"(), ptj)

"""
```julia
AbstractPlutoDingetjes.Display.published_to_js(x)
```

Make the object `x` available to the JS runtime of this cell, to be rendered inside a `<script>` element.

# Example
```julia
import HypertextLiteral: @htl
import AbstractPlutoDingetjes.Display: published_to_js

let
    x = Dict(
        "data" => rand(Float64, 20),
        "name" => "juliette",
    )

    @htl("\""
    <script>
    // we interpolate into JavaScript:
    const x = \$(published_to_js(x))

    console.log(x.name, x.data)
    </script>
    "\"")
end
```

# Note about IO context

The object that `published_to_js` returns needs to be rendered using the IO context that Pluto uses to render cell output. If you are using HypertextLiteral.jl, then this is easy to achieve. 

The example above is using `HypertextLiteral.@htl`, and the cell returns a `HypertextLiteral` object, which will be rendered by Pluto. This means that Pluto will render it using its magical IO context, and all is good!

## Custom show method

Below is a second example, to use when your are writing a **custom HTML show method for your own type**:

```julia
struct MyType
    data
end

function Base.show(io::IO, m::MIME"text/html", x::MyType)

    # ✅ This works
    show(io, m, @htl("\""
    <script>
    let data = \$(published_to_js(x.data))
    console.log(data)
    </script>
    "\""))
end
```

Test it out with:

```julia
MyType([1,2,3])
```

The trick that makes it work is: `show(io, m, @htl(...))`. This will take your `HypertextLiteral` object, and **render it using the `io` object that was passed in**.

## Without HypertextLiteral.jl

The following would not work:

```julia
function Base.show(io::IO, m::MIME"text/html", x::MyType)

    # 🛑 This does not work
    println(io, "\""
    <script>
    let data = \$(published_to_js(x.data))
    console.log(data)
    </script>
    "\"")
end
```

This does not work, because the **string interpolation (i.e. `"\"" ... \$(published_to_js(x.data)) ... "\""`) happens on its own**, without the `io` context used to render it.

The solution is to use HypertextLiteral.jl, passing through the `io` in your show method. If you can't use HypertextLiteral.jl, you could use `repr` to manually render published object to a string, using `io` as the context:

```julia
function Base.show(io::IO, m::MIME"text/html", x::MyType)
    
    # 🟡 This works, but we recommend the HypertextLiteral.jl example instead.
    published_js = repr(published_to_js(x.data); context=io)

    println(io, "\""
    <script>
    let data = \$(published_js)
    console.log(data)
    </script>
    "\"")
end
```

"""
published_to_js(x) = _PublishToJS(x)

end

end
