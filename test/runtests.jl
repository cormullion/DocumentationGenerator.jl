using Test, DocumentationGenerator
using Pkg

const julia = first(Base.julia_cmd())

@test length(DocumentationGenerator.installable_on_version()) > 1500

@testset "run with timeout" begin
    let
        tempfile = tempname()
        str = """
        sleep(4)
        sleep(4)
        write("$tempfile", "hi")
        sleep(3)
        """
        proc, _ = DocumentationGenerator.run_with_timeout(`$julia -e $str`, timeout=7)
        wait(proc)
        @test !success(proc)
        @test !isfile(tempfile)
    end

    let
        tempfile = tempname()
        str = """
        for i = 1:10
        sleep(1)
        println(i)
        end
        write("$tempfile", "hi")
        """
        proc, _ = DocumentationGenerator.run_with_timeout(`$julia -e $str`, timeout=6)
        wait(proc)
        @test success(proc)
        @test String(read(tempfile)) == "hi"
    end

    let
        tempfile = tempname()
        logfile = tempname()
        str = """
        for i in 1:10
        println(i)
        sleep(1)
        end
        write("$tempfile", "hi")
        """
        proc, task = DocumentationGenerator.run_with_timeout(`$julia -e $str`, timeout=3, log=logfile)
        wait(proc)
        @test success(proc)
        @test String(read(tempfile)) == "hi"
        logstr = ""
        for i in 1:10
            logstr *= "$i\n\n"
        end
        wait(task)
        @test isfile(logfile)
        @test String(read(logfile)) == logstr
    end
end


@testset "documentation generation run" begin
    packages = [
        # without docs
        (
            name = "FixedPointNumbers",
            url = "https://github.com/JuliaMath/FixedPointNumbers.jl.git",
            versions = [v"0.5.3"],
            installs = [true],
            doctype = ["default"],
        ),
        (
            name = "ReactionNetworkImporters",
            url = "https://github.com/isaacsas/ReactionNetworkImporters.jl.git",
            versions = [v"0.1.4"],
            installs = [true],
            doctype = ["default"],
        ),
        # with docs
        (
            name = "Example",
            url = "https://github.com/JuliaLang/Example.jl.git",
            versions = [v"0.5.1", v"0.5.2"],
            installs = [true, false],
            doctype = ["default", "real"],
        ),
        (
            name = "DynamicHMC",
            url = "https://github.com/tpapp/DynamicHMC.jl.git",
            versions = [v"1.0.4"],
            installs = [true],
            doctype = ["real"],
        ),
        # with fancy docs
        # not installable (wrong julia version)
        (
            name = "Flux",
            url = "https://github.com/FluxML/Flux.jl.git",
            versions = [v"0.2.2", v"0.7.3", v"0.8.2"],
            installs = [false, true, true],
            doctype = [nothing, "real", "real"],
        ),
    ]

    basepath = @__DIR__
    rm(joinpath(basepath, "logs"), force = true, recursive = true)
    rm(joinpath(basepath, "build"), force = true, recursive = true)

    DocumentationGenerator.build_documentations(
        packages, basepath = basepath, filter_versions = identity
    )

    build = joinpath(basepath, "build")
    @testset "build folder" begin
        for pkg in packages
            pkgbuild = joinpath(build, pkg.name, Base.package_slug(Pkg.METADATA_compatible_uuid(pkg.name), 5))
            @test isdir(pkgbuild)
            for (i, version) in enumerate(pkg.versions)
                println(pkg.name, ": ", version)
                @test isfile(basepath, "logs", string(pkg.name, "-", Pkg.METADATA_compatible_uuid(pkg.name), " ", version, ".log"))

                versiondir = joinpath(pkgbuild, string(version))
                @test isdir(versiondir)
                toml_path = joinpath(versiondir, "meta.toml")
                @test isfile(toml_path)
                toml = Pkg.TOML.parsefile(toml_path)
                pkginstalls = get(toml, "installs", false)
                @test pkginstalls == pkg.installs[i]
                if pkginstalls
                    doctype = get(toml, "doctype", nothing)
                    @test doctype == pkg.doctype[i]
                    @test isfile(joinpath(versiondir, "index.html"))
                    if doctype == "default"
                        @test isdir(joinpath(versiondir, "autodocs"))
                    end
                end
            end
        end
    end
    @testset "log folder" begin

    end
end
