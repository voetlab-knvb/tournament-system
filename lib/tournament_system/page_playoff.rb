require 'tournament_system/algorithm/page_playoff'
require 'tournament_system/algorithm/group_pairing'

module TournamentSystem
  # Implements the page playoff system.
  module PagePlayoff
    extend self

    # Generate matches with the given driver.
    #
    # @param driver [Driver]
    # @option options [Integer] round the round to generate
    # @option options [Boolean] bronze_match whether to generate a bronze match
    #     on the final round.
    def generate(driver, options = {})
      teams = driver.ranked_teams
      raise 'Page Playoffs only works with 4 teams' if teams.length != 4

      round = options[:round] || guess_round(driver)

      case round
      when 0 then semi_finals(driver, teams)
      when 1 then preliminary_finals(driver)
      when 2 then grand_finals(driver, options)
      else
        raise 'Invalid round number'
      end
    end

    # Rubocop doesn't handle _ as a parameter sink

    # The total number of rounds in a page playoff tournament
    #
    # @param _ for keeping the same interface as other tournament systems.
    # @return [Integer]
    def total_rounds(_ = nil)
      Algorithm::PagePlayoff::TOTAL_ROUNDS
    end

    # Guess the next round number (starting at 0) from the state in a driver.
    #
    # @param driver [Driver]
    # @return [Integer]
    def guess_round(driver)
      Algorithm::PagePlayoff.guess_round(driver.matches.length)
    end

    private

    def semi_finals(driver, teams)
      driver.create_matches Algorithm::GroupPairing.adjacent(teams)
    end

    def preliminary_finals(driver)
      matches = driver.matches
      top_loser = driver.get_match_loser matches[0]
      bottom_winner = driver.get_match_winner matches[1]

      driver.create_matches [[top_loser, bottom_winner]]
    end

    def grand_finals(driver, options)
      matches = driver.matches
      top_winner = driver.get_match_winner matches[0]
      bottom_winner = driver.get_match_winner matches[2]

      new_matches = driver.create_matches [[top_winner, bottom_winner]]
      new_matches += bronze_finals(driver, driver.matches) if options[:bronze_match]
      new_matches
    end

    def bronze_finals(driver, matches)
      prelim_loser = driver.get_match_loser matches[2]
      bottom_semi_loser = driver.get_match_loser matches[1]

      driver.create_matches [[prelim_loser, bottom_semi_loser]]
    end
  end
end
