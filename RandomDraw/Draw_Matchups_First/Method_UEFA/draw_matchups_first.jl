############################################ IMPORTS ############################################

using Gurobi, JuMP, CSV, DataFrames, Random, Base.Threads, Logging

####################################### GLOBAL VARIABLES #######################################

struct Team
    club::String
    nationality::String
    elo::Int
    uefa::Float64
end

struct TeamsContainer
    pot1::NTuple{9,Team}
    pot2::NTuple{9,Team}
    pot3::NTuple{9,Team}
    pot4::NTuple{9,Team}
    index::Dict{String,Team}
end

struct Constraint
    played_home::Set{String}
    played_ext::Set{String}
    nationalities::Dict{String,Int}
end

const env = Gurobi.Env() # environnement for Gurobi

# to create an instance of TeamsContainer
function create_teams_container(
    pot1::NTuple{9,Team},
    pot2::NTuple{9,Team},
    pot3::NTuple{9,Team},
    pot4::NTuple{9,Team}
)::TeamsContainer
    # Build the index dictionary by iterating over each pot
    index = Dict(team.club => team for pot in (pot1, pot2, pot3, pot4) for team in pot)
    # Create and return the TeamsContainer instance
    return TeamsContainer(pot1, pot2, pot3, pot4, index)
end

# Europa League
pot1 = (
    Team("Roma", "Italy", 1812, 101),
    Team("Man Utd", "England", 1779, 92),
    Team("Porto", "Portugal", 1778, 77),
    Team("Ajax", "Netherlands", 1619, 67),
    Team("Rangers", "Scotland", 1618, 63),
    Team("Frankfurt", "Germany", 1697, 60),
    Team("Lazio", "Italy", 1785, 54),
    Team("Tottenham", "England", 1791, 54),
    Team("Slavia Praha", "Czech Republic", 1702, 53)
)

pot2 = (
    Team("Real Sociedad", "Spain", 1767, 51),
    Team("Olympiacos", "Greece", 1639, 50),
    Team("AZ Alkmaar", "Netherlands", 1591, 50),
    Team("Braga", "Portugal", 1636, 49),
    Team("Lyon", "France", 1713, 44),
    Team("PAOK", "Greece", 1639, 37),
    Team("Fenerbahçe", "Turkey", 1714, 36),
    Team("M. Tel-Aviv", "Israel", 1614, 35.5),
    Team("Ferencvaros", "Hungary", 1479, 35)
)

pot3 = (
    Team("Qarabag", "Azerbaijan", 1597, 33),
    Team("Galatasaray", "Turkey", 1721, 31.5),
    Team("Viktoria Plzen", "Czech Republic", 1572, 28),
    Team("Bodo/Glimt", "Norway", 1598, 28),
    Team("Union SG", "Belgium", 1701, 27),
    Team("Dynamo Kyiv", "Ukraine", 1517, 26.5),
    Team("Ludogorets", "Bulgaria", 1512, 26),
    Team("Midtjylland", "Denmark", 1624, 25.5),
    Team("Malmo", "Sweden", 1493, 18.5)
)

pot4 = (
    Team("Athletic Club", "Spain", 1764, 17.897),
    Team("Hoffenheim", "Germany", 1683, 17.324),
    Team("Nice", "France", 1703, 17),
    Team("Anderlecht", "Belgium", 1640, 14.5),
    Team("Twente", "Netherlands", 1627, 12.650),
    Team("Besiktas", "Turkey", 1484, 12),
    Team("FCSB", "Romania", 1434, 10.5),
    Team("RFS", "Latvia", 1225, 8),
    Team("Elfsborg", "Sweden", 1403, 4.3)
)


# Champions League
# pot1 = (
#     Team("Real", "Spain", 1985, 136),
#     Team("ManCity", "England", 2057, 148),
#     Team("Bayern", "Germany", 1904, 144),
#     Team("PSG", "France", 1893, 116),
#     Team("Liverpool", "England", 1908, 114),
#     Team("Inter", "Italy", 1960, 101),
#     Team("Dortmund", "Germany", 1874, 97),
#     Team("Leipzig", "Germany", 1849, 97),
#     Team("Barcelona", "Spain", 1894, 91)
# )

# pot2 = (
#     Team("Leverkusen", "Germany", 1929, 90),
#     Team("Atlético", "Spain", 1830, 89),
#     Team("Atalanta", "Italy", 1879, 81),
#     Team("Juventus", "Italy", 1839, 80),
#     Team("Benfica", "Portugal", 1824, 79),
#     Team("Arsenal", "England", 1957, 72),
#     Team("Brugge", "Belgium", 1703, 64),
#     Team("Shakhtar", "Ukraine", 1573, 63),
#     Team("Milan", "Italy", 1821, 59)
# )

# pot3 = (
#     Team("Feyenoord", "Netherlands", 1747, 57),
#     Team("Sporting", "Portugal", 1824, 54.5),
#     Team("Eindhoven", "Netherlands", 1794, 54),
#     Team("Dinamo", "Croatia", 1584, 50),
#     Team("Salzburg", "Austria", 1693, 50),
#     Team("Lille", "France", 1785, 47),
#     Team("Crvena", "Serbia", 1734, 40),
#     Team("YB", "Switzerland", 1566, 34.5),
#     Team("Celtic", "Scotland", 1646, 32)
# )

# pot4 = (
#     Team("Bratislava", "Slovakia", 1703, 30.5),
#     Team("Monaco", "France", 1780, 24),
#     Team("Sparta", "Czech Republic", 1716, 22.5),
#     Team("Aston Villa", "England", 1772, 20.86),
#     Team("Bologna", "Italy", 1777, 18.056),
#     Team("Girona", "Spain", 1791, 17.897),
#     Team("Stuttgart", "Germany", 1795, 17.324),
#     Team("Sturm Graz", "Austria", 1610, 14.500),
#     Team("Brest", "France", 1685, 13.366)
# )

# Use the helper function to create the TeamsContainer instance
const teams = create_teams_container(pot1, pot2, pot3, pot4)

#################### TYPE DE TEAMS  #################################################################

function create_club_index(teams::TeamsContainer)::Dict{String,Int}
    club_index = Dict{String,Int}()
    for (i, pot) in enumerate((teams.pot1, teams.pot2, teams.pot3, teams.pot4))
        for (j, team) in enumerate(pot)
            club_index[team.club] = (i - 1) * 9 + j
        end
    end
    return club_index
end

const club_index = create_club_index(teams)

function get_li_nationalities(teams::TeamsContainer)::Set{String}
    nationalities = Set{String}()
    for pot in (teams.pot1, teams.pot2, teams.pot3, teams.pot4)
        for team in pot
            push!(nationalities, team.nationality)
        end
    end
    return nationalities
end

const all_nationalities = get_li_nationalities(teams)

function get_index_from_team_name(team_name::String)::Int
    return club_index[team_name]
end

function get_team_nationality(teams::TeamsContainer, index::Int)::String
    pot_index = div(index - 1, 9) + 1  # Détermine le pot (1 à 4)
    team_index = (index - 1) % 9 + 1   # Détermine l'index dans le pot (1 à 9)

    # Récupérer le bon pot en fonction de pot_index
    if pot_index == 1
        return teams.pot1[team_index].nationality
    elseif pot_index == 2
        return teams.pot2[team_index].nationality
    elseif pot_index == 3
        return teams.pot3[team_index].nationality
    elseif pot_index == 4
        return teams.pot4[team_index].nationality
    else
        error("Index out of bounds")
    end
end

function get_team_from_name(team_name::String)::Team
    return teams.index[team_name]
end

function get_team_from_index(team_index::Int)::Team
    pot_index = div(team_index - 1, 9) + 1  # Détermine le pot (1 à 4)
    team_index = (team_index - 1) % 9 + 1   # Détermine l'index dans le pot (1 à 9)

    # Récupérer le bon pot en fonction de pot_index
    if pot_index == 1
        return teams.pot1[team_index]
    elseif pot_index == 2
        return teams.pot2[team_index]
    elseif pot_index == 3
        return teams.pot3[team_index]
    elseif pot_index == 4
        return teams.pot4[team_index]
    else
        error("Index out of bounds")
    end
end

function initialize_constraints(teams::TeamsContainer, all_nationalities::Set{String})::Dict{String,Constraint}
    constraints = Dict{String,Constraint}()
    for pot in (teams.pot1, teams.pot2, teams.pot3, teams.pot4)
        for team in pot
            # Initialize all nationalities to 0 for each team
            team_nationalities = Dict(nat => 0 for nat in all_nationalities)
            # Set the team's own nationality to 2
            team_nationalities[team.nationality] = 2

            # Create a Constraint instance for each team
            constraints[team.club] = Constraint(
                Set{String}(),         # played_home initialized as an empty Set
                Set{String}(),         # played_ext initialized as an empty Set
                team_nationalities     # nationalities dictionnary
            )
        end
    end
    return constraints
end

# Update the constraints based on the new match
# home is the team playing at home and away is the team playing away
function update_constraints(home::Team, away::Team, constraints::Dict{String,Constraint})
    if (away.club in constraints[home.club].played_home) || (home.club in constraints[away.club].played_ext)
        @warn "Match already played. Home: $(home.club), Away: $(away.club)"
    else
        constraints[home.club].nationalities[away.nationality] += 1
        constraints[away.club].nationalities[home.nationality] += 1
    end
    push!(constraints[home.club].played_home, away.club)
    push!(constraints[away.club].played_ext, home.club)
end

function silence_output(f::Function)
    original_stdout = stdout
    original_stderr = stderr
    redirect_stdout(devnull)
    redirect_stderr(devnull)
    try
        return f()
    finally
        redirect_stdout(original_stdout)
        redirect_stderr(original_stderr)
    end
end

function solve_problem(selected_team::Team, constraints::Dict{String,Constraint}, new_match::NTuple{2,Team})::Bool
    model = Model(Gurobi.Optimizer; add_bridges=false)
    set_optimizer_attribute(model, "Seed", rand(1:1000000000)) # random solution
    set_optimizer_attribute(model, "OutputFlag", 0)
    set_optimizer_attribute(model, "LogToConsole", 0) # No logging to consol
    T = 8

    @variable(model, match_vars[1:36, 1:36, 1:8], Bin)

    # Objective function is trivial since we're not maximizing or minimizing a specific goal
    @objective(model, Max, 0)

    # General constraints
    @constraint(model, [i = 1:36], sum(match_vars[i, i, t] for t in 1:8) == 0) # A team cannot play against itself

    @constraint(model, [i = 1:36, j = 1:36; i != j], sum(match_vars[i, j, t] + match_vars[j, i, t] for t in 1:8) <= 1)  # Each pair of teams plays at most once


    # Contraintes spécifiques pour chaque pot
    for pot_start in 1:9:28
        @constraint(model, [i = 1:36], sum(match_vars[i, j, t] for t in 1:8, j in pot_start:pot_start+8) == 1)
        @constraint(model, [i = 1:36], sum(match_vars[j, i, t] for t in 1:8, j in pot_start:pot_start+8) == 1)
    end


    # Constraint for the initially selected admissible match
    home_idx, away_idx = get_index_from_team_name(new_match[1].club), get_index_from_team_name(new_match[2].club)
    selected_idx = get_index_from_team_name(selected_team.club)
    @constraint(model, sum(match_vars[selected_idx, home_idx, t] for t in 1:T) == 1)
    @constraint(model, sum(match_vars[away_idx, selected_idx, t] for t in 1:T) == 1)

    # Applying constraints based on previously played matches and nationality constraints
    for (club, cons) in constraints
        club_idx = get_index_from_team_name(club)
        for home_club in cons.played_home
            home_idx = get_index_from_team_name(home_club)
            @constraint(model, sum(match_vars[club_idx, home_idx, t] for t in 1:T) == 1)
        end
        for away_club in cons.played_ext
            away_idx = get_index_from_team_name(away_club)
            @constraint(model, sum(match_vars[away_idx, club_idx, t] for t in 1:T) == 1)
        end
    end

    # Nationality constraints
    for (i, pot_i) in enumerate((teams.pot1, teams.pot2, teams.pot3, teams.pot4))
        for (j, team_j) in enumerate(pot_i)
            team_idx = (i - 1) * 9 + j
            for (k, pot_k) in enumerate((teams.pot1, teams.pot2, teams.pot3, teams.pot4))
                for (l, team_l) in enumerate(pot_k)
                    if team_j.nationality == team_l.nationality && team_idx != ((k - 1) * 9 + l)
                        @constraint(model, sum(match_vars[team_idx, (k-1)*9+l, t] for t in 1:T) == 0)
                    end
                end
            end
        end
    end

    for nationality in all_nationalities
        for i in 1:36
            @constraint(model, sum(
                match_vars[i, j, t] + match_vars[j, i, t]
                for t in 1:8
                for j in 1:36
                if get_team_nationality(teams, j) == nationality
            ) <= 2)
        end
    end

    # Solve the problem
    optimize!(model)

    return termination_status(model) == MOI.OPTIMAL
end


#renvoie la liste des equipes du pot oppenent_group contre laquelle l'équipe selected team recoit pour jouer
#rq on a ou bien 0 ou bien 1 équipe
function filter_team_already_played_home(selected_team::Team, opponent_group::NTuple{9,Team}, constraints::Dict{String,Constraint})::Union{Team,Nothing}
    li_home_selected_team = constraints[selected_team.club].played_home
    for home_club_name in li_home_selected_team
        home_team = get_team_from_name(home_club_name)
        if home_team in opponent_group
            return home_team
        end
    end
    return nothing
end

#la même mais selected team se déplace cette fois
function filter_team_already_played_away(selected_team::Team, opponent_group::NTuple{9,Team}, constraints::Dict{String,Constraint})::Union{Team,Nothing}
    li_away_selected_team = constraints[selected_team.club].played_ext
    for away_club_name in li_away_selected_team
        away_team = get_team_from_name(away_club_name)
        if away_team in opponent_group
            return away_team
        end
    end
    return nothing
end


function true_admissible_matches(selected_team::Team, opponent_group::NTuple{9,Team}, constraints::Dict{String,Constraint})::Vector{Tuple{Team,Team}}
    true_matches = Vector{Tuple{Team,Team}}()
    #Si on a déjà tirer un adversaire pour l'équipe sélectionné, on en s'embête pas à regarder tous les couples (home,away) possible
    home_team = filter_team_already_played_home(selected_team, opponent_group, constraints)
    away_team = filter_team_already_played_away(selected_team, opponent_group, constraints)

    #On pourrait directement renvoyer (home_team, away_team) on fait le test par précaution
    if home_team !== nothing && away_team !== nothing && home_team != away_team
        match = (home_team, away_team)
        #On vérifie que les adversaires ne sont pas de la même nationalité que selected_team
        if home_team.nationality != selected_team.nationality && away_team.nationality != selected_team.nationality
            if solve_problem(selected_team, constraints, match)
                push!(true_matches, match)
            end
        end
    end

    if home_team === nothing && away_team === nothing
        for home in opponent_group
            for away in opponent_group
                if home != away && home.nationality != selected_team.nationality && away.nationality != selected_team.nationality &&
                   constraints[selected_team.club].nationalities[home.nationality] <= 2 &&
                   constraints[selected_team.club].nationalities[away.nationality] <= 2 &&
                   constraints[home.club].nationalities[selected_team.nationality] <= 2 &&
                   constraints[away.club].nationalities[selected_team.nationality] <= 2 &&
                   filter_team_already_played_away(home, opponent_group, constraints) === nothing &&#On vérfie que home ne s'est pas déjà déplacé
                   filter_team_already_played_home(away, opponent_group, constraints) === nothing
                    match = (home, away)
                    if solve_problem(selected_team, constraints, match)
                        push!(true_matches, match)
                    end
                end
            end
        end
    end

    if home_team === nothing && away_team !== nothing
        for home in opponent_group
            if home != away_team &&
               home.nationality != selected_team.nationality &&
               away_team.nationality != selected_team.nationality &&
               constraints[selected_team.club].nationalities[home.nationality] <= 2 &&
               constraints[home.club].nationalities[selected_team.nationality] <= 2 &&
               filter_team_already_played_away(home, opponent_group, constraints) === nothing
                match = (home, away_team)
                if solve_problem(selected_team, constraints, match)
                    push!(true_matches, match)
                end
            end
        end
    end

    if home_team !== nothing && away_team === nothing
        for away in opponent_group
            if home_team != away &&
               home_team.nationality != selected_team.nationality &&
               away.nationality != selected_team.nationality &&
               constraints[selected_team.club].nationalities[away.nationality] <= 2 &&
               constraints[away.club].nationalities[selected_team.nationality] <= 2 &&
               filter_team_already_played_home(away, opponent_group, constraints) === nothing
                match = (home_team, away)
                if solve_problem(selected_team, constraints, match)
                    push!(true_matches, match)
                end
            end
        end
    end
    return true_matches
end

function tirage_au_sort_uefa_sequential()
    constraints = initialize_constraints(teams, all_nationalities)
    println("Début du tirage au sort")
    start_time = time()
    matches_list = []

    open("tirage_au_sort.txt", "w") do file
        for pot_index in 1:4
            println("Mélange des indices pour le pot $pot_index")
            indices = shuffle!(collect(1:9))  # Mélange des indices
            # Accès au pot correspondant dans TeamsContainer
            pot = if pot_index == 1
                teams.pot1
            elseif pot_index == 2
                teams.pot2
            elseif pot_index == 3
                teams.pot3
            elseif pot_index == 4
                teams.pot4
            else
                error("Index de pot invalide")
            end

            for i in indices
                selected_team = pot[i]
                li_opponents = [(selected_team.club, "")]

                println(file, "Tirage pour l'équipe : ", selected_team.club)
                
                for idx_opponent_pot in 1:4
                    opponent_pot = if idx_opponent_pot == 1
                        teams.pot1
                    elseif idx_opponent_pot == 2
                        teams.pot2
                    elseif idx_opponent_pot == 3
                        teams.pot3
                    elseif idx_opponent_pot == 4
                        teams.pot4
                    else
                        error("Index de pot invalide")
                    end

                    matches_possible = true_admissible_matches(selected_team, opponent_pot, constraints)

                    equipes_possibles = [(match[1].club, match[2].club) for match in matches_possible]
                    selected_match = matches_possible[rand(1:end)]
                    home, away = selected_match

                    println(file, "Adversaires possibles du pot $idx_opponent_pot : ", equipes_possibles)

                    println("")
                    println("Equipe sélectionnée: $(selected_team.club)")
                    println("Pot sélectionné: $(idx_opponent_pot)")
                    println("")
                    println("Liste des couples possibles")
                    println(equipes_possibles)
                    println("")
                    println("Match sélectionné dans le pot $(idx_opponent_pot) : $(home.club) vs $(away.club)")
                    println("Appuyez sur la barre d'espace suivi d'Entrée pour continuer...")

                    while true
                        input = readline()
                        if input == " "
                            break
                        else
                            println("Vous n'avez pas appuyé sur la barre d'espace suivi d'Entrée, réessayez.")
                        end
                    end

                    update_constraints(selected_team, home, constraints)
                    update_constraints(away, selected_team, constraints)
                    push!(li_opponents, (home.club, away.club))
                end

                println(file, li_opponents)
                println(file, "\n---\n")  # Ajoute une ligne de séparation après chaque équipe
                push!(matches_list, li_opponents)
            end
            println(file, "\n\n")  # Ajoute un espace supplémentaire après chaque pot pour une meilleure visibilité
        end
    end

    println("Résultats du tirage au sort enregistrés dans le fichier 'tirage_au_sort.txt'")
    total_time = time() - start_time
    println("Temps total d'exécution de tirage_au_sort : $(round(total_time, digits=2)) secondes")
end



function tirage_au_sort_uefa(nb_draw::Int)
    elo_opponents = zeros(Float64, 36, nb_draw)
    uefa_opponents = zeros(Float64, 36, nb_draw)
    matches = zeros(Int, 36, 8, nb_draw)
    @threads for s in 1:nb_draw
        constraints = initialize_constraints(teams, all_nationalities)
        for pot_index in 1:4
            indices = shuffle!(collect(1:9))  # Mélange des indices

            # Accès au pot correspondant dans TeamsContainer
            pot = if pot_index == 1
                teams.pot1
            elseif pot_index == 2
                teams.pot2
            elseif pot_index == 3
                teams.pot3
            elseif pot_index == 4
                teams.pot4
            end

            for i in indices
                selected_team = pot[i]

                for idx_opponent_pot in 1:4
                    opponent_pot = if idx_opponent_pot == 1
                        teams.pot1
                    elseif idx_opponent_pot == 2
                        teams.pot2
                    elseif idx_opponent_pot == 3
                        teams.pot3
                    elseif idx_opponent_pot == 4
                        teams.pot4
                    end

                    home, away = true_admissible_matches(selected_team, opponent_pot, constraints)[rand(1:end)]

                    matches[get_index_from_team_name(selected_team.club), 2*idx_opponent_pot-1, s] = get_index_from_team_name(home.club)
                    matches[get_index_from_team_name(selected_team.club), 2*idx_opponent_pot, s] = get_index_from_team_name(away.club)

                    elo_opponents[get_index_from_team_name(selected_team.club), s] += away.elo + home.elo
                    uefa_opponents[get_index_from_team_name(selected_team.club), s] += away.uefa + home.uefa

                    update_constraints(selected_team, home, constraints)
                    update_constraints(away, selected_team, constraints)
                end
            end
        end
    end

    open("draws_draw_matchups_first_elo_bis.txt", "a") do file
        for i in 1:nb_draw
            row = join(elo_opponents[:, i], " ")
            write(file, row * "\n")
        end
    end

    open("draws_draw_matchups_first_uefa_bis.txt", "a") do file
        for i in 1:nb_draw
            row = join(uefa_opponents[:, i], " ")
            write(file, row * "\n")
        end
    end

    open("matches_draw_matchups_first_bis.txt", "a") do file
        for i in 1:nb_draw
            for team in 1:36
                home_matches = [(team, matches[team, k, i]) for k in 1:2:8]
                home_row = join(home_matches, " ")
                write(file, home_row * " ")
                away_matches = [(matches[team, k, i], team) for k in 2:2:8]
                away_row = join(away_matches, " ")
                write(file, away_row * " ")
            end
            write(file, "\n")
        end
    end

    return 0
end




function tirage_au_sort_randomized(nb_draw::Int)
    elo_opponents = zeros(Float64, 36, nb_draw)
    uefa_opponents = zeros(Float64, 36, nb_draw)
    matches = zeros(Int, 36, 8, nb_draw)
    for s in 1:nb_draw
        constraints = initialize_constraints(teams, all_nationalities)
        shuffled_order = shuffle(collect(1:36)) # Mélange de l'ordre des équipes pour qui nous allons déterminer les adversaires
        open("order_selection.txt", "a") do file
            write(file, shuffled_order)
        end
        @info "Shuffled order: $shuffled_order"
        for index_team in shuffled_order
            @info "Selected team index: $index_team"
            selected_team = get_team_from_index(index_team)
            @info "Selected team: $(selected_team.club)"
            opponent_pots_shuffled_indexes = shuffle(collect(1:4))  # Mélange des indices
            @info "Shuffled opponent pots indexes: $opponent_pots_shuffled_indexes"
            for idx_opponent_pot in opponent_pots_shuffled_indexes
                opponent_pot = if idx_opponent_pot == 1
                    teams.pot1
                elseif idx_opponent_pot == 2
                    teams.pot2
                elseif idx_opponent_pot == 3
                    teams.pot3
                elseif idx_opponent_pot == 4
                    teams.pot4
                end

                home = nothing
                away = nothing
                try
                    home, away = true_admissible_matches(selected_team, opponent_pot, constraints)[rand(1:end)]
                    @info "Selected home team: $(home.club)"
                    @info "Selected away team: $(away.club)"
                catch e
                    @error "Error while trying to find a match for $(selected_team.club) against pot $idx_opponent_pot"
                    @error "The constraints for that team are $(constraints[selected_team.club])"
                    throw(e)
                end

                matches[get_index_from_team_name(selected_team.club), 2*idx_opponent_pot-1, s] = get_index_from_team_name(home.club)
                matches[get_index_from_team_name(selected_team.club), 2*idx_opponent_pot, s] = get_index_from_team_name(away.club)

                elo_opponents[get_index_from_team_name(selected_team.club), s] += away.elo + home.elo
                uefa_opponents[get_index_from_team_name(selected_team.club), s] += away.uefa + home.uefa

                update_constraints(selected_team, home, constraints)
                update_constraints(away, selected_team, constraints)
            end
        end
    end

    open("draws_draw_matchups_first_elo_bis.txt", "a") do file
        for i in 1:nb_draw
            row = join(elo_opponents[:, i], " ")
            write(file, row * "\n")
        end
    end

    open("draws_draw_matchups_first_uefa_bis.txt", "a") do file
        for i in 1:nb_draw
            row = join(uefa_opponents[:, i], " ")
            write(file, row * "\n")
        end
    end

    open("matches_draw_matchups_first_bis.txt", "a") do file
        for i in 1:nb_draw
            for team in 1:36
                home_matches = [(team, matches[team, k, i]) for k in 1:2:8]
                home_row = join(home_matches, " ")
                write(file, home_row * " ")
                away_matches = [(matches[team, k, i], team) for k in 2:2:8]
                away_row = join(away_matches, " ")
                write(file, away_row * " ")
            end
            write(file, "\n")
        end
    end

    return 0
end




###################################### COMMANDS ###################################### 

println("Nombre de threads utilisés : ", Threads.nthreads())

const n_simul = 1

@time begin
    tirage_au_sort_randomized(n_simul)
end


