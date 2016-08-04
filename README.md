# TowerFE


## Development

For Windows, additionally

    gem install wdm

Run locally

restart ruby towerfe.rb

## Docker

Build image

    docker build -t floone/towerfe .

Run in production mode

    docker run --rm -e RACK_ENV=production --name tf -p 4567:4567 floone/towerfe