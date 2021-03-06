#!/usr/local/bin/ruby -w
require 'sinatra'
require 'rest-client'
require 'json'

# Listen on all interfaces to support docker port mapping
set :bind, '0.0.0.0'

enable :sessions

before '/towerfe/*' do
  redirect to('/towerfe/login/') unless (session[:authtoken] or /login/ =~ request.path_info.to_s)
end

get '/towerfe/login/' do
  erb :login
end

post '/towerfe/login/' do
  json = login_tower(params['username'], params['password'])
  puts json
  if json['token'] then
    reset_session_info(params['username'], json['token'])
    redirect to('/towerfe/')
  end
  redirect to('/towerfe/login/')
end

get '/towerfe/logout/' do
  reset_session_info
  redirect to('/towerfe/login/')
end

get '/towerfe/' do
  redirect to('/towerfe/templates/')
end

get '/towerfe/projects/' do
  t = Time.now
  @projects = JSON.parse(get_tower('/projects/'))['results']
  @backend_time = Time.now - t
  erb :projects
end

get '/towerfe/templates' do
  redirect to('/towerfe/templates/')
end

get '/towerfe/templates/' do
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
    projects = get_projects()
    json['results'].each do |t|
      project = projects[t['project']]
      t['project_scm_url'] = project['scm_url'];
      t['project_scm_branch'] = project['scm_branch'];
      recent = t['summary_fields']['recent_jobs']
      if recent.length > 0 then
        git('reset --hard origin/' + project['scm_branch'])
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

get '/towerfe/templates/:id' do
  id = params['id']
  raise "id must be numeric" unless id =~ /^[0-9]+$/
  json = get_job_template("#{id}")
  last_job_id = json['summary_fields']['recent_jobs'].at(0)['id']
  @template = json
  @gitinfo = get_git_info(last_job_id)
  erb :template
end

get '/towerfe/jobs/:id' do
  id = params['id']
  raise "id must be numeric" unless id =~ /^[0-9]+$/
  txt = get_job_stdout(id)
  @job = { 'job' => id, 'stdout' => txt }
  erb :job
end

post '/towerfe/templates/:id/launch/' do
  id = params['id']
  raise "id must be numeric" unless id =~ /^[0-9]+$/
  @job = JSON.parse(post_tower("/job_templates/#{id}/launch/"))
  redirect '/towerfe/jobs/' + @job['job'].to_s
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
    #raw = post_tower('/project_updates/' + (job_id+1).to_s + '/stdout/?format=txt')
    raw = get_tower('/project_updates/' + (job_id+1).to_s + '/stdout?txt_download&token=' + session[:authtoken])
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
  begin
    RestClient::Request.execute(
      method: method,
      url: 'https://ansible.it.bwns.ch/api/v1' + resource,
      timeout: 20,
      headers: {:Authorization => 'Token ' + session[:authtoken]},
      :verify_ssl => false
    )
  rescue RestClient::Unauthorized
    reset_session_info
    redirect to('/towerfe/login/')
  end
end

def login_tower(username, password)
  JSON.parse(RestClient::Request.execute(
    method: :post,
    url: 'https://ansible.it.bwns.ch/api/v1' + '/authtoken/',
    timeout: 20,
    :verify_ssl => false,
    payload: {:username => username, :password => password}
  ))
end

def git(cmd)
  `git -C git/workingcopy #{cmd}`
end

def reset_session_info(username = nil, authtoken = nil)
  session[:username] = username
  session[:authtoken] = authtoken
end

def active_page?(path='')
  request.path_info.start_with?('/towerfe/' + path)
end
