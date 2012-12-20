require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'

TEAMS = {"SF"=>"San Francisco", "DAL"=>"Dallas", "NYG"=>"NY Giants", "ATL"=>"Atlanta", "KC"=>"Kansas City", "PHI"=>"Philadelphia", "CLE"=>"Cleveland", "WAS"=>"Washington", "NO"=>"New Orleans", "STL"=>"St. Louis", "DET"=>"Detroit", "NE"=>"New England", "TEN"=>"Tennessee", "MIA"=>"Miami", "HOU"=>"Houston", "BUF"=>"Buffalo", "NYJ"=>"NY Jets", "JAC"=>"Jacksonville", "MIN"=>"Minnesota", "IND"=>"Indianapolis", "CHI"=>"Chicago", "CAR"=>"Carolina", "TB"=>"Tampa Bay", "SEA"=>"Seattle", "ARI"=>"Arizona", "GB"=>"Green Bay", "PIT"=>"Pittsburgh", "DEN"=>"Denver", "CIN"=>"Cinncinati", "BAL"=>"Baltimore", "SD"=>"San Diego", "OAK"=>"Oakland"}

class YahooFballStats
  def initialize(url_file, team_abbr)
    @url_file = url_file
    @team_abbr = team_abbr
    @scrapers = []
  end
  
  def add_scraper(scraper)
    @scrapers << scraper
  end

  def run
    game_num = 0
    File.open(@url_file) do |f|
      f.each_line do |line|
        line.strip!
        next if line.start_with? '#'
        game_num += 1

        @scrapers.each do |s|
          csv_string = s.scrape(line, @team_abbr)
          out_file_name = "#{game_num}-#{@team_abbr}-#{s.class.name}.csv"
          puts "writing: #{out_file_name}"
          File.open(out_file_name, 'w') {|o| o.write(csv_string)}
        end
        puts ""
      end
    end
  end
end

class ScoresScraper
  def scrape(url, team_abbr)
    return if url.nil? || url.empty?

    url = "#{url}&page=boxscore"
    page = Nokogiri::HTML(open(url))

    div_scoring_summary = page.css('div#ysp-reg-box-game_details-scoring_summary').css('div.bd').children

    quarter = 0
    team_index = -1
    opponent_index = -1
    csv_string = CSV.generate do |csv|
      csv << ["quarter", "time_left", "team_score", "opponent_score"]
      div_scoring_summary.each do |dss|
        case dss.name
        when 'h5'
          md = /(\d)(st|nd|rd|th) Quarter/.match dss.text
          quarter = md.nil? ? 5 : md[1].to_i # 5 represents OT
          md = /([A-Z]+)\s\-\s([A-Z]+)/.match dss.css('span').text
          team_index = md[1] == team_abbr ? 1 : 2
          opponent_index = md[1] != team_abbr ? 1 : 2
        when 'table'
          dss.css('tbody').css('tr').each do |tr|
            time = tr.css('td.time').text.strip
            md = /(\d+)\s\-\s(\d+)/.match tr.css('td.score').text
            team_score = md[team_index].to_i
            opponent_score = md[opponent_index].to_i
            csv << [quarter, time, team_score, opponent_score]
          end
        end
      end
    end
  end
end

class PlaysScraper
  def scrape(url, team_abbr)
    return if url.nil? || url.empty?

    url = "#{url}&page=plays"
    page = Nokogiri::HTML(open(url))

    div_plays = page.css('div#ysp-reg-box-game_details-play_by_play').css('div.bd').children

    quarter = 0
    csv_string = CSV.generate do |csv|
      csv << ["quarter", "time_left", "down", "first_down_yards", "yards_to_goal", "play"]
      div_plays.each do |dp|
        case dp.name
        when 'text'
          next
        when 'h5'
          quarter = dp.text[0].to_i
        when 'dl'
          next unless dp.css('dt').first.text =~ /#{TEAMS[team_abbr]}.*/
          next unless dp.css('dd').count > 1
          dds = dp.css('dd')
          dds.each {|dd| csv << [quarter].concat(parse_play(dd, team_abbr)) }
        end
      end
    end
  end

  def parse_play(dd, team_abbr)
    event_el = dd.css('span.event')
    time_el = dd.css('span.time')
    play_el = dd.css('span.play')

    md = /^(\d+)(st|nd|rd|th)\-(\d+),\s([A-Z]*)(\d+)$/.match event_el.text.strip
    yards_to_goal = md[4] == team_abbr ? (100 - md[5].to_i) : md[5].to_i

    return [time_el.text.strip, md[1], md[3], yards_to_goal, determine_play(play_el.text)]
  end

  def determine_play(play_desc)
    case play_desc
    when /.*pass.*/
      return 'pass'
    when /.*rushed.*/
      return 'rush'
    when /.*field goal.*/
      return 'field goal'
    when /.*punt.*/
      return 'punt'
    else
      return 'noplay'
    end
  end
end


#
# Main
#

if __FILE__ == $0
  if(ARGV.length < 2)
    puts "arguments: <team abbreviation> <input file with urls>"
    exit(1)
  end

  team_abbr = ARGV[0]
  input_file = ARGV[1]

  input_file = nil unless TEAMS.has_key? team_abbr
  if input_file.nil?
    puts "invalid team"
    exit(2)
  end

  puts "Scraping stats for #{TEAMS[team_abbr]}"
  fball_stats = YahooFballStats.new(input_file, team_abbr)
  fball_stats.add_scraper(ScoresScraper.new)
  fball_stats.add_scraper(PlaysScraper.new)
  fball_stats.run
end

