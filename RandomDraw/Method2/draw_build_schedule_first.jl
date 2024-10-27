############################################ IMPORTS ############################################

using JuMP, Gurobi
using Plots
using Statistics
using Profile # profiler
using Base.Threads # parallelization


####################################### GLOBAL VARIABLES #######################################


const p = 4 # number of pots
const q = 9 # number of teams per pot
const n = 36  # number of teams (= pq)

const opponents = # opponents[i] : list of placeholders connected to placeholder i
[[18, 9, 19, 36, 11, 2, 32, 26],
 [31, 21, 3, 16, 27, 1, 14, 33],
 [10, 32, 2, 13, 26, 22, 36, 4], 
 [5, 14, 29, 35, 10, 23, 25, 3], 
 [4, 11, 22, 6, 30, 34, 13, 19], 
 [16, 27, 33, 5, 21, 29, 7, 12], 
 [20, 8, 15, 24, 28, 17, 6, 30], 
 [23, 7, 12, 25, 9, 31, 35, 18], 
 [34, 1, 17, 20, 8, 15, 24, 28], 
 [3, 35, 21, 18, 4, 32, 22, 11], 
 [12, 5, 27, 23, 1, 33, 31, 10], 
 [11, 36, 8, 26, 19, 13, 30, 6], 
 [19, 28, 14, 3, 35, 12, 5, 21], 
 [24, 4, 13, 30, 34, 20, 2, 15], 
 [33, 25, 7, 29, 16, 9, 23, 14], 
 [6, 17, 32, 2, 15, 24, 26, 34], 
 [29, 16, 9, 31, 25, 7, 18, 27], 
 [1, 22, 20, 10, 36, 28, 17, 8], 
 [13, 20, 1, 28, 12, 27, 33, 5], 
 [7, 19, 18, 9, 31, 14, 21, 35], 
 [32, 2, 10, 22, 6, 30, 20, 13], 
 [35, 18, 5, 21, 23, 3, 10, 29], 
 [8, 34, 36, 11, 22, 4, 15, 24], 
 [14, 31, 25, 7, 29, 16, 9, 23], 
 [30, 15, 24, 8, 17, 26, 4, 36], 
 [27, 33, 28, 12, 3, 25, 16, 1], 
 [26, 6, 11, 32, 2, 19, 34, 17], 
 [36, 13, 26, 19, 7, 18, 29, 9], 
 [17, 30, 4, 15, 24, 6, 28, 22], 
 [25, 29, 31, 14, 5, 21, 12, 7], 
 [2, 24, 30, 17, 20, 8, 11, 32], 
 [21, 3, 16, 27, 33, 10, 1, 31], 
 [15, 26, 6, 34, 32, 11, 19, 2], 
 [9, 23, 35, 33, 14, 5, 27, 16], 
 [22, 10, 34, 4, 13, 36, 8, 20], 
 [28, 12, 23, 1, 18, 35, 3, 25]]

 const teams = [
    Dict("club" => "Real", "nationality" => "Spain", "elo" => 1985, "uefa" => 136),                    #1
    Dict("club" => "ManCity", "nationality" => "England", "elo" => 2057, "uefa" => 148),               #2
    Dict("club" => "Bayern", "nationality" => "Germany", "elo" => 1904, "uefa" => 144),                #3
    Dict("club" => "PSG", "nationality" => "France", "elo" => 1893, "uefa" => 116),                    #4
    Dict("club" => "Liverpool", "nationality" => "England", "elo" => 1908, "uefa" => 114),             #5
    Dict("club" => "Inter", "nationality" => "Italy", "elo" => 1960, "uefa" => 101),                   #6
    Dict("club" => "Dortmund", "nationality" => "Germany", "elo" => 1874, "uefa" => 97),               #7
    Dict("club" => "Leipzig", "nationality" => "Germany", "elo" => 1849, "uefa" => 97),                #8
    Dict("club" => "Barcelona", "nationality" => "Spain", "elo" => 1894, "uefa" => 91),                #9
    Dict("club" => "Leverkusen", "nationality" => "Germany", "elo" => 1929, "uefa" => 90),             #10
    Dict("club" => "Atlético", "nationality" => "Spain", "elo" => 1830, "uefa" => 89),                 #11
    Dict("club" => "Atalanta", "nationality" => "Italy", "elo" => 1879, "uefa" => 81),                 #12
    Dict("club" => "Juventus", "nationality" => "Italy", "elo" => 1839, "uefa" => 80),                 #13
    Dict("club" => "Benfica", "nationality" => "Portugal", "elo" => 1824, "uefa" => 79),               #14
    Dict("club" => "Arsenal", "nationality" => "England", "elo" => 1957, "uefa" => 72),                #15
    Dict("club" => "Brugge", "nationality" => "Belgium", "elo" => 1703, "uefa" => 64),                 #16
    Dict("club" => "Shakhtar", "nationality" => "Ukraine", "elo" => 1573, "uefa" => 63),               #17
    Dict("club" => "Milan", "nationality" => "Italy", "elo" => 1821, "uefa" => 59),                    #18
    Dict("club" => "Feyenoord", "nationality" => "Netherlands", "elo" => 1747, "uefa" => 57),          #19
    Dict("club" => "Sporting", "nationality" => "Portugal", "elo" => 1824, "uefa" => 54.5),            #20
    Dict("club" => "Eindhoven", "nationality" => "Netherlands", "elo" => 1794, "uefa" => 54),          #21
    Dict("club" => "Dinamo", "nationality" => "Croatia", "elo" => 1584, "uefa" => 50),                 #22
    Dict("club" => "Salzburg", "nationality" => "Austria", "elo" => 1693, "uefa" => 50),               #23
    Dict("club" => "Lille", "nationality" => "France", "elo" => 1785, "uefa" => 47),                   #24
    Dict("club" => "Crvena", "nationality" => "Serbia", "elo" => 1734, "uefa" => 40),                  #25
    Dict("club" => "YB", "nationality" => "Switzerland", "elo" => 1566, "uefa" => 34.5),               #26
    Dict("club" => "Celtic", "nationality" => "Scotland", "elo" => 1646, "uefa" => 32),                #27
    Dict("club" => "Bratislava", "nationality" => "Slovakia", "elo" => 1703, "uefa" => 30.5),          #28
    Dict("club" => "Monaco", "nationality" => "France", "elo" => 1780, "uefa" => 24),                  #29
    Dict("club" => "Sparta", "nationality" => "Czech Republic", "elo" => 1716, "uefa" => 22.5),        #30
    Dict("club" => "Aston Villa", "nationality" => "England", "elo" => 1772, "uefa" => 20.86),         #31
    Dict("club" => "Bologna", "nationality" => "Italy", "elo" => 1777, "uefa" => 18.056),              #32
    Dict("club" => "Girona", "nationality" => "Spain", "elo" => 1791, "uefa" => 17.897),               #33
    Dict("club" => "Stuttgart", "nationality" => "Germany", "elo" => 1795, "uefa" => 17.324),          #34
    Dict("club" => "Sturm Graz", "nationality" => "Austria", "elo" => 1610, "uefa" => 14.500),         #35
    Dict("club" => "Brest", "nationality" => "France", "elo" => 1685, "uefa" => 13.366)                #36 
]

const team_nationalities = # team_nationalities[i] : nationality of team i
(1, 2, 3, 4, 2, 5, 3, 3, 1, 3, 1, 5, 5, 6, 2, 7, 8, 5, 9, 6, 9, 10, 11, 4, 12, 13, 14, 15, 4, 16, 2, 5, 1, 3, 11, 4)

const nationalities = # nationalities[i] : list of teams of nationality i 
( (1, 9, 11, 33), # Spain
  (2, 5, 15, 31), # England
  (3, 7, 8, 10, 34), #  Germany
  (4, 24, 29, 36), # France
  (6, 12, 13, 18, 32), # Italy
  (14, 20), # Portugal
  (16), # Belgium
  (17), # Ukraine
  (19, 21), # Netherlands
  (22), # Croatia
  (23, 35), # Austria
  (25), # Serbia
  (26), # Switzerland
  (27), # Scotland 
  (28), # Slovakia
  (30) # Czech Republic
) 

const nb_nat = 16 # number of different nationalities

const env = Gurobi.Env() # environnement fo Gurobi


####################################### DEAD CODE ####################################### 


#=
function live_draw() # performs the draw progressively and stores it in a .txt file
    already_filled = Int[]
    open("draw_example.txt", "w") do file
        for placeholder in 1:n
            println(file, "Draw for placeholder : ", placeholder)
            println("")
            println("Placeholder à remplir : $(placeholder)")
            possible_teams = admissible_teams(placeholder, already_filled)  
            println(file, "Possible teams : ", possible_teams)
            println("")
            println("Liste des équipes possibles")
            println(possible_teams) 
            team = possible_teams[rand(1:end)]
            println(file, "Selected team : ", team)
            println(file, "\n---\n") 
            println("")
            println("Equipe sélectionnée : $(team)")
            push!(already_filled, team)
            println("")
            println("Remplissage")
            println(already_filled)
            println("Appuyez sur la barre d'espace suivi d'Entrée pour continuer...")
            while true
                input = readline()
                if input == " "
                    break
                else
                    println("Vous n'avez pas appuyé sur la barre d'espace suivi d'Entrée, réessayez.")
                 end
            end
        end
    end
    println("Résultats du tirage au sort enregistrés dans le fichier 'draw_example.txt'")
end
=#

#= 
function draw_strength_opponents(elo_opponents, uefa_opponents, team)
    uefa_data = collect(uefa_opponents[team, :]) # convert to vector
    histo =  histogram(uefa_data, bins=20, alpha=0.5, label="Uefa", color=:blue, xlabel="Values", ylabel="Frequency")
    uefa_real = uefa_real_opponents[team]
    vline!(histo, [uefa_real], label="Actual uefa score = $(uefa_real)", color=:red)
    p_value = count(x -> x > uefa_real, uefa_data) / length(uefa_data)
    title!(histo, "Opponents of $(teams[team]["club"]); p_value = $(p_value)")
    display(histo)
end
=#


################################### CODE FOR SIMULATIONS ###################################


function is_solvable(nationalities, opponents, nb_nat, team_nationalities, p, q, n, new_team, new_placeholder, already_filled) # = true if new_team in new_placeholder gurantees a solution given already_filled, false otherwise
    model = Model(() -> Gurobi.Optimizer(env))
    set_optimizer_attribute(model, "OutputFlag", 0)  # No output
    set_optimizer_attribute(model, "LogToConsole", 0) # No logging to consol
    set_optimizer_attribute(model, "Seed", rand(1:10000)) # random solution
    @variable(model, y[1:n, 1:n], Bin) # y[i,j] = 1 if team i is in placeholder j, 0 otherwise
    
    # for each placeholder
    for placeholder in 1:n 
        # only one team
        @constraint(model, sum(y[team, placeholder] for team in 1:n) == 1)
    end

    # for each pot
    for pot in 0:(p-1)
        # for each team in this pot
        for i in 1:q
            # for its pot
            # it must be associated with a corresponding placeholder 
            # (e.g., teams 1 to 9 must be placed in a placeholder numbered between 1 and 9)
            @constraint(model, sum(y[pot*q+i, pot*q+j] for j in 1:q) == 1)

            # for each other pot
            for other_pot in 0:(p-1)
                if other_pot != pot
                    # it cannot be associated with a corresponding placeholder
                    # (e.g., teams 1 to 9 cannot be placed in a placeholder numbered between 10 and 18)
                    @constraint(model, sum(y[pot*q+i, other_pot*q+j] for j in 1:q) == 0) 
                end
            end

        end
    end

    # for each placeholder
    for placeholder in 1:n 
        # for each nationality
        for nat in 1:nb_nat 
            # there can't be more than two teams of this nationality associated with this placeholder
            @constraint(model, sum(y[compatriot, neighbor] for compatriot in nationalities[nat] for neighbor in opponents[placeholder]) <= 2)
        end
    end

    # for each team
    for team in 1:n
        # for each placeholder
        for placeholder in 1:n
            # each team of the same nationality
            team_nationality = team_nationalities[team]
            for compatriot in nationalities[team_nationality] 
                # connected to this placeholder
                for neighbor in opponents[placeholder]
                    # cannot be adjacent if the team is indeed in this placeholder
                    @constraint(model, y[team, placeholder] + y[compatriot, neighbor] <= 1)
                end
            end
        end
    end

    for i in 1:length(already_filled)
        @constraint(model, y[already_filled[i], i] == 1) # already filled teams
    end

    @constraint(model, y[new_team, new_placeholder] == 1) # test the new team in the new placeholder 
           
    optimize!(model)
    return termination_status(model) == MOI.OPTIMAL
end


function admissible_teams(nationalities, opponents, nb_nat, team_nationalities, p, q, n, placeholder, already_filled) # returns the list of possible teams for placeholder given already_filled
    possible_teams = Int[]
    pot = div(placeholder-1, 9)
    for team in (pot*q+1):((pot+1)*q) 
        if !(team in already_filled) # team not already assigned to a placeholder
            if is_solvable(nationalities, opponents, nb_nat, team_nationalities, p, q, n, team, placeholder, already_filled) # does not cause a failure
                push!(possible_teams, team)
            end
        end
    end
    return possible_teams
end


function draw(nationalities, opponents, nb_nat, team_nationalities, p, q, n) # performs the draw ; draw[i] : team at placeholder i    
    already_filled = Int[]
    for placeholder in 1:n
        possible_teams = admissible_teams(nationalities, opponents, nb_nat, team_nationalities, p, q, n, placeholder, already_filled)  
        team = possible_teams[rand(1:end)]
        push!(already_filled, team)
    end
    return already_filled
end


function strength_opponents(nb_draw, teams, nationalities, opponents, nb_nat, team_nationalities, p, q, n)
    elo_opponents = zeros(Float64, n, nb_draw)  
    uefa_opponents = zeros(Float64, n, nb_draw) 
    @threads for i in 1:nb_draw
        println(i)
        draw_i = draw(nationalities, opponents, nb_nat, team_nationalities, p, q, n)
        for placeholder in 1:n
            team = draw_i[placeholder]
            elo_opponents[team, i] = sum(teams[draw_i[opp]]["elo"] for opp in opponents[placeholder])
            uefa_opponents[team, i] = sum(teams[draw_i[opp]]["uefa"] for opp in opponents[placeholder])
        end
    end
    open("elo_strength_opponents.txt", "a") do file  
        for i in 1:nb_draw
            row = join(elo_opponents[:, i], " ")  
            write(file, row * "\n")  
        end
    end    
    open("uefa_strength_opponents.txt", "a") do file  
        for i in 1:nb_draw
            row = join(uefa_opponents[:, i], " ")  
            write(file, row * "\n")  
        end
    end    
    return 0
end


###################################### COMMANDS ###################################### 

println("Nombre de threads utilisés : ", Threads.nthreads())

const n_simul = 20

strength_opponents(n_simul, teams, nationalities, opponents, nb_nat, team_nationalities, p, q, n)
