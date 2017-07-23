# TowerFE

## Run

### Manually (for development)

Clone the git repository that holds the Ansible configurations to `./git/workingcopy`:

    mkdir -p git
    git clone ssh://git@git.example.com/ansible/project.git git/workingcopy

Install the gems:

    gem install -g Gemfile

Run:

    ./towerfe.rb

### Notes on OSX

On OSX, I use rbenv (https://github.com/rbenv/rbenv).

    brew update
    brew install rbenv
    rbenv init

Additionally, I use the `restart` utility for convenience:

    gem install restart
    restart ruby ./towerfe.rb

### Docker

Build image

    docker build -t floone/towerfe .

Run in production mode

    docker run --rm -e RACK_ENV=production --name tf -p 4567:4567 floone/towerfe