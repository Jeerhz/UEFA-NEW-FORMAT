"""
This script performs the draw for the method Build Schedule First.

"""
############################################ IMPORTS ############################################
using JuMP, SCIP, MathOptInterface
# using Plots
using Statistics
using Random
# using Profile # profiler
using Base.Threads # parallelization
using Logging


####################################### GLOBAL VARIABLES #######################################


const nb_pots = 4 # number of pots
const nb_teams_per_pot = 9 # number of teams per pot
const nb_teams = 36  # number of teams (= nb_pots*nb_teams_per_pot)

"""
Matrix of shape 36x8 representing the 8 opponents of each team in the draw
opponents[i] : list of placeholders connected to placeholder i
"""
const opponents =
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

# Champions League
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
	Dict("club" => "Brest", "nationality" => "France", "elo" => 1685, "uefa" => 13.366),                #36 
]

# Europa League
# const teams = [
#     Dict("club" => "Roma", "nationality" => "Italy", "elo" => 1812, "uefa" => 101),                       #1
#     Dict("club" => "Man Utd", "nationality" => "England", "elo" => 1779, "uefa" => 92),                   #2
#     Dict("club" => "Porto", "nationality" => "Portugal", "elo" => 1778, "uefa" => 77),                    #3
#     Dict("club" => "Ajax", "nationality" => "Netherlands", "elo" => 1619, "uefa" => 67),                  #4
#     Dict("club" => "Rangers", "nationality" => "Scotland", "elo" => 1618, "uefa" => 63),                  #5
#     Dict("club" => "Frankfurt", "nationality" => "Germany", "elo" => 1697, "uefa" => 60),                 #6
#     Dict("club" => "Lazio", "nationality" => "Italy", "elo" => 1785, "uefa" => 54),                       #7
#     Dict("club" => "Tottenham", "nationality" => "England", "elo" => 1791, "uefa" => 54),                 #8
#     Dict("club" => "Slavia Praha", "nationality" => "Czech Republic", "elo" => 1702, "uefa" => 53),       #9
#     Dict("club" => "Real Sociedad", "nationality" => "Spain", "elo" => 1767, "uefa" => 51),               #10
#     Dict("club" => "AZ Alkmaar", "nationality" => "Netherlands", "elo" => 1591, "uefa" => 50),            #11
#     Dict("club" => "Braga", "nationality" => "Portugal", "elo" => 1636, "uefa" => 49),                    #12
#     Dict("club" => "Olympiacos", "nationality" => "Greece", "elo" => 1673, "uefa" => 48),                 #13
#     Dict("club" => "Lyon", "nationality" => "France", "elo" => 1713, "uefa" => 44),                       #14
#     Dict("club" => "PAOK", "nationality" => "Greece", "elo" => 1639, "uefa" => 37),                       #15
#     Dict("club" => "Fenerbahçe", "nationality" => "Turkey", "elo" => 1714, "uefa" => 36),                 #16
#     Dict("club" => "M. Tel-Aviv", "nationality" => "Israel", "elo" => 1614, "uefa" => 35.5),              #17
#     Dict("club" => "Ferencvaros", "nationality" => "Hungary", "elo" => 1479, "uefa" => 35),               #18
#     Dict("club" => "Qarabag", "nationality" => "Azerbaijan", "elo" => 1597, "uefa" => 33),                #19
#     Dict("club" => "Galatasaray", "nationality" => "Turkey", "elo" => 1721, "uefa" => 31.5),              #20
#     Dict("club" => "Viktoria Plzen", "nationality" => "Czech Republic", "elo" => 1572, "uefa" => 28),     #21
#     Dict("club" => "Bodo/Glimt", "nationality" => "Norway", "elo" => 1598, "uefa" => 28),                 #22
#     Dict("club" => "Union SG", "nationality" => "Belgium", "elo" => 1701, "uefa" => 27),                  #23
#     Dict("club" => "Dynamo Kyiv", "nationality" => "Ukraine", "elo" => 1517, "uefa" => 26.5),             #24
#     Dict("club" => "Ludogorets", "nationality" => "Bulgaria", "elo" => 1512, "uefa" => 26),               #25
#     Dict("club" => "Midtjylland", "nationality" => "Denmark", "elo" => 1624, "uefa" => 25.5),             #26
#     Dict("club" => "Malmo", "nationality" => "Sweden", "elo" => 1493, "uefa" => 18.5),                    #27
#     Dict("club" => "Athletic Club", "nationality" => "Spain", "elo" => 1764, "uefa" => 17.897),           #28
#     Dict("club" => "Hoffenheim", "nationality" => "Germany", "elo" => 1683, "uefa" => 17.324),            #29
#     Dict("club" => "Nice", "nationality" => "France", "elo" => 1703, "uefa" => 17),                       #30
#     Dict("club" => "Anderlecht", "nationality" => "Belgium", "elo" => 1640, "uefa" => 14.5),              #31
#     Dict("club" => "Twente", "nationality" => "Netherlands", "elo" => 1627, "uefa" => 12.650),            #32
#     Dict("club" => "Besiktas", "nationality" => "Turkey", "elo" => 1484, "uefa" => 12),                   #33
#     Dict("club" => "FCSB", "nationality" => "Romania", "elo" => 1434, "uefa" => 10.5),                    #34
#     Dict("club" => "RFS", "nationality" => "Latvia", "elo" => 1225, "uefa" => 8),                         #35
#     Dict("club" => "Elfsborg", "nationality" => "Sweden", "elo" => 1403, "uefa" => 4.3)                   #36
# ]

# Champions League
# team_nationalities[i] : nationality of team i
const team_nationalities =
	[1, 2, 3, 4, 2, 5, 3, 3, 1, 3, 1, 5, 5, 6, 2, 7, 8, 5, 9, 6, 9, 10, 11, 4, 12, 13, 14, 15, 4, 16, 2, 5, 1, 3, 11, 4]

# Europa League
# team_nationalities[i] : nationality of team i
# const team_nationalities = 
# [1, 2, 3, 4, 5, 6, 1, 2, 14, 7, 4, 3, 8, 9, 8, 10, 11, 12, 13, 10, 14, 15, 16, 17, 18, 19, 20, 7, 6, 9, 16, 4, 10, 21, 22, 20]

# Champions League
const nationalities = # nationalities[i] : list of teams of nationality i 
	[[1, 9, 11, 33], # Spain
		[2, 5, 15, 31], # England
		[3, 7, 8, 10, 34], #  Germany
		[4, 24, 29, 36], # France
		[6, 12, 13, 18, 32], # Italy
		[14, 20], # Portugal
		[16], # Belgium
		[17], # Ukraine
		[19, 21], # Netherlands
		[22], # Croatia
		[23, 35], # Austria
		[25], # Serbia
		[26], # Switzerland
		[27], # Scotland 
		[28], # Slovakia
		[30], # Czech Republic
	]

# Europa League
# const nationalities = # nationalities[i] : list of teams of nationality i
# [   [1, 7],               # Italy
#     [2, 8],               # England
#     [3, 12],              # Portugal
#     [4, 11, 32],          # Netherlands
#     [5],                  # Scotland
#     [6, 29],              # Germany
#     [10, 28],             # Spain
#     [13, 15],             # Greece
#     [14, 30],             # France
#     [16, 20, 33],         # Turkey
#     [17],                 # Israel
#     [18],                 # Hungary
#     [19],                 # Azerbaijan
#     [9, 21],              # Czech Republic
#     [22],                 # Norway
#     [23, 31],             # Belgium
#     [24],                 # Ukraine
#     [25],                 # Bulgaria
#     [26],                 # Denmark
#     [27, 36],             # Sweden
#     [34],                 # Romania
#     [35],                 # Latvia
# ]

# Champions League
const nb_nat = 16 # number of different nationalities

# Europa League
# const nb_nat = 22 # number of different nationalities

const env = SCIP.Optimizer

################################### CODE FOR SIMULATIONS ###################################
"""
Check if given a current state of the draw, a new team - placeholder assignment can lead to a solution of the draw.
Returns true if new_team in new_placeholder can lead to a solution given already_filled, false otherwise

Parameters
----------
...
already_filled: list of 36 integers (0 if not filled, team index otherwise)
	already_filled[i] = j means that team j is already assigned to placeholder i. If already_filled[i] = 0, then placeholder i is not yet assigned to a team.
"""
function is_solvable(nationalities, opponents, nb_nat, team_nationalities, nb_pots, nb_teams_per_pot, new_team, new_placeholder, already_filled)::bool
	model = Model(env)
	set_attribute(model, "display/verblevel", 0)


	nb_teams = nb_pots * nb_teams_per_pot
	# y[i,j] = 1 if team i is in placeholder j, 0 otherwise
	@variable(model, y[1:nb_teams, 1:nb_teams], Bin)

	# Exactly one team is associated to each placeholder
	for placeholder in 1:nb_teams
		@constraint(model, sum(y[team, placeholder] for team in 1:nb_teams) == 1)
	end

	# Exactly one placeholder is associated to each team
	for team in 1:nb_teams
		@constraint(model, sum(y[team, placeholder] for placeholder in 1:nb_teams) == 1)
	end

	# Every team must be associated with a placeholder from its pot
	# (e.g., team indexed from 1 to nb_teams_per_pot must be associated to a placeholder numbered between 1 and nb_teams_per_pot)
	for pot_index in 1:nb_pots
		for team_pot_index in 1:nb_teams_per_pot
			@constraint(model, sum(y[(pot_index-1)*nb_teams_per_pot+team_pot_index, (pot_index-1)*nb_teams_per_pot+placeholder_pot_index] for placeholder_pot_index in 1:nb_teams_per_pot) == 1)
			for other_pot_index in 1:nb_pots
				if other_pot_index != pot_index
					# it cannot be associated with a corresponding placeholder
					# (e.g., teams 1 to 9 cannot be placed in a placeholder numbered between 10 and 18)
					@constraint(model, sum(y[(pot_index-1)*nb_teams_per_pot+team_pot_index, (other_pot_index-1)*nb_teams_per_pot+placeholder_other_pot_index] for placeholder_other_pot_index in 1:nb_teams_per_pot) == 0)
				end
			end
		end
	end

	# Likewise, each team must be associated with a placeholder from its pot
	for pot_index in 1:nb_pots
		for placeholder_pot_index in 1:nb_teams_per_pot
			@constraint(model, sum(y[(pot_index-1)*nb_teams_per_pot+team_pot_index, (pot_index-1)*nb_teams_per_pot+placeholder_pot_index] for team_pot_index in 1:nb_teams_per_pot) == 1)
			for other_pot_index in 1:nb_pots
				if other_pot_index != pot_index
					@constraint(model, sum(y[(pot_index-1)*nb_teams_per_pot+team_pot_index, (other_pot_index-1)*nb_teams_per_pot+team_other_pot_index] for team_other_pot_index in 1:nb_teams_per_pot) == 0)
				end
			end

		end
	end

	# Ensure the two teams of the same nationality does not play against each other
	for team_index in 1:nb_teams
		team_nationality = team_nationalities[team_index]
		for compatriot_team_index in nationalities[team_nationality]
			if compatriot_team_index != team_index
				for placeholder_index in 1:nb_teams
					for neighbor in opponents[placeholder_index]
						# cannot be adjacent if the team is indeed in this placeholder
						@constraint(model, y[team_index, placeholder_index] + y[compatriot_team_index, neighbor] <= 1)
					end
				end
			end
		end
	end


	# Every placeholder shall have at most 2 opponents from the same nationality
	for placeholder_index in 1:nb_teams
		for nationality_group in nationalities
			@constraint(model, sum(y[team_index, opponent_placeholder_index] for team_index in nationality_group for opponent_placeholder_index in opponents[placeholder_index]) <= 2)
		end
	end

	# Write the constraints for the already filled placeholders
	for team_index in 1:nb_teams
		if already_filled[team_index] > 0 # placeholder already assigned to a team
			@constraint(model, y[already_filled[team_index], team_index] == 1)
		end
	end

	# Add the new constraint for the new team in the new placeholder
	@constraint(model, y[new_team, new_placeholder] == 1) # test the new team in the new placeholder 

	optimize!(model)
	return termination_status(model) == MOI.OPTIMAL
end


"""
Returns the list of possible teams for placeholder given already_filled
"""
function admissible_teams(nationalities, opponents, nb_nat, team_nationalities, nb_pots, nb_teams_per_pot, placeholder, already_filled)
	possible_teams = Int[]
	placeholder_pot = div(placeholder - 1, 9)
	for team in (placeholder_pot*nb_teams_per_pot+1):((placeholder_pot+1)*nb_teams_per_pot)
		if !(team in already_filled) # team not already assigned to a placeholder
			if is_solvable(nationalities, opponents, nb_nat, team_nationalities, nb_pots, nb_teams_per_pot, team, placeholder, already_filled) # does not cause a failure
				push!(possible_teams, team)
			end
		end
	end
	return possible_teams
end


function draw(nationalities, opponents, nb_nat, team_nationalities, p, q, n) # performs the draw ; draw[i] : team at placeholder i    
	already_filled = zeros(Int, n)
	# normal draw
	#placeholder_order = 1:n
	# randomized draw
	placeholder_order = shuffle!(collect(1:n))
	for placeholder in placeholder_order
		possible_teams = admissible_teams(nationalities, opponents, nb_nat, team_nationalities, p, q, placeholder, already_filled)
		team = possible_teams[rand(1:end)]
		already_filled[placeholder] = team
	end
	return already_filled
end


function tirage_au_sort(nb_draw, teams, nationalities, opponents, nb_nat, team_nationalities, p, q, n)
	elo_opponents = zeros(Float64, n, nb_draw)
	uefa_opponents = zeros(Float64, n, nb_draw)
	matches = zeros(Int, 36, 8, nb_draw)
	@threads for i in 1:nb_draw
		draw_i = draw(nationalities, opponents, nb_nat, team_nationalities, p, q, n)
		for placeholder in 1:n
			team = draw_i[placeholder]
			matches[team, :, i] = [draw_i[opp] for opp in opponents[placeholder]]
			elo_opponents[team, i] = sum(teams[draw_i[opp]]["elo"] for opp in opponents[placeholder])
			uefa_opponents[team, i] = sum(teams[draw_i[opp]]["uefa"] for opp in opponents[placeholder])
		end
	end
	open("bsf_rd_ucl_elo.txt", "a") do file
		for i in 1:nb_draw
			row = join(elo_opponents[:, i], " ")
			write(file, row * "\n")
		end
	end

	open("bsf_rd_ucl_uefa.txt", "a") do file
		for i in 1:nb_draw
			row = join(uefa_opponents[:, i], " ")
			write(file, row * "\n")
		end
	end

	open("bsf_rd_ucl_matches.txt", "a") do file
		for i in 1:nb_draw
			for team in 1:36
				matchups = [(team, matches[team, k, i]) for k in 1:8]
				row = join(matchups, " ")
				write(file, row * " ")
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
	tirage_au_sort(n_simul, teams, nationalities, opponents, nb_nat, team_nationalities, p, q, n)
end
