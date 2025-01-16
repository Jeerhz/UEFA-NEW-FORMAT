using Test
include("draw_matchups_first.jl")

# Define the test set
@testset "Testing draw_matchups_first functions" begin

    # Test create_club_index
    @testset "create_club_index" begin
        @test club_index["Roma"] == 1
        @test club_index["Real Sociedad"] == 10
    end

    # Test get_li_nationalities
    @testset "get_li_nationalities" begin
        nationalities = get_li_nationalities(teams)
        @test "Italy" in nationalities
        @test "Latvia" in nationalities
        @test length(nationalities) == 20
    end

    # Test get_index_from_team_name
    @testset "get_index_from_team_name" begin
        index = get_club_index_from_team_name("Ajax")
        @test index == 4
    end

    # Test get_team_nationality
    @testset "get_team_nationality" begin
        nationality = get_team_nationality(teams, 5)
        @test nationality == "Scotland"
    end

    # Test get_team_from_name
    @testset "get_team_from_name" begin
        team = get_team_from_name("Tottenham")
        @test team.nationality == "England"
        @test team.elo == 1791
    end

    # Test get_team_from_index
    @testset "get_team_from_index" begin
        team = get_team_from_club_index(13)
        @test team.club == "Real Sociedad"
        @test team.nationality == "Spain"
    end

    # Test initialize_constraints
    @testset "initialize_constraints" begin
        constraints = initialize_constraints(teams, all_nationalities)
        @test "Roma" in keys(constraints)
        @test constraints["Roma"].nationalities["Italy"] == 2
    end

    # Test update_constraints
    @testset "update_constraints" begin
        constraints = initialize_constraints(teams, all_nationalities)
        roma = get_team_from_name("Roma")
        ajax = get_team_from_name("Ajax")
        update_constraints(roma, ajax, constraints)
        @test ajax.club in constraints["Roma"].played_home
        @test roma.club in constraints["Ajax"].played_ext
    end

    # Test solve_problem
    @testset "solve_problem" begin
        constraints = initialize_constraints(teams, all_nationalities)
        roma = get_team_from_name("Roma")
        ajax = get_team_from_name("Ajax")
        match = (roma, ajax)
        solved = solve_problem(roma, constraints, match)
        @test solved == true
    end

    # Test true_admissible_matches
    @testset "true_admissible_matches" begin
        constraints = initialize_constraints(teams, all_nationalities)
        roma = get_team_from_name("Roma")
        opponents = true_admissible_matches(roma, teams.potB, constraints)
        @test length(opponents) > 0
    end

    # Test tirage_au_sort_uefa_sequential
    @testset "tirage_au_sort_uefa_sequential" begin
        silence_output(() -> uefa_draw_sequential())
        @test isfile("tirage_au_sort.txt")
    end

    # Test tirage_au_sort_randomized
    @testset "tirage_au_sort_randomized" begin
        silence_output(() -> uefa_draw_randomized(1))
        @test isfile("matches_draw_matchups_first_bis.txt")
    end

end
