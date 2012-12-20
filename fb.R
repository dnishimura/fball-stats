NUM_GAMES = 14

read_game_plays <- function(game_num, team_abbr) {
  return(read.csv(sprintf("%d-%s-PlaysScraper.csv", game_num, team_abbr)))
}
  
read_game_scores <- function(game_num, team_abbr) {
  return(read.csv(sprintf("%d-%s-ScoresScraper.csv", game_num, team_abbr)))
}

rush_analysis <- function(num_games, team_abbr) {
  game_indices <- 1:num_games
  win_margin <- rep(NA, num_games)
  rush_percentages <- rep(NA, num_games)
  rush_delta <- rep(NA, num_games)
  games <- rep(NA, num_games)
  
  for(i in game_indices) {
    game_plays <- read_game_plays(i, team_abbr)
    game_scores <- read_game_scores(i, team_abbr)
    win_margin[i] <- tail(game_scores$team_score, n=1) - tail(game_scores$opponent_score, n=1)
    rush_delta[i] <- nrow(game_plays[game_plays$play == "rush",]) - nrow(game_plays[game_plays$play == "pass",])
    rush_percentages[i] <- nrow(game_plays[game_plays$play == "rush",]) / (nrow(game_plays[game_plays$play == "rush",]) + nrow(game_plays[game_plays$play == "pass",]))
  }
  
  result.rushes = data.frame(win_margin=win_margin,rush_percentage=rush_percentages,rush_delta=rush_delta)
  result.win_rush.corr <- with(result.rushes[result.rushes$win_margin < 21 & result.rushes$win_margin > -21,], cor(win_margin, rush_delta))
  result = data.frame(team=team_abbr, win_rush_delta_corr=result.win_rush.corr)
  return(result)
}

# Main analysis
sf.result <- rush_analysis(NUM_GAMES, "SF")
no.result <- rush_analysis(NUM_GAMES, "NO")
det.result <- rush_analysis(NUM_GAMES, "DET")
min.result <- rush_analysis(NUM_GAMES, "MIN")

all.result <- rbind(sf.result, no.result, det.result, min.result)

