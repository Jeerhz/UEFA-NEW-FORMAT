#!/usr/bin/env python3
"""
UEFA Draw Scheduling using OR‑Tools CP‑SAT

This script implements a scheduling feasibility model for a UEFA-style draw.
It uses OR‑Tools CP‑SAT and is structured with data classes and functions that
mirror the logic of the original Julia template.
"""

from dataclasses import dataclass
from typing import Tuple, Dict, Set, List
from ortools.sat.python import cp_model
import random
import logging

# ----------------------------- Data Structures --------------------------------


@dataclass(frozen=True)
class Team:
    club: str
    nationality: str
    elo: int
    uefa: float


@dataclass
class TeamsContainer:
    potA: Tuple[Team, ...]
    potB: Tuple[Team, ...]
    potC: Tuple[Team, ...]
    potD: Tuple[Team, ...]
    index: Dict[str, Team]


@dataclass
class ConstraintData:
    played_home: Set[str]
    played_ext: Set[str]
    nationalities: Dict[str, int]


# ----------------------------- Initialization Functions -----------------------


def create_teams_container(
    potA: Tuple[Team, ...],
    potB: Tuple[Team, ...],
    potC: Tuple[Team, ...],
    potD: Tuple[Team, ...],
) -> TeamsContainer:
    """Creates a TeamsContainer from the four pots."""
    index = {team.club: team for pot in (potA, potB, potC, potD) for team in pot}
    return TeamsContainer(potA, potB, potC, potD, index)


def get_all_nationalities(teams: TeamsContainer) -> Set[str]:
    """Returns a set of all nationalities present in the league."""
    nations = set()
    for pot in (teams.potA, teams.potB, teams.potC, teams.potD):
        for team in pot:
            nations.add(team.nationality)
    return nations


def initialize_constraints(
    all_nations: Set[str], teams: TeamsContainer
) -> Dict[str, ConstraintData]:
    """
    For each team, initialize its ConstraintData:
      - 'played_home' and 'played_ext' are empty sets.
      - 'nationalities' is a dictionary mapping each nation to 0,
        except for the team's own nationality which is set to 2.
    """
    constraints = {}
    for pot in (teams.potA, teams.potB, teams.potC, teams.potD):
        for team in pot:
            nat_dict = {nat: 0 for nat in all_nations}
            nat_dict[team.nationality] = 2
            constraints[team.club] = ConstraintData(set(), set(), nat_dict)
    return constraints


def update_constraints(
    home: Team, away: Team, constraints: Dict[str, ConstraintData]
) -> None:
    """
    Update the constraints for a played match.
    If the match is not already recorded, update:
      - Increment the count for the opponent's nationality.
      - Record the played match (home for home team, away for away team).
    """
    cons_home = constraints[home.club]
    cons_away = constraints[away.club]
    if away.club in cons_home.played_home or home.club in cons_away.played_ext:
        logging.warning(f"Match already played: Home {home.club}, Away {away.club}")
        return
    cons_home.nationalities[away.nationality] += 1
    cons_away.nationalities[home.nationality] += 1
    cons_home.played_home.add(away.club)
    cons_away.played_ext.add(home.club)


# ----------------------------- Dummy CP Helper Functions ------------------------------


def solve_problem(
    selected_team: Team,
    constraints: Dict[str, ConstraintData],
    new_match: Tuple[Team, Team],
    teams: TeamsContainer,
) -> bool:
    """
    Dummy implementation of a feasibility check.
    In a full implementation, this function builds a CP-SAT model (using OR-Tools)
    that sets up match scheduling constraints and forces the match (home, away)
    for selected_team, returning True if a feasible schedule exists.
    """
    # For demonstration, assume every candidate yields a feasible solution.
    return True


def true_admissible_matches(
    selected_team: Team,
    opponent_pot: Tuple[Team, ...],
    constraints: Dict[str, ConstraintData],
) -> List[Tuple[Team, Team]]:
    """
    Dummy implementation to generate candidate (home, away) pairs.
    Returns candidate pairs from opponent_pot where:
      - The home and away teams are distinct.
      - Neither has the same nationality as the selected team.
    In a complete implementation, additional constraint checks would be performed.
    """
    candidates = []
    n = len(opponent_pot)
    for i in range(n):
        for j in range(n):
            if i != j:
                home = opponent_pot[i]
                away = opponent_pot[j]
                if (
                    home.nationality != selected_team.nationality
                    and away.nationality != selected_team.nationality
                ):
                    candidates.append((home, away))
    return candidates


# ----------------------------- Draw Function ----------------------------------


def uefa_draw(
    teams: TeamsContainer, all_nations: Set[str]
) -> Dict[str, List[Tuple[str, str, str]]]:
    """
    Performs a sequential UEFA draw according to the following rules:
      - Teams are seeded into four pots (A, B, C, D).
      - For each team, opponents are drawn from eligible pots as follows:
          * Teams in Pot A must draw 2 opponents from each pot (A, B, C, D).
          * Teams in Pot B already have opponents from Pot A, so they draw 2 from each of Pots B, C, D.
          * Teams in Pot C draw 2 from each of Pots C and D.
          * Teams in Pot D draw 2 from Pot D.
      - For each selected team (processed in random order within its pot), for each eligible opponent pot,
        candidate (home, away) pairs are generated using `true_admissible_matches`.
      - For each eligible draw (performed twice per opponent pot), if forcing the match via `solve_problem`
        yields a feasible schedule, the constraints are updated (using `update_constraints`) and the drawn
        match is recorded.
    Returns a dictionary mapping each selected team's club to a list of drawn matches.
    Each drawn match is a tuple: (opponent pot label, home opponent club, away opponent club).
    """
    constraints = initialize_constraints(all_nations, teams)
    drawn_matches: Dict[str, List[Tuple[str, str, str]]] = {}
    pots = [teams.potA, teams.potB, teams.potC, teams.potD]
    pot_labels = ["A", "B", "C", "D"]

    # Process teams from each pot in order.
    for pot_idx, pot in enumerate(pots):
        team_order = list(pot)
        random.shuffle(team_order)
        for selected_team in team_order:
            drawn_matches[selected_team.club] = []
            logging.info(
                f"Selected team from pot {pot_labels[pot_idx]}: {selected_team.club}"
            )
            # Determine the number of matches to draw from each eligible opponent pot.
            # For example, if the selected team is from Pot A (pot_idx == 0), then it draws 2 matches from each pot.
            # If from Pot B, then draw 2 matches from pots B, C, and D, etc.
            num_matches_needed = 2  # Each eligible opponent pot yields 2 matches.
            for opp_idx in range(pot_idx, len(pots)):
                opponent_pot = pots[opp_idx]
                logging.info(f"  Considering opponents from pot {pot_labels[opp_idx]}")
                matches_drawn = 0
                # Draw until we have 2 matches or no candidate remains.
                while matches_drawn < num_matches_needed:
                    candidates = true_admissible_matches(
                        selected_team, opponent_pot, constraints
                    )
                    if not candidates:
                        logging.warning(
                            f"    No admissible candidates found for {selected_team.club} in pot {pot_labels[opp_idx]}"
                        )
                        break
                    random.shuffle(candidates)
                    candidate_found = False
                    for candidate in candidates:
                        home_opponent, away_opponent = candidate
                        if solve_problem(
                            selected_team,
                            constraints,
                            (home_opponent, away_opponent),
                            teams,
                        ):
                            update_constraints(
                                selected_team, home_opponent, constraints
                            )
                            update_constraints(
                                away_opponent, selected_team, constraints
                            )
                            drawn_matches[selected_team.club].append(
                                (
                                    pot_labels[opp_idx],
                                    home_opponent.club,
                                    away_opponent.club,
                                )
                            )
                            logging.info(
                                f"    Feasible match from pot {pot_labels[opp_idx]}: {home_opponent.club} vs {away_opponent.club}"
                            )
                            matches_drawn += 1
                            candidate_found = True
                            break  # Stop after one feasible candidate for this draw.
                    if not candidate_found:
                        logging.warning(
                            f"    No feasible candidate found for {selected_team.club} in pot {pot_labels[opp_idx]} on draw {matches_drawn + 1}"
                        )
                        break
    return drawn_matches


# ----------------------------- Main Section -----------------------------------

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    # Example setup for Champions League:
    potA = (
        Team("Real", "Spain", 1985, 136),
        Team("ManCity", "England", 2057, 148),
        Team("Bayern", "Germany", 1904, 144),
        Team("PSG", "France", 1893, 116),
        Team("Liverpool", "England", 1908, 114),
        Team("Inter", "Italy", 1960, 101),
        Team("Dortmund", "Germany", 1874, 97),
        Team("Leipzig", "Germany", 1849, 97),
        Team("Barcelona", "Spain", 1894, 91),
    )
    potB = (
        Team("Leverkusen", "Germany", 1929, 90),
        Team("Atlético", "Spain", 1830, 89),
        Team("Atalanta", "Italy", 1879, 81),
        Team("Juventus", "Italy", 1839, 80),
        Team("Benfica", "Portugal", 1824, 79),
        Team("Arsenal", "England", 1957, 72),
        Team("Brugge", "Belgium", 1703, 64),
        Team("Shakhtar", "Ukraine", 1573, 63),
        Team("Milan", "Italy", 1821, 59),
    )
    potC = (
        Team("Feyenoord", "Netherlands", 1747, 57),
        Team("Sporting", "Portugal", 1824, 54.5),
        Team("Eindhoven", "Netherlands", 1794, 54),
        Team("Dinamo", "Croatia", 1584, 50),
        Team("Salzburg", "Austria", 1693, 50),
        Team("Lille", "France", 1785, 47),
        Team("Crvena", "Serbia", 1734, 40),
        Team("YB", "Switzerland", 1566, 34.5),
        Team("Celtic", "Scotland", 1646, 32),
    )
    potD = (
        Team("Bratislava", "Slovakia", 1703, 30.5),
        Team("Monaco", "France", 1780, 24),
        Team("Sparta", "Czech Republic", 1716, 22.5),
        Team("Aston Villa", "England", 1772, 20.86),
        Team("Bologna", "Italy", 1777, 18.056),
        Team("Girona", "Spain", 1791, 17.897),
        Team("Stuttgart", "Germany", 1795, 17.324),
        Team("Sturm Graz", "Austria", 1610, 14.500),
        Team("Brest", "France", 1685, 13.366),
    )
    teams_container = create_teams_container(potA, potB, potC, potD)
    all_nations = get_all_nationalities(teams_container)
    # (Re)initialize constraints.
    constraints = initialize_constraints(all_nations, teams_container)

    drawn = uefa_draw(teams_container, all_nations)
    for team, matches in drawn.items():
        print(f"Team {team} drawn matches: {matches}")
