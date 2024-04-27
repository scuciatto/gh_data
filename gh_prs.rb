require 'octokit'
require 'csv'
require 'date'

Octokit.configure do |c|
  c.access_token = 'GH_ACCESS_TOKEN'
end
client = Octokit::Client.new

def fetch_pull_requests(client, repo, start_date, end_date)
  prs = []
  page = 1
  last_response = client.pull_requests(repo, state: 'closed', page: page, sort: 'created', direction: 'desc', per_page: 100)

  while last_response.any?
    last_response.each do |pr|
      puts "Fetching PR ##{pr[:number]}..."
      pr_created_at = Date.parse(pr[:created_at].to_s)
      break if pr_created_at < start_date # Stop fetching if the PR is older than the start date
      if pr_created_at <= end_date
        prs << pr
      end
    end
    page += 1
    break if last_response.any? && Date.parse(last_response.last[:created_at].to_s) < start_date
    last_response = client.pull_requests(repo, state: 'closed', page: page, sort: 'created', direction: 'desc', per_page: 100)
  end

  prs
end

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
start_date = Date.parse('2024-04-01')
end_date = Date.parse('2024-04-30')

prs = fetch_pull_requests(client, repo, start_date, end_date)
pr_details = extract_pr_details(client, prs)

CSV.open('pr_details.csv', 'wb') do |csv|
  csv << ['PR Number', 'PR Title','Author', 'Status', 'Milestone', 'Change Requests Count', 'Change Requestors', 'Approvers', 'Labels', 'URL']
  pr_details.each { |pr_detail| csv << pr_detail }
end

puts 'CSV file has been generated.'
