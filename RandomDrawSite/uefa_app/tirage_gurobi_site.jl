using Gurobi, JuMP, CSV, DataFrames, Random

teams = [
    [   Dict("club" => "Real", "nationality" => "Spain"),
        Dict("club" => "ManCity", "nationality" => "England"),
        Dict("club" => "Bayern", "nationality" => "Germany"),
        Dict("club" => "PSG", "nationality" => "France"), 
        Dict("club" => "Liverpool", "nationality" => "England"),
        Dict("club" => "Inter", "nationality" => "Italy"),
        Dict("club" => "Dortmund", "nationality" => "Germany"),
        Dict("club" => "Leipzig", "nationality" => "Germany"),
        Dict("club" => "Barcelona", "nationality" => "Spain")
    ],

    [
        Dict("club" => "Leverkusen", "nationality" => "Germany"),
        Dict("club" => "Atlético", "nationality" => "Spain"),
        Dict("club" => "Atalanta", "nationality" => "Italy"),
        Dict("club" => "Juventus", "nationality" => "Italy"),
        Dict("club" => "Benfica", "nationality" => "Portugal"),
        Dict("club" => "Arsenal", "nationality" => "England"),
        Dict("club" => "Brugge", "nationality" => "Belgium"),
        Dict("club" => "Shakhtar", "nationality" => "Ukraine"),
        Dict("club" => "Milan", "nationality" => "Italy")
    ],


    [   Dict("club" => "Feyenoord", "nationality" => "Netherlands"),
        Dict("club" => "Sporting", "nationality" => "Portugal"),
        Dict("club" => "Eindhoven", "nationality" => "Netherlands"),
        Dict("club" => "Dinamo", "nationality" => "Croatia"),
        Dict("club" => "Salzburg", "nationality" => "Austria"),
        Dict("club" => "Lille", "nationality" => "France"),
        Dict("club" => "Crvena", "nationality" => "Serbia"),
        Dict("club" => "YB", "nationality" => "Switzerland"),
        Dict("club" => "Celtic", "nationality" => "Scotland")
    ],


    [   Dict("club" => "Bratislava", "nationality" => "Slovakia"),
        Dict("club" => "Monaco", "nationality" => "France"),
        Dict("club" => "Sparta", "nationality" => "Czech Republic"),
        Dict("club" => "Aston Villa", "nationality" => "England"),
        Dict("club" => "Bologna", "nationality" => "Italy"),
        Dict("club" => "Girona", "nationality" => "Spain"),
        Dict("club" => "Stuttgart", "nationality" => "Germany"),
        Dict("club" => "Sturm Graz", "nationality" => "Austria"),
        Dict("club" => "Brest", "nationality" => "France"),
    ]
]


function get_li_nationalities(teams)
    nationalities = Set()
    for pot in teams
        for team in pot
            push!(nationalities, team["nationality"])
        end
    end
    return nationalities
end


function get_index_of_team(team_name, teams)
    for (i, pot) in enumerate(teams)
        for (j, t) in enumerate(pot)
            if t["club"] == team_name
                return (i - 1) * 9 + j
            end
        end
    end
    return nothing
end


function get_team(team_name, teams)
    for (i, pot) in enumerate(teams)
        for (j, t) in enumerate(pot)
            if t["club"] == team_name
                return t
            end
        end
    end
    return nothing
end

function initialize_constraints(teams)
    all_nationalities = get_li_nationalities(teams)
    constraints = Dict()
    for pot in teams
        for team in pot
            # Initialize all nationalities to 0 for each team
            team_nationalities = Dict(nat => 0 for nat in all_nationalities)
            # Then set the team's own nationality to 2
            team_nationalities[team["nationality"]] = 2

            constraints[team["club"]] = Dict(
                "played-home" => Set(),
                "played-ext" => Set(),
                "nationalities" => team_nationalities
            )
        end
    end
    return constraints
end


function update_constraints(home, away, constraints, add=true)
    if add
        push!(constraints[home["club"]]["played-home"], away["club"])
        push!(constraints[away["club"]]["played-ext"], home["club"])
        constraints[home["club"]]["nationalities"][away["nationality"]] += 1
        constraints[away["club"]]["nationalities"][home["nationality"]] += 1
    else
        delete!(constraints[home["club"]]["played-home"], away["club"])
        delete!(constraints[away["club"]]["played-ext"], home["club"])
        constraints[home["club"]]["nationalities"][away["nationality"]] -= 1
        constraints[away["club"]]["nationalities"][home["nationality"]] -= 1
    end
end


function solve_problem(selected_team, constraints, new_match, nationalities, teams)
    model = Model(Gurobi.Optimizer; add_bridges=false)
    set_optimizer_attribute(model, "OutputFlag", 0)
    T=8

    @variable(model, match_vars[1:36, 1:36, 1:8], Bin)

    # Objective function is trivial since we're not maximizing or minimizing a specific goal
    @objective(model, Max, 0)

    # General constraints
    for i in 1:36
        @constraint(model, sum(match_vars[i, i, t] for t in 1:8) == 0)  # A team cannot play against itself
        for j in 1:36
            if i != j
                @constraint(model, sum(match_vars[i, j, t] + match_vars[j, i, t] for t in 1:8) <= 1)  # Each pair of teams plays at most once
            end
        end
    end


    # Contraintes spécifiques pour chaque pot
    for i in 1:36
        for pot_start in 1:9:28
            @constraint(model, sum(match_vars[i, j, t] for t in 1:T, j in pot_start:pot_start+8) == 1)
            @constraint(model, sum(match_vars[j, i, t] for t in 1:T, j in pot_start:pot_start+8) == 1)
        end
    end

    # Constraint for the initially selected admissible match
    home_idx, away_idx = get_index_of_team(new_match[1]["club"], teams), get_index_of_team(new_match[2]["club"], teams)
    selected_idx = get_index_of_team(selected_team["club"], teams)
    @constraint(model, sum(match_vars[selected_idx, home_idx, t] for t in 1:T) == 1)
    @constraint(model, sum(match_vars[away_idx, selected_idx, t] for t in 1:T) == 1)

    # Applying constraints based on previously played matches and nationality constraints
    for (club, cons) in constraints
        club_idx = get_index_of_team(club, teams)
        for home_club in cons["played-home"]
            home_idx = get_index_of_team(home_club, teams)
            @constraint(model, sum(match_vars[club_idx, home_idx, t] for t in 1:T) == 1)
        end
        for away_club in cons["played-ext"]
            away_idx = get_index_of_team(away_club, teams)
            @constraint(model, sum(match_vars[away_idx, club_idx, t] for t in 1:T) == 1)
        end
    end

    # Nationality constraints
    for (i, pot_i) in enumerate(teams)
        for (j, team_j) in enumerate(pot_i)
            team_idx = (i - 1) * 9 + j
            for (k, pot_k) in enumerate(teams)
                for (l, team_l) in enumerate(pot_k)
                    if team_j["nationality"] == team_l["nationality"] && team_idx != ((k - 1) * 9 + l)
                        @constraint(model, sum(match_vars[team_idx, (k - 1) * 9 + l, t] for t in 1:T) == 0)
                    end
                end
            end
        end
    end

    for nationality in nationalities
        for i in 1:36
            @constraint(model, sum(match_vars[i, j, t] + match_vars[j, i, t] for t in 1:8 for j in 1:36 if teams[div(j-1, 9) + 1][(j-1) % 9 + 1]["nationality"] == nationality) <= 2)
        end
    end

    # Solve the problem
    optimize!(model)

    return termination_status(model) == MOI.OPTIMAL
end


#renvoie la liste des equipes du pot oppenent_group contre laquelle l'équipe selected team recoit pour jouer
#rq on a ou bien 0 ou bien 1 équipe
function filter_team_already_played_home(teams, nationalities, selected_team, opponent_group, constraints)
    li_home_selected_team = constraints[selected_team["club"]]["played-home"]
    for home_club_name in li_home_selected_team
        home_team = get_team(home_club_name, teams)
        if home_team in opponent_group
            return home_team
        end
    end
    return nothing
end

#la même mais selected team se déplace cette fois
function filter_team_already_played_away(teams, nationalities, selected_team, opponent_group, constraints)
    li_away_selected_team = constraints[selected_team["club"]]["played-ext"]
    for away_club_name in li_away_selected_team
        away_team = get_team(away_club_name, teams)
        if away_team in opponent_group
            return away_team
        end
    end
    return nothing
end



function true_admissible_matches(teams, nationalities, selected_team, opponent_group, constraints)
    true_matches = []
    #Si on a déjà tirer un adversaire pour l'équipe sélectionné, on en s'embête pas à regarder tous les couples (home,away) possible
    home_team = filter_team_already_played_home(teams, nationalities, selected_team, opponent_group, constraints)
    away_team = filter_team_already_played_away(teams, nationalities, selected_team, opponent_group, constraints)

    #On pourrait directement renvoyer (home_team, away_team) on fait le test par précaution
    if home_team != nothing && away_team != nothing && home_team != away_team
        match = (home_team, away_team)
        if home_team["nationality"] != selected_team["nationality"] && away_team["nationality"] != selected_team["nationality"]
            if solve_problem(selected_team, constraints, match, nationalities, teams) 
                push!(true_matches, match)
            end
        end
    end

    if home_team == nothing && away_team == nothing
        for home in opponent_group
            for away in opponent_group
                if home != away && home["nationality"] != selected_team["nationality"] && away["nationality"] != selected_team["nationality"]&&
                constraints[selected_team["club"]]["nationalities"][home["nationality"]] <= 2 &&
                constraints[selected_team["club"]]["nationalities"][away["nationality"]] <= 2 &&
                constraints[home["club"]]["nationalities"][selected_team["nationality"]] <= 2 &&
                constraints[away["club"]]["nationalities"][selected_team["nationality"]] <= 2 &&
                filter_team_already_played_away(teams, nationalities, home, opponent_group, constraints) == nothing  &&#On vérfie que home ne s'est pas déjà déplacé
                filter_team_already_played_home(teams, nationalities, away, opponent_group, constraints) == nothing
                    match = (home, away)
                    if solve_problem(selected_team, constraints, match, nationalities, teams)
                        push!(true_matches, match)
                    end
                end
            end
        end
    end

    if home_team == nothing && away_team != nothing
        for home in opponent_group
            if home != away_team && home["nationality"] != selected_team["nationality"] && away_team["nationality"] != selected_team["nationality"]&&
            constraints[selected_team["club"]]["nationalities"][home["nationality"]] <= 2 &&
            constraints[home["club"]]["nationalities"][selected_team["nationality"]] <= 2 &&
            filter_team_already_played_away(teams, nationalities, home, opponent_group, constraints) == nothing
                match = (home, away_team)
                if solve_problem(selected_team, constraints, match, nationalities, teams)
                    push!(true_matches, match)
                end
            end
        end
    end

    if home_team != nothing && away_team == nothing
        for away in opponent_group
            if home_team != away && home_team["nationality"] != selected_team["nationality"] && away["nationality"] != selected_team["nationality"]&&
            constraints[selected_team["club"]]["nationalities"][away["nationality"]] <= 2 &&
            constraints[away["club"]]["nationalities"][selected_team["nationality"]] <= 2 &&
            filter_team_already_played_home(teams, nationalities, away, opponent_group, constraints) == nothing
                match = (home_team, away)
                if solve_problem(selected_team, constraints, match, nationalities, teams)
                    push!(true_matches, match)
                end
            end
        end
    end

    return true_matches
end



function tirage_au_sort(teams, constraints; sequential=false, number_tirages=1)
    nationalities = get_li_nationalities(teams)
    li_li_tirages = []
    li_tirages = []
    open("tirage_au_sort_" * "7" * ".txt", "w") do file
        for num_tirage in 1:number_tirages
            for pot in 1:4
                indices = shuffle!(collect(1:9))  # Mélange des indices
                new_tirage_inter = []

                for i in indices
                    li_one_team = []
                    selected_team = teams[pot][i]
                    push!(li_one_team, selected_team["club"])
                    li_opponents_all_pot = []

                    for idx_opponent_pot in 1:4
                        li_opponents = []
                        matches_possible = true_admissible_matches(teams, nationalities, selected_team, teams[idx_opponent_pot], constraints)
                        equipes_possibles = [(match[1]["club"], match[2]["club"]) for match in matches_possible]
                        (home, away) = matches_possible[rand(1:end)]

                        update_constraints(selected_team, home, constraints, true)
                        update_constraints(away, selected_team, constraints, true)
                        push!(li_opponents, equipes_possibles, (home["club"], away["club"]))
                        push!(li_opponents_all_pot, li_opponents)
                    end
                    push!(li_one_team, li_opponents_all_pot)
                    push!(li_tirages, li_one_team)
                end
            end
            push!(li_li_tirages, li_tirages)
        end
        # Affichage des résultats après la fermeture du fichier
        println(file, li_li_tirages)
    end
end



constraints = initialize_constraints(teams)
tirage_au_sort(teams, constraints, sequential=false, number_tirages=1)
println("Tirage au sort terminé")

