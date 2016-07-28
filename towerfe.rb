require 'sinatra'
require 'rest-client'
require 'json'
#require 'parallel'

get '/templates' do
  json = get_job_templates(params['project'], params['playbook'])
  #Parallel.each(json['results']) do |t|
  json['results'].each do |t|
    recent = t['summary_fields']['recent_jobs']
    if recent.length > 0 then
      hash = get_git_info(recent.at(0)['id'])
      t['summary_fields']['last_job']['hash'] = hash
    end
  end
  @templates = json['results']
  erb :templates
end

get '/templates/:id' do
  json = get_job_template("#{params['id']}")
  last_job_id = json['summary_fields']['recent_jobs'].at(0)['id']
  @template = json
  @gitinfo = get_git_info(last_job_id)
  erb :template
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

def get_job_template(id)
  JSON.parse(get_tower('/job_templates/' + id))
end

def get_job_templates(project=nil, playbook=nil)
  query = '/job_templates/?page_size=50'
  if (project) then
    query += '&project=' + project
  end
  if (playbook) then
    query += '&playbook=' + playbook
  end
  JSON.parse(get_tower(query))
end

def get_tower(resource)
  RestClient.get 'https://ansible.it.bwns.ch/api/v1' + resource, {:Authorization => 'Basic dGFhemVmbDE6bG9naW4xMjM='}
end