#!/usr/local/bin/ruby -w
require 'sinatra'
require 'rest-client'
require 'json'

# Listen on all interfaces to support docker port mapping
set :bind, '0.0.0.0'

get '/' do
  redirect to('/templates/')
end

get '/templates' do
  redirect to('/templates/')
end

get '/templates/' do
  t = Time.now
  q = params['q']
  if (q && q != '') then
    raise "q must match the rules" unless q =~ /^[a-zA-Z0-9_ \.@]+$/
    @query = q
    if q.end_with? '.yml' then
      json = get_job_templates_by_playbook(q)
    elsif q.length > 0 then
      json = get_job_templates_by_name(q)
    end
  end
  if (json)
    git('fetch -p')
    git('reset --hard origin/master')
    projects = get_projects()
    json['results'].each do |t|
      project = projects[t['project']]
      t['project_scm_url'] = project['scm_url'];
      t['project_scm_branch'] = project['scm_branch'];
      recent = t['summary_fields']['recent_jobs']
      if recent.length > 0 then
        hash = get_git_info(recent.at(0)['id'])
        t['summary_fields']['last_job']['hash'] = hash
        msg = git('log -1 --pretty="format: %<(30,trunc)%s (%cr)" ' + hash)
        if msg == '' then
          msg = '... could not find commit'
        else
          msg = get_git_behind(hash) + ' ' + msg
        end
        t['summary_fields']['last_job']['gitinfo'] = msg
      end
    end
    @templates = json['results']
  end
  @backend_time = Time.now - t
  erb :templates
end

get '/templates/:id' do
  id = params['id']
  raise "id must be numeric" unless id =~ /^[0-9]+$/
  json = get_job_template("#{id}")
  last_job_id = json['summary_fields']['recent_jobs'].at(0)['id']
  @template = json
  @gitinfo = get_git_info(last_job_id)
  erb :template
end

get '/jobs/:id' do
  id = params['id']
  raise "id must be numeric" unless id =~ /^[0-9]+$/
  txt = get_job_stdout(id)
  @job = { 'job' => id, 'stdout' => txt }
  erb :job
end

post '/templates/:id/launch/' do
  id = params['id']
  raise "id must be numeric" unless id =~ /^[0-9]+$/
  @job = JSON.parse(post_tower("/job_templates/#{id}/launch/"))
  redirect '/jobs/' + @job['job'].to_s
end

def get_git_behind(hash)
  hashes = git('rev-list ' + hash + '..HEAD')
  if hashes.lines.length == 0 then
    '[HEAD]'
  else
    '[+' + hashes.lines.length.to_s + ']'
  end
end

def get_git_info(job_id)
  begin
    raw = get_tower('/project_updates/' + (job_id+1).to_s + '/stdout/?format=txt')
    search = '"after": '
    from = raw.index(search) + search.length + 1
    raw = raw[from..raw.length]
    raw = raw[0..raw.index('"')-1]
  rescue => e
    puts e
    'ERR'
  end
end

def get_projects()
  list = JSON.parse(get_tower('/projects/'))['results']
  hash = Hash.new
  list.each do |project|
    hash[project['id']] = project
  end
  hash
end

def get_job_template(id)
  JSON.parse(get_tower('/job_templates/' + id))
end

def get_job_templates_by_playbook(playbook)
  get_job_templates('playbook=' + playbook)
end

def get_job_templates_by_name(fragment)
  get_job_templates('name__icontains=' + fragment)
end

def get_job_templates(querystring)
  query = '/job_templates/?page_size=50&' + querystring
  JSON.parse(get_tower(query))
end

def get_job_stdout(id)
  get_tower('/jobs/' + id + '/stdout/?format=txt')
end

def get_tower(resource)
  call_tower(resource, :get)
end

def post_tower(resource)
  call_tower(resource, :post)
end

def call_tower(resource, method)
  RestClient::Request.execute(
    method: method,
    url: 'https://ansible.it.bwns.ch/api/v1' + resource,
    timeout: 20,
    headers: {:Authorization => 'Basic dGFhemVmbDE6bG9naW4xMjM='},
    :verify_ssl => false
  )
end

def git(cmd)
  `git -C git/workingcopy #{cmd}`
end
