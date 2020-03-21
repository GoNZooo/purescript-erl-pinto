{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "erl-pinto"
, dependencies =
    [ "console"
    , "effect"
    , "psci-support"
    , "erl-cowboy"
    , "erl-process"
    ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
, backend = "purerl"
}
