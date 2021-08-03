require 'tournament_system/algorithm/swiss'
require 'tournament_system/swiss/dutch'
require 'tournament_system/swiss/accelerated_dutch'

module TournamentSystem
  # Robust implementation of the swiss tournament system
  module Voetlab
    extend self

    # Generate matches with the given driver.
    #
    # @param driver [Driver]
    # @option options [Pairer] pairer the pairing system to use, defaults to
    #                                 {Dutch}
    # @option options [Hash] pair_options options for the chosen pairing system,
    #                                     see {Dutch} for more details
    # @return [nil]
    def generate(driver, options = {})
      available_rounds = available_round_robin_rounds(driver)

      state = build_state(driver, options)
      ordered_rounds = available_rounds.sort_by do |pairings|
        rate_round(pairings, state, options)
      end

      pairings = ordered_rounds.first.map(&:to_a)

      driver.create_matches(pairings)
    end

    def minimum_rounds(driver)
      1
    end
    
    # private

    def build_state(driver, options = {})
      pairer = pairer_from_options(options)
      pairer_options = options[:pair_options] || {}

      state = pairer.build_state(driver, pairer_options)

      teams = state.teams

      state.matches = state.driver.matches_hash

      state.score_range = state.scores.values.max - state.scores.values.min
      state.average_score_difference = state.score_range / teams.length.to_f

      state.team_index_map = teams.map.with_index.to_h

      state
    end

    def rate_round(pairings, state, options = {})
      pairer = pairer_from_options(options)
      costs = pairings.map do |pair|
        home, away = pair.to_a
        pairer.cost_function(state, home, away)
      end
      costs.sum
    end

    def available_round_robin_rounds(driver)
      # By permuting teams, we get all possible round robin tournament configurations
      all_rr_tournaments = driver.seeded_teams.permutation.map { |teams| round_robin_tournament(driver, teams) }.to_set

      # Filter out round robin tournaments that do not include all past rounds
      # Those tournaments will not be able to complete fully
      past_pairings = driver.matches.map(&:to_set).to_set
      valid_rr_tournaments = all_rr_tournaments.select do |rounds|
        played_rounds = rounds.select { |pairings| !(pairings & past_pairings).empty? }
        past_pairings == flatten_set(played_rounds) # If past pairings are the only pairings, we know rounds are identical
      end

      # Collect all possibe rounds
      all_rounds = flatten_set(valid_rr_tournaments)

      # Combine the rounds of all valid round robin tournaments and filter out
      # rounds that have already been played
      valid_rounds = all_rounds.select { |pairings| (pairings & past_pairings).empty? }
    end

    def round_robin_tournament(driver, teams)
      total_rounds = Algorithm::RoundRobin.total_rounds(teams.count)
      all_rounds = (1..total_rounds).map { |round| Algorithm::RoundRobin.round_robin_pairing(Algorithm::Util.padd_teams_even(teams), round).map(&:to_set).to_set }

      all_rounds.to_set
    end

    def pairer_from_options(options)
      options[:pairer] || TournamentSystem::Swiss::Dutch
    end

    def flatten_set(sets)
      new_set = Set.new
      sets.each do |s|
        s.each do |e|
          new_set.add(e)
        end
      end
      new_set
    end
  end
end
