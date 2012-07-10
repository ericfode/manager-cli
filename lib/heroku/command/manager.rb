require 'heroku/command/base'
require 'rest_client'

# manage apps in organization accounts
#
class Heroku::Command::Manager < Heroku::Command::BaseWithApp
  MANAGER_HOST = ENV['MANAGER_HOST'] || "manager-api.heroku.com"

  # transfer
  #
  # transfer an app to an organization account
  #
  def index
    display "Usage: heroku manager:transfer (--to|--from) ORG_NAME [--app APP_NAME]"
  end

  # manager:transfer (--to|--from) ORG_NAME [--app APP_NAME]
  #
  # transfer an app to or from an organization account
  #
  # -t, --to ORG         # Transfer application from personal account to this org
  # -f, --from ORG       # Transfer application from this org to personal account
  #
  def transfer
    to = options[:to]
    from = options[:from]

    if to == nil && from == nil
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to transfer to or from with --to <org name> or --from <org name>"
    end

    if to != nil && from != nil
      raise Heroku::Command::CommandFailed, "Ambiguous option. Please specify either a --to <org name> or a --from <org name>. Not both."
    end

    begin
      heroku.get("/apps/#{app}")
    rescue RestClient::ResourceNotFound => e
      raise Heroku::Command::CommandFailed, "You do not have access to the app '#{app}'"
    end

    if to != nil
      print_and_flush("Transferring #{app} to #{to}...")
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{to}/app", json_encode({ "app_name" => app }), :content_type => :json)
      if response.code == 201
        print_and_flush(" done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}")      
      end
    else
      print_and_flush("Transferring #{app} from #{from} to your personal account...")
      response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{from}/app/#{app}/transfer-out", "")
      if response.code == 200
        print_and_flush(" done\n")
      else
        print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}")      
      end
    end
  end


  # manager:migrate (--to|--from) ORG_NAME [--team TEAM_NAME]
  #
  # move all apps between a team an an org
  #
  # --team TEAM      # Team to transfer applications from/to
  # --to ORG         # Transfer all applications from TEAM to ORG
  # --from ORG       # Transfer all applications from ORG to TEAM
  #
  def migrate
    to = options[:to]
    from = options[:from]
    team = options[:team]

    if to == nil && from == nil
      raise Heroku::Command::CommandFailed, "No organization specified.\nSpecify which organization to transfer to or from with --to <org name> or --from <org name>"
    end

    if team == nil
      raise Heroku::Command::CommandFailed, "No team specified.\nSpecify which team to transfer applications to/from with --team <team name>"
    end

    begin
      team_apps = json_decode(heroku.get("/v3/teams/#{team}"))["apps"]
      puts "Migrating the following apps from team #{team}:"
      team_apps.each { |a|
        puts "    #{a}"
      }
      print_and_flush("Transferring apps to your personal account...")
      resp = heroku.post("/v3/teams/personal/apps", "apps[#{team_apps.join("]=1&apps[")}]=1")
      if resp.code == 200
        print_and_flush " done\n"
      else
        print_and_flush " failed!\n"
        raise Heroku::Command::CommandFailed, "Migration failed while transferring apps to your personal account.\nCheck the #{team} team and your personal account to find the apps.\nNo apps where transferred to the organization."
      end
      print_and_flush("Transferring apps from your personal account to the #{to} organization...\n")
      team_apps.each { |a| 
        print_and_flush("    #{a}...")
        response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{to}/app", json_encode({ "app_name" => a }), :content_type => :json)
        if response.code == 201
          print_and_flush(" transferred\n")
        else
          print_and_flush(" failed!\n")
        end
      }

    rescue RestClient::ResourceNotFound => e
      raise Heroku::Command::CommandFailed, "No such team: '#{team}' (perhaps you don't have access?)"
    end

    # if to != nil
    #   print_and_flush("Transferring #{app} to #{to}...")
    #   response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{to}/app", json_encode({ "app_name" => app }), :content_type => :json)
    #   if response.code == 201
    #     print_and_flush(" done\n")
    #   else
    #     print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}")      
    #   end
    # else
    #   print_and_flush("Transferring #{app} from #{from} to your personal account...")
    #   response = RestClient.post("https://:#{api_key}@#{MANAGER_HOST}/v1/organization/#{from}/app/#{app}/transfer-out", "")
    #   if response.code == 200
    #     print_and_flush(" done\n")
    #   else
    #     print_and_flush("failed\nAn error occurred: #{response.code}\n#{response}")      
    #   end
    # end
  end
  # manager:orgs
  #
  # list organization accounts that you have access to
  #
  def orgs
    puts "You are a member of the following organizations:"
    puts json_decode(RestClient.get("https://:#{api_key}@#{MANAGER_HOST}/v1/user-info"))["organizations"].collect { |o|
        "    #{o["organization_name"]}"
    }
  end

  protected
  def api_key
    Heroku::Auth.api_key
  end

  def print_and_flush(str)
    print str
    $stdout.flush
  end

end
