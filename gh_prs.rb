require 'octokit'
require 'csv'
require 'date'

# Setup Octokit client with a GitHub access token
Octokit.configure do |c|
  c.access_token = 'GH_ACCESS_TOKEN'
end
client = Octokit::Client.new

# Fetch pull requests
def fetch_pull_requests(client, repo, users, start_date, end_date)
  # TODO: deal with pagination
  prs = []
  
  all_prs = client.pull_requests(repo, state: 'closed', sort: 'created', direction: 'desc', per_page: 100)
  all_prs.each do |pr|
    puts "Fetching PR ##{pr[:number]}..."
    pr_updated_at = Date.parse(pr[:updated_at].to_s)
    next unless pr_updated_at >= start_date && pr_updated_at <= end_date
    next unless users.include?(pr[:user][:login])

    prs << pr
  end
  
  prs
end

# Extract required details from pull requests
def extract_pr_details(client, prs)
  details = []
  prs.each do |pr|
    reviews = client.pull_request_reviews(pr[:base][:repo][:full_name], pr[:number])
    review_comments = reviews.map { |review| { user: review[:user][:login], state: review[:state] } }
    approvals = reviews.select { |review| review[:state] == 'APPROVED' }.map { |review| review[:user][:login] }
    
    details << [
      pr[:number],
      pr[:title],
      pr[:user][:login],
      pr[:state],
      pr[:milestone]&.dig(:title),
      review_comments.size,
      review_comments.map { |c| c[:user] }.join(', '),
      approvals.join(', '),
      pr[:labels].map { |label| label[:name] }.join(', '),
      pr[:html_url]
    ]
  end
  details
end

# Configuration variables
repo = 'User/Repo'
users = ['user1', 'user2']
start_date = Date.parse('2024-04-01')
end_date = Date.parse('2024-04-30')

# Fetch and process pull requests
prs = fetch_pull_requests(client, repo, users, start_date, end_date)
pr_details = extract_pr_details(client, prs)

# Write details to a CSV file
CSV.open('pr_details.csv', 'wb') do |csv|
  csv << ['PR Number', 'PR Title','Author', 'Status', 'Milestone', 'Change Requests Count', 'Change Requestors', 'Approvers', 'Labels', 'URL']
  pr_details.each { |pr_detail| csv << pr_detail }
end

puts 'CSV file has been generated.'
